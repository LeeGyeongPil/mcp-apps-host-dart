import 'dart:async';
import 'dart:collection';

import 'jsonrpc.dart';
import 'methods.dart';
import 'policy.dart';
import 'server_adapter.dart';
import 'transport.dart';
import 'types.dart';

/// Where a [HostBridge] is in the View lifecycle.
enum BridgeState {
  /// Waiting for `ui/initialize`.
  awaitingInitialize,

  /// Initialize answered, waiting for `ui/notifications/initialized`.
  awaitingInitialized,

  /// The View is ready; notifications flow.
  ready,

  /// Torn down. Requests from the View are refused.
  closed,
}

/// Handles `ui/open-link`. Return `true` after opening, `false` to refuse.
typedef OpenLinkHandler = Future<bool> Function(Uri url);

/// Handles `ui/message` (the View adds a message to the conversation).
/// Return `false` to report an error to the View.
typedef MessageHandler = Future<bool> Function(Map<String, Object?> params);

/// Handles `ui/request-display-mode`. Return the mode that was granted.
typedef DisplayModeHandler = Future<String> Function(String requestedMode);

/// Handles `ui/update-model-context`.
typedef ModelContextHandler = Future<void> Function(
    Map<String, Object?> params);

/// The host side of one MCP Apps View. Pure Dart: it knows nothing about
/// WebViews, only about a [ViewTransport].
///
/// The bridge answers the View's requests, holds Host->View notifications
/// until the View said it is initialized, and routes `tools/call` through a
/// [ToolCallPolicy] to the [McpServerAdapter].
class HostBridge {
  HostBridge({
    required this.transport,
    required this.server,
    required this.hostInfo,
    required this.hostContext,
    ToolCallPolicy? policy,
    this.onOpenLink,
    this.onMessage,
    this.onRequestDisplayMode,
    this.onUpdateModelContext,
    this.onSizeChanged,
    this.onLog,
    this.maxQueued = 256,
    this.maxAuditEntries = 1000,
  }) : policy = policy ?? ToolCallPolicy() {
    _context = Map.of(hostContext.toJson());
    _subscription = transport.incoming.listen(_onRaw);
  }

  final ViewTransport transport;
  final McpServerAdapter server;
  final HostInfo hostInfo;
  final HostContext hostContext;
  final ToolCallPolicy policy;

  final OpenLinkHandler? onOpenLink;
  final MessageHandler? onMessage;
  final DisplayModeHandler? onRequestDisplayMode;
  final ModelContextHandler? onUpdateModelContext;
  final void Function(ViewSize size)? onSizeChanged;
  final void Function(LogEntry entry)? onLog;

  /// Upper bound of notifications held before `initialized`. The oldest are
  /// dropped (and audited) beyond it.
  final int maxQueued;

  /// Upper bound of the kept audit trail.
  final int maxAuditEntries;

  late Map<String, Object?> _context;
  late final StreamSubscription<String> _subscription;
  final _stateChanges = StreamController<BridgeState>.broadcast();
  final _queue = Queue<JsonRpcNotification>();
  final _audit = <AuditEntry>[];
  final _pending = <Object, Completer<void>>{};
  List<Map<String, Object?>>? _tools;
  BridgeState _state = BridgeState.awaitingInitialize;
  int _nextId = 1;

  BridgeState get state => _state;

  /// Emits every state change.
  Stream<BridgeState> get stateChanges => _stateChanges.stream;

  /// Every policy decision so far (bounded by [maxAuditEntries]).
  List<AuditEntry> get audit => List.unmodifiable(_audit);

  /// Number of notifications waiting for `initialized`.
  int get queuedCount => _queue.length;

  /// What this host tells the View it supports. Computed from the handlers
  /// given, so nothing is advertised that would be answered with an error.
  /// Draft methods such as `ui/download-file` are never advertised.
  Map<String, Object?> get hostCapabilities => {
        if (onOpenLink != null) 'openLinks': <String, Object?>{},
        'serverTools': <String, Object?>{},
        'serverResources': <String, Object?>{},
        if (onLog != null) 'logging': <String, Object?>{},
        if (onMessage != null) 'message': {'text': <String, Object?>{}},
        if (onUpdateModelContext != null)
          'updateModelContext': {'text': <String, Object?>{}},
      };

  // ---- Host -> View ----

  void sendToolInput(Map<String, Object?> arguments) =>
      _notify(UiMethods.toolInput, {'arguments': arguments});

  void sendToolInputPartial(Map<String, Object?> arguments) =>
      _notify(UiMethods.toolInputPartial, {'arguments': arguments});

  void sendToolResult(Map<String, Object?> callToolResult) =>
      _notify(UiMethods.toolResult, callToolResult);

  void sendToolCancelled([String? reason]) =>
      _notify(UiMethods.toolCancelled, {if (reason != null) 'reason': reason});

  /// Merges [partial] (wire-format keys such as `theme`) into the host
  /// context and tells the View.
  void updateHostContext(Map<String, Object?> partial) {
    _context = {..._context, ...partial};
    _notify(UiMethods.hostContextChanged, partial);
  }

  /// Asks the View to clean up (`ui/resource-teardown`), waits for its answer
  /// and closes the bridge. Throws [TimeoutException] when the View does not
  /// answer within [timeout]; the bridge is closed anyway.
  Future<void> teardown(String reason,
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (_state == BridgeState.closed) return;
    final id = _nextId++;
    final done = Completer<void>();
    _pending[id] = done;
    transport.send(
        JsonRpcRequest(id, UiMethods.resourceTeardown, {'reason': reason})
            .encode());
    try {
      await done.future.timeout(timeout);
    } finally {
      _pending.remove(id);
      _setState(BridgeState.closed);
    }
  }

  /// Stops listening. Call it when the View is gone.
  Future<void> close() async {
    _setState(BridgeState.closed);
    await _subscription.cancel();
    await _stateChanges.close();
  }

  // ---- internals ----

  void _setState(BridgeState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateChanges.isClosed) _stateChanges.add(next);
  }

  void _record(AuditEntry entry) {
    _audit.add(entry);
    if (_audit.length > maxAuditEntries) _audit.removeAt(0);
  }

  void _notify(String method, Map<String, Object?> params) {
    if (_state == BridgeState.closed) throw const BridgeClosedException();
    final message = JsonRpcNotification(method, params);
    // The spec: nothing goes to the View before it sent `initialized`.
    if (_state == BridgeState.ready) {
      transport.send(message.encode());
      return;
    }
    _queue.add(message);
    if (_queue.length > maxQueued) {
      final dropped = _queue.removeFirst();
      _record(AuditEntry(
          kind: 'queue',
          subject: dropped.method,
          decision: Decision.denied,
          reason: 'queue full, oldest dropped'));
    }
  }

  void _reply(JsonRpcMessage message) {
    transport.send(message.encode());
  }

  Future<void> _onRaw(String raw) async {
    final JsonRpcMessage message;
    try {
      message = JsonRpcMessage.decode(raw);
    } on FormatException catch (e) {
      _reply(JsonRpcError(null, -32600, 'Invalid Request: ${e.message}'));
      return;
    }
    switch (message) {
      case JsonRpcRequest(:final id, :final method, :final params):
        try {
          _reply(JsonRpcResult(id, await _handleRequest(method, params)));
        } on McpAppsRpcException catch (e) {
          _reply(JsonRpcError(id, e.code, e.message));
        } catch (e) {
          _reply(JsonRpcError(id, -32603, 'Internal error: $e'));
        }
      case JsonRpcNotification(:final method, :final params):
        _handleNotification(method, params);
      case JsonRpcResult(:final id):
        _pending.remove(id)?.complete();
      case JsonRpcError(:final id):
        // An error answer to teardown still means the View is done.
        if (id != null) _pending.remove(id)?.complete();
    }
  }

  Future<Map<String, Object?>> _handleRequest(
      String method, Map<String, Object?> params) async {
    if (_state == BridgeState.closed) {
      throw const McpAppsRpcException(-32000, 'The bridge is closed');
    }
    if (method == UiMethods.initialize) {
      if (_state != BridgeState.awaitingInitialize) {
        throw const McpAppsRpcException(-32600, 'Already initialized');
      }
      _setState(BridgeState.awaitingInitialized);
      return {
        'protocolVersion': UiMethods.protocolVersion,
        'hostInfo': hostInfo.toJson(),
        'hostCapabilities': hostCapabilities,
        'hostContext': _context,
      };
    }
    if (_state == BridgeState.awaitingInitialize) {
      throw const McpAppsRpcException(
          -32002, 'Send ui/initialize before any other request');
    }
    switch (method) {
      case 'ping':
        return {};
      case 'tools/call':
        return _callTool(params);
      case 'resources/read':
        final uri = params['uri'];
        if (uri is! String) {
          throw const McpAppsRpcException(-32602, 'uri must be a string');
        }
        return server.readResource(uri);
      case UiMethods.openLink:
        return _openLink(params);
      case UiMethods.message:
        final handler = onMessage;
        if (handler == null) break;
        return await handler(params) ? {} : {'isError': true};
      case UiMethods.updateModelContext:
        final handler = onUpdateModelContext;
        if (handler == null) break;
        await handler(params);
        return {};
      case UiMethods.requestDisplayMode:
        final requested = '${params['mode']}';
        final handler = onRequestDisplayMode;
        final current = '${_context['displayMode'] ?? 'inline'}';
        return {'mode': handler == null ? current : await handler(requested)};
    }
    throw McpAppsRpcException(-32601, 'Method not found: $method');
  }

  Future<Map<String, Object?>> _callTool(Map<String, Object?> params) async {
    final name = params['name'];
    if (name is! String) {
      throw const McpAppsRpcException(-32602, 'name must be a string');
    }
    final rawArgs = params['arguments'];
    final arguments = rawArgs is Map
        ? rawArgs.cast<String, Object?>()
        : const <String, Object?>{};

    var tool = _findTool(name);
    if (tool == null) {
      // The server may have added tools since the last listing.
      _tools = (await server.listTools());
      tool = _findTool(name);
    }
    final verdict = await policy.evaluate(name, arguments, tool);
    _record(AuditEntry(
      kind: 'tools/call',
      subject: name,
      decision: verdict.allowed ? Decision.allowed : Decision.denied,
      reason: verdict.reason,
    ));
    if (!verdict.allowed) {
      throw McpAppsRpcException(
          -32000, 'Tool call refused: ${verdict.reason} ($name)');
    }
    return server.callTool(name, arguments);
  }

  Map<String, Object?>? _findTool(String name) {
    for (final tool in _tools ?? const <Map<String, Object?>>[]) {
      if (tool['name'] == name) return tool;
    }
    return null;
  }

  Future<Map<String, Object?>> _openLink(Map<String, Object?> params) async {
    final handler = onOpenLink;
    if (handler == null) {
      throw const McpAppsRpcException(-32601, 'Method not found: ui/open-link');
    }
    final text = '${params['url']}';
    final url = Uri.tryParse(text);
    if (url == null || !(url.isScheme('http') || url.isScheme('https'))) {
      _record(AuditEntry(
          kind: UiMethods.openLink,
          subject: text,
          decision: Decision.denied,
          reason: 'only http and https links'));
      throw const McpAppsRpcException(-32000, 'Invalid URL');
    }
    final opened = await handler(url);
    _record(AuditEntry(
        kind: UiMethods.openLink,
        subject: text,
        decision: opened ? Decision.allowed : Decision.denied,
        reason: opened ? '' : 'denied by user'));
    if (!opened) {
      throw const McpAppsRpcException(-32000, 'Link opening denied by user');
    }
    return {};
  }

  void _handleNotification(String method, Map<String, Object?> params) {
    switch (method) {
      case UiMethods.initialized:
        if (_state != BridgeState.awaitingInitialized) return;
        _setState(BridgeState.ready);
        // Flush in the order the host sent them.
        while (_queue.isNotEmpty) {
          transport.send(_queue.removeFirst().encode());
        }
      case UiMethods.sizeChanged:
        double? number(String key) {
          final v = params[key];
          return v is num ? v.toDouble() : null;
        }
        onSizeChanged
            ?.call(ViewSize(width: number('width'), height: number('height')));
      case 'notifications/message':
        onLog?.call(LogEntry(
          level: '${params['level'] ?? 'info'}',
          data: params['data'],
          logger:
              params['logger'] is String ? params['logger'] as String : null,
        ));
      default:
        // Includes the draft request-teardown notification: only audited.
        _record(AuditEntry(
            kind: 'notification',
            subject: method,
            decision: Decision.denied,
            reason: 'ignored'));
    }
  }
}
