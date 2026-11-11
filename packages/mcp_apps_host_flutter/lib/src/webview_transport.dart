import 'dart:async';

import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A [ViewTransport] on top of a [WebViewController].
///
/// View -> host: the View document calls `window.parent.postMessage(...)`; the
/// injected shim forwards it to the JavaScript channel [channel].
/// Host -> View: [send] runs [BridgeScripts.dispatch] in the page.
class WebViewViewTransport implements ViewTransport {
  /// Registers the channel on [controller]. Do this before loading the page.
  WebViewViewTransport(this.controller, {this.channel = 'mcpBridge'}) {
    controller.addJavaScriptChannel(
      channel,
      onMessageReceived: (message) {
        if (!_incoming.isClosed) _incoming.add(message.message);
      },
    );
  }

  final WebViewController controller;

  /// Name of the JavaScript channel; must match the shim's channel.
  final String channel;

  final _incoming = StreamController<String>();

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String raw) {
    // A page that is already gone can not run scripts; that is not an error
    // the host can act on, so it is ignored.
    controller
        .runJavaScript(BridgeScripts.dispatch(raw))
        .catchError((Object _) {});
  }

  /// Releases the channel and closes [incoming].
  Future<void> dispose() async {
    await controller.removeJavaScriptChannel(channel);
    await _incoming.close();
  }
}
