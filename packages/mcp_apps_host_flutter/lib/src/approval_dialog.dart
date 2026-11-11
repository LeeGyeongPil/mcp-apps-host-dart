import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';

/// Default approval UI for [ToolCallPolicy]: shows the tool name and its
/// arguments and returns `true` only when the user taps "Allow".
///
/// ```dart
/// ToolCallPolicy(
///   mode: ApprovalMode.perToolPerSession,
///   approver: (request) => showToolApprovalDialog(context, request),
/// )
/// ```
Future<bool> showToolApprovalDialog(
  BuildContext context,
  ToolApprovalRequest request,
) async {
  final answer = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ToolApprovalDialog(request: request),
  );
  return answer ?? false;
}

/// The dialog widget behind [showToolApprovalDialog].
class ToolApprovalDialog extends StatelessWidget {
  const ToolApprovalDialog({super.key, required this.request});

  final ToolApprovalRequest request;

  /// Arguments longer than this are cut, so a View can not flood the screen.
  static const maxArgumentChars = 600;

  @override
  Widget build(BuildContext context) {
    var args = const JsonEncoder.withIndent('  ').convert(request.arguments);
    if (args.length > maxArgumentChars) {
      args = '${args.substring(0, maxArgumentChars)}\n...';
    }
    return AlertDialog(
      title: const Text('Allow this app to call a tool?'),
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
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
