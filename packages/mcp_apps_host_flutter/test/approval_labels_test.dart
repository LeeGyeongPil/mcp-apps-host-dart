import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host_flutter/mcp_apps_host_flutter.dart';

Future<BuildContext> _pump(WidgetTester tester) async {
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
  return context;
}

void main() {
  test('forLocale normalizes the language tag', () {
    for (final tag in ['ko', 'ko-KR', 'ko_KR', 'KO']) {
      expect(ToolApprovalLabels.forLocale(tag), same(ToolApprovalLabels.ko));
    }
    for (final tag in ['en', 'en-US', null, '', 'fr']) {
      expect(ToolApprovalLabels.forLocale(tag), same(ToolApprovalLabels.en));
    }
  });

  test('Flutter locale resolves through the same table', () {
    expect(ToolApprovalLabels.forFlutterLocale(const Locale('ko', 'KR')),
        same(ToolApprovalLabels.ko));
    expect(ToolApprovalLabels.forFlutterLocale(const Locale('en', 'US')),
        same(ToolApprovalLabels.en));
    expect(ToolApprovalLabels.forFlutterLocale(null),
        same(ToolApprovalLabels.en));
  });

  testWidgets('locale ko-KR shows Korean texts and returns the choice',
      (tester) async {
    final context = await _pump(tester);
    final allowed = showToolApprovalDialog(
      context,
      const ToolApprovalRequest('refresh_data', {}),
      locale: 'ko-KR',
    );
    await tester.pumpAndSettle();
    expect(find.text('이 앱이 도구를 호출하도록 허용할까요?'), findsOneWidget);
    expect(find.text('Allow'), findsNothing);
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();
    expect(await allowed, isTrue);

    final denied = showToolApprovalDialog(
      context,
      const ToolApprovalRequest('refresh_data', {}),
      locale: 'ko_KR',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('거부'));
    await tester.pumpAndSettle();
    expect(await denied, isFalse);
  });

  testWidgets('labels win over locale', (tester) async {
    final context = await _pump(tester);
    final result = showToolApprovalDialog(
      context,
      const ToolApprovalRequest('refresh_data', {}),
      locale: 'ko',
      labels: const ToolApprovalLabels(
        title: 'Run it?',
        allow: 'Yes',
        deny: 'No',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Run it?'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
