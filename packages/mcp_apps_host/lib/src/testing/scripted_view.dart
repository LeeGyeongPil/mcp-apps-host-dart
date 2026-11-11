import 'dart:async';

import '../jsonrpc.dart';
import '../methods.dart';
import '../transport.dart';

/// A View written in Dart. It plays the part of an MCP App inside a WebView:
/// it sends the same messages in the same order as the ext-apps `App` class
/// (`ui/initialize`, then `ui/notifications/initialized`).
///
/// Use it with [MemoryPipe] to test a [HostBridge] without a WebView.
class ScriptedView {
  ScriptedView(this.transport, {this.answerTeardown = true}) {
    transport.incoming.listen(_onRaw);
  }

  final ViewTransport transport;

  /// Whether to answer `ui/resource-teardown` with `{}` automatically.
  final bool answerTeardown;

  /// Everything the host sent (requests, notifications, responses), in order.
  final List<JsonRpcMessage> received = [];

  final _waiting = <Object, Completer<JsonRpcMessage>>{};
  final _inbox = <JsonRpcMessage>[];
  final _inboxWaiters = <Completer<JsonRpcMessage>>[];
  int _nextId = 1;

  /// Notifications the host sent, in order.
  List<JsonRpcNotification> get notifications =>
      received.whereType<JsonRpcNotification>().toList();

  /// Sends a request and waits for the matching response.
  Future<JsonRpcMessage> request(String method,
      [Map<String, Object?> params = const {}]) {
    final id = _nextId++;
    final done = Completer<JsonRpcMessage>();
    _waiting[id] = done;
    transport.send(JsonRpcRequest(id, method, params).encode());
    return done.future;
  }

  /// Sends a notification.
  void notify(String method, [Map<String, Object?> params = const {}]) =>
      transport.send(JsonRpcNotification(method, params).encode());

  /// Sends raw text, for example broken JSON.
  void sendRaw(String raw) => transport.send(raw);

  /// Does the first half of the handshake and returns the host's answer.
  Future<JsonRpcMessage> initialize() => request(UiMethods.initialize, {
        'protocolVersion': UiMethods.protocolVersion,
        'appInfo': {'name': 'scripted-view', 'version': '0.0.0'},
        'appCapabilities': <String, Object?>{},
      });

  /// Does the second half of the handshake.
  void sendInitialized() => notify(UiMethods.initialized);

  /// Round trip that proves every earlier message of the host arrived: the
  /// pipe keeps order, so when the answer to this ping is here, anything the
  /// host sent before has been received. (The answer may be an error.)
  Future<void> barrier() async {
    await request('ping');
  }

  /// The next message from the host that is not an answer to a [request].
  Future<JsonRpcMessage> nextFromHost() {
    if (_inbox.isNotEmpty) return Future.value(_inbox.removeAt(0));
    final waiter = Completer<JsonRpcMessage>();
    _inboxWaiters.add(waiter);
    return waiter.future;
  }

  void _onRaw(String raw) {
    final JsonRpcMessage message;
    try {
      message = JsonRpcMessage.decode(raw);
    } on FormatException {
      return;
    }
    received.add(message);
    switch (message) {
      case JsonRpcResult(:final id):
        _waiting.remove(id)?.complete(message);
      case JsonRpcError(:final id) when id != null && _waiting.containsKey(id):
        _waiting.remove(id)!.complete(message);
      case JsonRpcRequest(:final id, :final method):
        if (method == UiMethods.resourceTeardown && answerTeardown) {
          transport.send(JsonRpcResult(id, const {}).encode());
        } else {
          _push(message);
        }
      default:
        _push(message);
    }
  }

  void _push(JsonRpcMessage message) {
    if (_inboxWaiters.isNotEmpty) {
      _inboxWaiters.removeAt(0).complete(message);
    } else {
      _inbox.add(message);
    }
  }
}
