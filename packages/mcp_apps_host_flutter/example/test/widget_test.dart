import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_apps_host_flutter_example/main.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview_platform.dart';

void main() {
  testWidgets('shows practice mode and creates a WebView controller', (
    tester,
  ) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.textContaining('Practice mode'), findsOneWidget);
    expect(platform.controller, isNotNull);
  });
}
