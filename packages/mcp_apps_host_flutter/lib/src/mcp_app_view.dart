import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'host_context.dart';
import 'webview_transport.dart';

/// Shows one MCP App (`ui://` View) in a WebView and runs the host side of
/// its protocol.
///
/// The widget prepares the HTML (CSP meta and bridge shim first in `<head>`),
/// loads it, answers the View's requests through a [HostBridge] and locks
/// navigation: after the first load the WebView can not leave the page. Links
/// are only opened through [onOpenLink].
///
/// The document, server, CSP and policy are read once, when the widget is
/// first built. To show another View or switch server, give the widget a new
/// `key` so Flutter creates a fresh state. Disposing the widget closes the
/// bridge without sending `ui/resource-teardown`; if the View needs that, call
/// `teardown` on the bridge you received in [onBridgeReady] before removing
/// the widget.
class McpAppView extends StatefulWidget {
  const McpAppView({
    super.key,
    required this.server,
    required this.html,
    required this.hostInfo,
    this.csp,
    this.policy,
    this.onOpenLink,
    this.onMessage,
    this.onUpdateModelContext,
    this.onRequestDisplayMode,
    this.onLog,
    this.onBridgeReady,
    this.initialHeight = 300,
    this.maxHeight = 800,
    this.baseUrl = defaultBaseUrl,
    this.controller,
  });

  /// Origin the document is loaded with. It must not be an address of your
  /// own app or assets, so the View can not reach their cookies or files.
  static const defaultBaseUrl = 'https://mcp-app.invalid/';

  /// The MCP server the View's tool calls are forwarded to.
  final McpServerAdapter server;

  /// The View document (the text of the `ui://` resource).
  final String html;

  final HostInfo hostInfo;

  /// The resource's `_meta.ui.csp` declaration, if any.
  final UiCsp? csp;

  /// Rules for the View's `tools/call` requests. Defaults to no approval.
  final ToolCallPolicy? policy;

  final OpenLinkHandler? onOpenLink;
  final MessageHandler? onMessage;
  final ModelContextHandler? onUpdateModelContext;
  final DisplayModeHandler? onRequestDisplayMode;
  final void Function(LogEntry entry)? onLog;

  /// Called once the bridge exists. Use it to send `sendToolInput` and
  /// `sendToolResult`; they wait until the View is ready.
  final void Function(HostBridge bridge)? onBridgeReady;

  /// Height before the View reports its size.
  final double initialHeight;

  /// Upper limit for the height a View can ask for.
  final double maxHeight;

  final String baseUrl;

  /// Use your own controller (for example to share cookies settings). It must
  /// be fresh: the widget adds a channel and a navigation delegate.
  final WebViewController? controller;

  @override
  State<McpAppView> createState() => _McpAppViewState();
}

class _McpAppViewState extends State<McpAppView> {
  late final WebViewController _controller;
  late final WebViewViewTransport _transport;
  HostBridge? _bridge;
  late double _height;
  bool _pageLoaded = false;
  String? _lastContext;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
    _controller = widget.controller ?? WebViewController();
    _transport = WebViewViewTransport(_controller);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageFinished: (_) => _pageLoaded = true,
        ),
      );
  }

  @override
  void didUpdateWidget(McpAppView oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.html == widget.html &&
          identical(oldWidget.server, widget.server),
      'McpAppView reads html, server, csp and policy only once. '
      'Give the widget a new key to load a different View.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final context = hostContextOf(this.context, maxHeight: widget.maxHeight);
    final encoded = jsonEncode(context.toJson());
    final bridge = _bridge;
    if (bridge == null) {
      _start(context);
    } else if (encoded != _lastContext && bridge.state != BridgeState.closed) {
      bridge.updateHostContext(context.toJson());
    }
    _lastContext = encoded;
  }

  void _start(HostContext hostContext) {
    final bridge = HostBridge(
      transport: _transport,
      server: widget.server,
      hostInfo: widget.hostInfo,
      hostContext: hostContext,
      policy: widget.policy,
      onOpenLink: widget.onOpenLink,
      onMessage: widget.onMessage,
      onUpdateModelContext: widget.onUpdateModelContext,
      onRequestDisplayMode: widget.onRequestDisplayMode,
      onLog: widget.onLog,
      onSizeChanged: _onSizeChanged,
    );
    _bridge = bridge;
    final prepared = HtmlInjector.prepare(
      widget.html,
      csp: CspBuilder.build(widget.csp),
      shim: BridgeScripts.shim(),
    );
    _controller.loadHtmlString(prepared, baseUrl: widget.baseUrl);
    widget.onBridgeReady?.call(bridge);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    // Sub-frames are governed by the CSP (frame-src). The main frame may only
    // do the initial load.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final initial =
        request.url == widget.baseUrl || request.url == 'about:blank';
    if (!_pageLoaded && initial) return NavigationDecision.navigate;
    return NavigationDecision.prevent;
  }

  void _onSizeChanged(ViewSize size) {
    final height = size.height;
    if (height == null || !mounted) return;
    final next = height.clamp(0, widget.maxHeight).toDouble();
    if (next != _height) setState(() => _height = next);
  }

  @override
  void dispose() {
    final bridge = _bridge;
    _bridge = null;
    if (bridge != null) {
      // The page is going away; there is nobody to wait for.
      bridge.close();
    }
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('mcp-app-view-box'),
      height: _height,
      child: WebViewWidget(controller: _controller),
    );
  }
}
