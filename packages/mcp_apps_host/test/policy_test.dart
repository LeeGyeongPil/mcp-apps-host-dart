import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:test/test.dart';

class Rig {
  Rig(ToolCallPolicy Function(Rig) makePolicy) {
    final pipe = MemoryPipe();
    server = FakeMcpServer();
    bridge = HostBridge(
      transport: pipe.hostSide,
      server: server,
      hostInfo: const HostInfo(name: 't', version: '1'),
      hostContext: const HostContext(),
      policy: makePolicy(this),
    );
    view = ScriptedView(pipe.viewSide);
  }

  late final FakeMcpServer server;
  late final HostBridge bridge;
  late final ScriptedView view;
  int asked = 0;
  bool answer = true;

  Future<void> ready() async {
    await view.initialize();
    view.sendInitialized();
    await view.barrier();
  }

  Future<JsonRpcMessage> call(String tool) =>
      view.request('tools/call', {'name': tool, 'arguments': {}});
}

ToolApprover counting(Rig r) => (request) async {
      r.asked++;
      return r.answer;
    };

int codeOf(JsonRpcMessage m) => (m as JsonRpcError).code;

void main() {
  test('model-only tool is refused without reaching the server', () async {
    final r = Rig((_) => ToolCallPolicy());
    await r.ready();
    final answer = await r.call('delete_all');
    expect(codeOf(answer), -32000);
    expect(r.server.calls, isEmpty);
  });

  test('visibility omitted means allowed; app-only is delegated', () async {
    final r = Rig((_) => ToolCallPolicy());
    await r.ready();
    expect(await r.call('show_dashboard'), isA<JsonRpcResult>());
    expect(await r.call('refresh_data'), isA<JsonRpcResult>());
    expect(r.server.calls, ['show_dashboard', 'refresh_data']);
  });

  test('tool missing from the server list and denied tools are refused',
      () async {
    final r = Rig((_) => ToolCallPolicy(deny: {'refresh_data'}));
    await r.ready();
    expect(codeOf(await r.call('not_a_tool')), -32000);
    expect(codeOf(await r.call('refresh_data')), -32000);
    expect(r.server.calls, isEmpty);
  });

  test('allow list limits the tools', () async {
    final r = Rig((_) => ToolCallPolicy(allow: {'show_dashboard'}));
    await r.ready();
    expect(codeOf(await r.call('refresh_data')), -32000);
    expect(await r.call('show_dashboard'), isA<JsonRpcResult>());
  });

  test('perCall asks for each of 3 calls', () async {
    final r = Rig((r) =>
        ToolCallPolicy(mode: ApprovalMode.perCall, approver: counting(r)));
    await r.ready();
    for (var i = 0; i < 3; i++) {
      await r.call('refresh_data');
    }
    expect(r.asked, 3);
  });

  test('perToolPerSession asks once for one tool', () async {
    final r = Rig((r) => ToolCallPolicy(
        mode: ApprovalMode.perToolPerSession, approver: counting(r)));
    await r.ready();
    for (var i = 0; i < 3; i++) {
      await r.call('refresh_data');
    }
    expect(r.asked, 1);
    await r.call('show_dashboard');
    expect(r.asked, 2, reason: 'a different tool is a new question');
  });

  test('perSession asks once for two tools', () async {
    final r = Rig((r) =>
        ToolCallPolicy(mode: ApprovalMode.perSession, approver: counting(r)));
    await r.ready();
    await r.call('refresh_data');
    await r.call('show_dashboard');
    expect(r.asked, 1);
  });

  test('user refusal gives -32000 "denied by user" and is not remembered',
      () async {
    final r = Rig((r) => ToolCallPolicy(
        mode: ApprovalMode.perToolPerSession, approver: counting(r)));
    await r.ready();
    r.answer = false;
    final answer = await r.call('refresh_data');
    expect(codeOf(answer), -32000);
    expect((answer as JsonRpcError).message, contains('denied by user'));
    await r.call('refresh_data');
    expect(r.asked, 2);
    expect(r.server.calls, isEmpty);
  });

  test('every decision is in the audit trail', () async {
    final r = Rig((r) =>
        ToolCallPolicy(mode: ApprovalMode.perCall, approver: counting(r)));
    await r.ready();
    await r.call('refresh_data');
    await r.call('delete_all');
    r.answer = false;
    await r.call('show_dashboard');
    final trail = r.bridge.audit;
    expect(trail.map((e) => '${e.decision.name} ${e.subject}'),
        ['allowed refresh_data', 'denied delete_all', 'denied show_dashboard']);
    expect(trail.every((e) => e.kind == 'tools/call'), isTrue);
  });

  test('a mode that asks needs an approver', () {
    expect(
        () => ToolCallPolicy(mode: ApprovalMode.perCall), throwsArgumentError);
  });

  group('parallel calls share one pending question', () {
    // The approver answers after a delay, so parallel calls overlap it.
    ToolApprover slow(Rig r) => (request) async {
          r.asked++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return r.answer;
        };

    test('perToolPerSession asks once for three parallel calls', () async {
      final r = Rig((r) => ToolCallPolicy(
          mode: ApprovalMode.perToolPerSession, approver: slow(r)));
      await r.ready();
      final answers = await Future.wait([
        r.call('refresh_data'),
        r.call('refresh_data'),
        r.call('refresh_data')
      ]);
      expect(r.asked, 1);
      expect(answers.every((a) => a is JsonRpcResult), isTrue);
    });

    test('perSession asks once across different tools', () async {
      final r = Rig((r) =>
          ToolCallPolicy(mode: ApprovalMode.perSession, approver: slow(r)));
      await r.ready();
      final answers = await Future.wait([
        r.call('refresh_data'),
        r.call('show_dashboard'),
        r.call('refresh_data')
      ]);
      expect(r.asked, 1);
      expect(answers.every((a) => a is JsonRpcResult), isTrue);
    });

    test('a refusal is shared by the parallel calls and asked again later',
        () async {
      final r = Rig((r) => ToolCallPolicy(
          mode: ApprovalMode.perToolPerSession, approver: slow(r)));
      await r.ready();
      r.answer = false;
      final answers =
          await Future.wait([r.call('refresh_data'), r.call('refresh_data')]);
      expect(r.asked, 1);
      expect(answers.every((a) => a is JsonRpcError), isTrue);
      r.answer = true;
      expect(await r.call('refresh_data'), isA<JsonRpcResult>());
      expect(r.asked, 2, reason: 'a refusal is not remembered');
    });

    test('perCall still asks for every parallel call', () async {
      final r = Rig(
          (r) => ToolCallPolicy(mode: ApprovalMode.perCall, approver: slow(r)));
      await r.ready();
      await Future.wait([r.call('refresh_data'), r.call('refresh_data')]);
      expect(r.asked, 2);
    });
  });
}
