import 'meta.dart';

/// How often the user is asked before a View may call a tool.
enum ApprovalMode {
  /// Never ask. Visibility and allow/deny lists still apply.
  never,

  /// Ask before every call.
  perCall,

  /// Ask once per tool; the answer holds until the policy is reset.
  perToolPerSession,

  /// Ask once; the answer covers every tool.
  perSession,
}

/// What the user is asked to approve.
class ToolApprovalRequest {
  const ToolApprovalRequest(this.toolName, this.arguments);

  final String toolName;
  final Map<String, Object?> arguments;
}

/// Asks the user. Return `true` to allow the call.
typedef ToolApprover = Future<bool> Function(ToolApprovalRequest request);

/// The verdict of [ToolCallPolicy.evaluate].
class PolicyVerdict {
  const PolicyVerdict.allow() : this._(true, '');
  const PolicyVerdict.deny(String reason) : this._(false, reason);
  const PolicyVerdict._(this.allowed, this.reason);

  final bool allowed;
  final String reason;
}

/// Decides whether a View may call a tool.
///
/// Layers, in order: the tool must exist on the connected server, its
/// visibility must include `app` (a MUST in the spec), it must not be in
/// [deny], it must be in [allow] when that is set, and finally the user may
/// be asked according to [mode]. Without an [approver], any mode other than
/// [ApprovalMode.never] is rejected when the policy is created.
class ToolCallPolicy {
  ToolCallPolicy({
    this.mode = ApprovalMode.never,
    this.approver,
    Set<String>? allow,
    Set<String>? deny,
  })  : allow = allow == null ? null : Set.unmodifiable(allow),
        deny = Set.unmodifiable(deny ?? const <String>{}) {
    if (mode != ApprovalMode.never && approver == null) {
      throw ArgumentError.value(
        mode,
        'mode',
        'An approver is required when mode is not ApprovalMode.never. '
            'Pass approver: or use ApprovalMode.never.',
      );
    }
  }

  final ApprovalMode mode;
  final ToolApprover? approver;

  /// When set, only these tools may be called.
  final Set<String>? allow;

  /// These tools are always refused.
  final Set<String> deny;

  final Set<String> _approvedTools = {};
  bool _sessionApproved = false;
  final Map<String, Future<bool>> _pending = {};

  /// Forgets earlier approvals.
  void resetSession() {
    _approvedTools.clear();
    _sessionApproved = false;
    _pending.clear();
  }

  /// Asks once and records a yes. A no (or an error) is not remembered, so a
  /// later call asks again; calls that waited on this question share its
  /// answer.
  Future<bool> _ask(
      String key, String name, Map<String, Object?> arguments) async {
    try {
      final ok = await approver!(ToolApprovalRequest(name, arguments));
      if (ok) {
        if (mode == ApprovalMode.perToolPerSession) _approvedTools.add(name);
        if (mode == ApprovalMode.perSession) _sessionApproved = true;
      }
      return ok;
    } finally {
      _pending.remove(key);
    }
  }

  /// Decides on a call of [name]. [tool] is the server's definition of the
  /// tool, or `null` when the server does not list it.
  Future<PolicyVerdict> evaluate(
    String name,
    Map<String, Object?> arguments,
    Map<String, Object?>? tool,
  ) async {
    if (tool == null) return const PolicyVerdict.deny('unknown tool');
    if (!UiToolMeta.fromTool(tool).visibleToApp) {
      return const PolicyVerdict.deny('tool is not visible to apps');
    }
    if (deny.contains(name)) return const PolicyVerdict.deny('tool is blocked');
    if (allow != null && !allow!.contains(name)) {
      return const PolicyVerdict.deny('tool is not on the allow list');
    }

    final needsAsk = switch (mode) {
      ApprovalMode.never => false,
      ApprovalMode.perCall => true,
      ApprovalMode.perToolPerSession => !_approvedTools.contains(name),
      ApprovalMode.perSession => !_sessionApproved,
    };
    if (!needsAsk) return const PolicyVerdict.allow();

    // Parallel calls that need the same answer share one pending question.
    final key = switch (mode) {
      ApprovalMode.perToolPerSession => name,
      ApprovalMode.perSession => '',
      _ => null, // perCall: every call is its own question
    };
    final ok = key == null
        ? await approver!(ToolApprovalRequest(name, arguments))
        : await _pending.putIfAbsent(key, () => _ask(key, name, arguments));
    if (!ok) return const PolicyVerdict.deny('denied by user');
    return const PolicyVerdict.allow();
  }
}
