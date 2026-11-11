# Manual check on a real WebView

The automated tests use a fake `WebViewPlatform`. Nothing in CI renders a real
WebView. Before relying on the widget, do this once per platform you ship
(macOS, iOS, Android). Status of each box is yours to fill in; this repository
has not been verified on a device.

1. Create the runner: `cd packages/mcp_apps_host_flutter/example && flutter create --platforms=macos,ios,android .`
2. `flutter run -d <device>`.
3. [ ] The demo View appears and its log shows a `ui/notifications/tool-input` message (handshake and queue work, `source: window` is accepted).
4. [ ] The widget grows to about 320 px after the View reports its size.
5. [ ] "Call refresh_data" shows the approval dialog once; a second press does not ask again.
6. [ ] "Call delete_all" is refused (the log shows an error).
7. [ ] Inspect the page (Safari Web Inspector, `chrome://inspect`): the CSP meta is the first element in `<head>`, and a `fetch('https://example.com')` from the console is blocked by `connect-src 'none'`.
8. [ ] A link or `location.href = 'https://example.com'` inside the View does not navigate.
