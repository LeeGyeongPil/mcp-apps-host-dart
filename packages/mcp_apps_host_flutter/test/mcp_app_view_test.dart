import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:mcp_apps_host_flutter/mcp_apps_host_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview_platform.dart';

const html =
    '<!doctype html><html><head><title>t</title><script>doc()</script></head><body></body></html>';

Widget app(Widget child, {ThemeData? theme, MediaQueryData? media}) {
  Widget body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, child: child),
  );
  if (media != null) body = MediaQuery(data: media, child: body);
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: body),
  );
}

McpAppView view({
  HostBridge? Function(HostBridge)? onReady,
  double maxHeight = 500,
}) => McpAppView(
  maxHeight: maxHeight,
  server: FakeMcpServer(),
  html: html,
  hostInfo: const HostInfo(name: 'widget-test', version: '1'),
  onBridgeReady: onReady == null ? null : (b) => onReady(b),
);

void main() {
  late FakeWebViewPlatform platform;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  testWidgets(
    'loads prepared HTML with a non-asset baseUrl and registers the channel',
    (tester) async {
      await tester.pumpWidget(app(view()));
      final c = platform.controller!;

      expect(c.channels.keys, contains('mcpBridge'));
      expect(c.mode, JavaScriptMode.unrestricted);
      final loaded = c.loadedHtml.single;
      expect(loaded.baseUrl, McpAppView.defaultBaseUrl);
      expect(loaded.baseUrl, startsWith('https://'));
      expect(loaded.baseUrl, isNot(startsWith('file:')));

      final head = loaded.html.indexOf('<head>') + '<head>'.length;
      expect(
        loaded.html.indexOf('<meta http-equiv="Content-Security-Policy"'),
        head,
      );
      expect(loaded.html, contains("default-src 'none'"));
      expect(
        loaded.html.indexOf('window.parent.postMessage'),
        lessThan(loaded.html.indexOf('doc()')),
      );
    },
  );

  testWidgets(
    'answers ui/initialize through runJavaScript with source: window',
    (tester) async {
      await tester.pumpWidget(app(view()));
      final c = platform.controller!;
      c.postFromPage(
        'mcpBridge',
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ui/initialize',
          'params': {'protocolVersion': '2026-01-26'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(c.scripts, isNotEmpty);
      expect(c.scripts.first, contains('source: window'));
      expect(c.scripts.first, contains('2026-01-26'));
    },
  );

  testWidgets(
    'hostContextOf reflects dark theme, mobile platform and safe area',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      late HostContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 800),
              viewPadding: EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: Builder(
              builder: (ctx) {
                context = hostContextOf(ctx);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // Reset before the test ends: Flutter checks that no override is left.
      debugDefaultTargetPlatformOverride = null;
      final json = context.toJson();
      expect(json['theme'], 'dark');
      expect(json['platform'], 'mobile');
      expect((json['safeAreaInsets']! as Map)['top'], 47);
      expect((json['safeAreaInsets']! as Map)['bottom'], 34);
      expect((json['deviceCapabilities']! as Map)['touch'], true);
    },
  );

  testWidgets('desktop platform and light theme', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    late HostContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = hostContextOf(ctx);
            return const SizedBox();
          },
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = null;
    expect(context.theme, 'light');
    expect(context.platform, 'desktop');
  });

  testWidgets('only the first load may navigate', (tester) async {
    await tester.pumpWidget(app(view()));
    final nav = platform.navigationDelegate!;
    NavigationRequest request(String url, {bool main = true}) =>
        NavigationRequest(url: url, isMainFrame: main);

    expect(
      await nav.onNavigationRequest!(request(McpAppView.defaultBaseUrl)),
      NavigationDecision.navigate,
    );
    expect(
      await nav.onNavigationRequest!(request('https://evil.example/')),
      NavigationDecision.prevent,
    );
    expect(
      await nav.onNavigationRequest!(
        request('https://evil.example/', main: false),
      ),
      NavigationDecision.navigate,
      reason: 'sub-frames are limited by CSP frame-src',
    );

    nav.onPageFinished!(McpAppView.defaultBaseUrl);
    expect(
      await nav.onNavigationRequest!(request(McpAppView.defaultBaseUrl)),
      NavigationDecision.prevent,
      reason: 'after the first load nothing may navigate',
    );
  });

  testWidgets('size-changed sets the widget height, capped by maxHeight', (
    tester,
  ) async {
    await tester.pumpWidget(app(view()));
    final c = platform.controller!;
    double height() =>
        tester.getSize(find.byKey(const ValueKey('mcp-app-view-box'))).height;

    expect(height(), 300);
    Future<void> initialize() async {
      c.postFromPage(
        'mcpBridge',
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ui/initialize',
          'params': {},
        }),
      );
      await tester.pump();
    }

    await initialize();
    c.postFromPage(
      'mcpBridge',
      jsonEncode({
        'jsonrpc': '2.0',
        'method': 'ui/notifications/size-changed',
        'params': {'width': 380, 'height': 420},
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(height(), 420);

    c.postFromPage(
      'mcpBridge',
      jsonEncode({
        'jsonrpc': '2.0',
        'method': 'ui/notifications/size-changed',
        'params': {'height': 99999},
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(height(), 500);
  });

  testWidgets('tool input waits for initialized and then reaches the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        view(
          onReady: (bridge) {
            bridge.sendToolInput({'city': 'Seoul'});
            return null;
          },
        ),
      ),
    );
    final c = platform.controller!;
    await tester.pump();
    expect(c.scripts, isEmpty);

    c.postFromPage(
      'mcpBridge',
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ui/initialize',
        'params': {},
      }),
    );
    await tester.pump();
    await tester.pump();
    final afterInit = c.scripts.length;
    c.postFromPage(
      'mcpBridge',
      jsonEncode({
        'jsonrpc': '2.0',
        'method': 'ui/notifications/initialized',
        'params': {},
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(c.scripts.length, afterInit + 1);
    expect(c.scripts.last, contains('tool-input'));
  });

  testWidgets('approval dialog returns the user choice', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    final result = showToolApprovalDialog(
      context,
      const ToolApprovalRequest('refresh_data', {'n': 1}),
    );
    await tester.pumpAndSettle();
    expect(find.text('refresh_data'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    final denied = showToolApprovalDialog(
      context,
      const ToolApprovalRequest('refresh_data', {}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
    expect(await denied, isFalse);
  });
}
