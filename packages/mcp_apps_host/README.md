# mcp_apps_host

Host-side bridge for MCP Apps (`ui://` Views), in pure Dart. It knows nothing
about WebViews, so it works with any WebView package. For a ready-made
Flutter widget see `mcp_apps_host_flutter` in the same repository.

Main parts: `HostBridge` (handshake, queue until `initialized`, request
routing, teardown), `ToolCallPolicy` (visibility, allow/deny, user approval),
`CspBuilder` and `HtmlInjector` (spec default CSP, shim first in `<head>`),
`BridgeScripts` (WebView `postMessage` shim and dispatch), and
`package:mcp_apps_host/testing.dart` (`MemoryPipe`, `ScriptedView`,
`FakeMcpServer`).

```dart
final bridge = HostBridge(
  transport: myTransport,            // your ViewTransport
  server: McpDartServerAdapter(client),
  hostInfo: const HostInfo(name: 'my-app', version: '1.0.0'),
  hostContext: const HostContext(theme: 'dark', platform: 'mobile'),
  policy: ToolCallPolicy(
    mode: ApprovalMode.perToolPerSession,
    approver: (request) async => askUser(request),
  ),
);
bridge.sendToolInput({'city': 'Seoul'}); // waits until the View is ready
```

Run the example: `dart run example/mcp_apps_host_example.dart`
(practice mode with an in-memory server and a scripted View).

See the repository README for the full guide, pitfalls and limits.
