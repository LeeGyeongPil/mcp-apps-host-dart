import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';

/// The user-visible texts of the approval dialog. This table is the only
/// place where the dialog's wording lives.
class ToolApprovalLabels {
  const ToolApprovalLabels({
    required this.title,
    required this.allow,
    required this.deny,
  });

  /// English texts (the default).
  static const en = ToolApprovalLabels(
    title: 'Allow this app to call a tool?',
    allow: 'Allow',
    deny: 'Deny',
  );

  /// Korean texts.
  static const ko = ToolApprovalLabels(
    title: '이 앱이 도구를 호출하도록 허용할까요?',
    allow: '허용',
    deny: '거부',
  );

  /// Dialog title.
  final String title;

  /// Text of the button that approves the call.
  final String allow;

  /// Text of the button that rejects the call.
  final String deny;

  /// Picks [ko] when the language part of [tag] is `ko` (`ko`, `ko-KR`,
  /// `ko_KR`, `KO`, ...), otherwise [en]. `null` and empty values give [en].
  static ToolApprovalLabels forLocale(String? tag) {
    if (tag == null) return en;
    final language = tag.trim().toLowerCase().split(RegExp('[-_]')).first;
    return language == 'ko' ? ko : en;
  }

  /// Same as [forLocale] for a Flutter [Locale].
  static ToolApprovalLabels forFlutterLocale(Locale? locale) =>
      forLocale(locale?.languageCode);
}

/// Default approval UI for [ToolCallPolicy]: shows the tool name and its
/// arguments and returns `true` only when the user taps the allow button
/// ("Allow" in English, "허용" in Korean).
///
/// The wording is chosen in this order: [labels], then [locale] (for example
/// `'ko-KR'`), then the app's [Localizations] locale (Korean for `ko`), then
/// English. An app that does not list `ko` in `supportedLocales` resolves to
/// `en_US`, so its dialog stays English.
///
/// ```dart
/// ToolCallPolicy(
///   mode: ApprovalMode.perToolPerSession,
///   approver: (request) => showToolApprovalDialog(context, request),
/// )
/// ```
Future<bool> showToolApprovalDialog(
  BuildContext context,
  ToolApprovalRequest request, {
  ToolApprovalLabels? labels,
  String? locale,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ToolApprovalDialog(
      request: request,
      labels: labels,
      locale: locale,
    ),
  );
  return answer ?? false;
}

/// The dialog widget behind [showToolApprovalDialog].
class ToolApprovalDialog extends StatelessWidget {
  const ToolApprovalDialog({
    super.key,
    required this.request,
    this.labels,
    this.locale,
  });

  final ToolApprovalRequest request;

  /// Explicit texts. Wins over [locale] and the app locale.
  final ToolApprovalLabels? labels;

  /// Language tag such as `'ko'` or `'ko-KR'`. Wins over the app locale.
  final String? locale;

  /// Arguments longer than this are cut, so a View can not flood the screen.
  static const maxArgumentChars = 600;

  @override
  Widget build(BuildContext context) {
    var args = const JsonEncoder.withIndent('  ').convert(request.arguments);
    if (args.length > maxArgumentChars) {
      args = '${args.substring(0, maxArgumentChars)}\n...';
    }
    final texts = labels ??
        (locale != null
            ? ToolApprovalLabels.forLocale(locale)
            : ToolApprovalLabels.forFlutterLocale(
                Localizations.maybeLocaleOf(context)));
    return AlertDialog(
      title: Text(texts.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.toolName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(args, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(texts.deny),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(texts.allow),
        ),
      ],
    );
  }
}
