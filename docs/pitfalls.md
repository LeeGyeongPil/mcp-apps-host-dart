# WebView host pitfalls and how this library answers them

Each pitfall names the test that pins the behaviour. Sources: MCP Apps spec
2026-01-26 (https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx)
and `@modelcontextprotocol/ext-apps` 2.0.4, checked 2026-11-10.

| # | Pitfall | What this library does | Test |
|---|---|---|---|
| 1 | In a native WebView the View is the top-level window, so `window.parent === window`. The View SDK ignores a message whose `event.source` is not `window.parent`; a host that dispatches without `source` is silently ignored. | `BridgeScripts.dispatch` always sets `source: window`. | `test/bridge_scripts_test.dart` |
| 2 | Because `parent === window`, a naive `postMessage` from the View is delivered to the View itself (an echo). | `BridgeScripts.shim` replaces `window.parent.postMessage` and sends to the native channel instead of calling the original. | `test/bridge_scripts_test.dart` |
| 3 | The host must not send anything before the View sends `ui/notifications/initialized`. | `HostBridge` queues Host-to-View notifications (bounded) and flushes them in order. | `test/handshake_test.dart` |
| 4 | WebViews have no `sandbox` attribute and no opaque origin; a `<meta>` CSP can not express `frame-ancestors` or `sandbox`. | Spec default CSP injected as the first child of `<head>`; navigation locked after the first load; a non-asset `baseUrl`. This is weaker isolation than an iframe in a browser host. | `test/csp_html_test.dart`, `test/mcp_app_view_test.dart` |
| 5 | Older servers send `_meta["ui/resourceUri"]`. | `UiToolMeta.fromTool` reads both keys. | `test/meta_interop_test.dart` |
| 6 | Tools with `visibility: ["model"]` must not be callable by the View (a MUST in the spec). | `ToolCallPolicy` refuses them before the server is contacted. | `test/policy_test.dart` |
| 7 | An approval card for every `tools/call` is unusable. | `ApprovalMode.perToolPerSession` and `perSession` ask once (concurrent calls share one question; denials are not remembered). | `test/policy_test.dart` |
| 8 | A declared CSP domain could carry `; script-src *`. | `CspBuilder` drops anything that is not a plain origin and only appends to the matching directive. | `test/csp_html_test.dart` |
