// Example app: one MCP App in a WebView, with an in-memory MCP server.
//
// The platform folders are not included. Create them once:
//   cd packages/mcp_apps_host_flutter/example
//   flutter create --platforms=macos,ios,android .
// Then `flutter run -d macos`. (iOS and macOS need no network permission here
// because the demo server is in memory.)
import 'package:flutter/material.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:mcp_apps_host_flutter/mcp_apps_host_flutter.dart';

void main() => runApp(const ExampleApp());

// A View document written for this example. It speaks the MCP Apps protocol
// by hand, the way the ext-apps `App` class does.
const _viewHtml = '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width"></head>
<body style="font-family: sans-serif">
<h3>Demo View</h3>
<button id="refresh">Call refresh_data</button>
<button id="delete">Call delete_all (model only)</button>
<pre id="log"></pre>
<script>
  var log = function (t) { document.getElementById('log').textContent += t + '\\n'; };
  var id = 0;
  var send = function (m) { window.parent.postMessage(m, '*'); };
  var request = function (method, params) { send({jsonrpc: '2.0', id: ++id, method: method, params: params}); };
  window.addEventListener('message', function (e) {
    if (e.source !== window.parent) { return; }
    log(JSON.stringify(e.data).slice(0, 120));
  });
  request('ui/initialize', {protocolVersion: '2026-01-26', appInfo: {name: 'demo', version: '1'}, appCapabilities: {}});
  setTimeout(function () {
    send({jsonrpc: '2.0', method: 'ui/notifications/initialized', params: {}});
    send({jsonrpc: '2.0', method: 'ui/notifications/size-changed', params: {height: 320}});
  }, 300);
  document.getElementById('refresh').onclick = function () { request('tools/call', {name: 'refresh_data', arguments: {}}); };
  document.getElementById('delete').onclick = function () { request('tools/call', {name: 'delete_all', arguments: {}}); };
</script></body></html>''';

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const Scaffold(body: SafeArea(child: DemoPage())),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _server = FakeMcpServer(dashboardHtml: _viewHtml);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Practice mode: in-memory MCP server and a demo View.'),
        const SizedBox(height: 12),
        McpAppView(
          server: _server,
          html: _viewHtml,
          hostInfo: const HostInfo(name: 'example-app', version: '0.1.0'),
          policy: ToolCallPolicy(
            mode: ApprovalMode.perToolPerSession,
            approver: (request) => showToolApprovalDialog(context, request),
          ),
          onOpenLink: (url) async => false,
          onBridgeReady: (bridge) => bridge.sendToolInput({'city': 'Seoul'}),
        ),
      ],
    );
  }
}
