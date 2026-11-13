# mcp_apps_host_flutter

A thin `webview_flutter` adapter for `mcp_apps_host`: `McpAppView` (widget),
`WebViewViewTransport`, `hostContextOf(BuildContext)` and
`showToolApprovalDialog`.

```dart
McpAppView(
  server: serverAdapter,                // McpServerAdapter
  html: resourceText,                   // text of the ui:// resource
  hostInfo: const HostInfo(name: 'my-app', version: '1.0.0'),
  policy: ToolCallPolicy(
    mode: ApprovalMode.perToolPerSession,
    approver: (r) => showToolApprovalDialog(context, r),
  ),
  onOpenLink: (url) async => openInBrowser(url),
  onBridgeReady: (bridge) => bridge.sendToolInput(args),
)
```

The approval dialog follows the app locale (Korean for `ko`, otherwise English).
Choose it explicitly with `showToolApprovalDialog(context, r, locale: 'ko-KR')`
or pass your own `labels: ToolApprovalLabels(...)`; `labels` wins over `locale`.
For auto-detection to give Korean, the app needs `ko` in `supportedLocales` and a `flutter_localizations` delegate; otherwise it stays English.

Tested with Flutter 3.32.4 and webview_flutter 4.13.1 using a fake
`WebViewPlatform`. Real WebView rendering is not covered by automated tests;
see `docs/manual-check.md` in the repository.
