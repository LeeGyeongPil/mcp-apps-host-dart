import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:test/test.dart';

({HostBridge bridge, ScriptedView view}) setup({
  OpenLinkHandler? onOpenLink,
  MessageHandler? onMessage,
}) {
  final pipe = MemoryPipe();
  final bridge = HostBridge(
    transport: pipe.hostSide,
    server: FakeMcpServer(),
    hostInfo: const HostInfo(name: 'test-host', version: '1.2.3'),
    hostContext: const HostContext(theme: 'dark', platform: 'mobile'),
    onOpenLink: onOpenLink,
    onMessage: onMessage,
  );
  return (bridge: bridge, view: ScriptedView(pipe.viewSide));
}

void main() {
  test('requests before ui/initialize are refused', () async {
    final t = setup();
    final answer = await t.view.request('tools/call', {'name': 'refresh_data'});
    expect(answer, isA<JsonRpcError>());
    expect((answer as JsonRpcError).code, -32002);
    expect(t.bridge.state, BridgeState.awaitingInitialize);
  });

  test(
      'initialize result carries version, host info, context and computed capabilities',
      () async {
    final t = setup(onOpenLink: (_) async => true);
    final result = ((await t.view.initialize()) as JsonRpcResult).result;
    expect(result['protocolVersion'], '2026-01-26');
    expect(result['hostInfo'], {'name': 'test-host', 'version': '1.2.3'});
    expect((result['hostContext']! as Map)['theme'], 'dark');
    final caps = result['hostCapabilities']! as Map;
    expect(caps.containsKey('openLinks'), isTrue);
    expect(caps.containsKey('serverTools'), isTrue);
    // No handler for these, so they are not advertised. Draft download is never.
    expect(caps.containsKey('message'), isFalse);
    expect(caps.containsKey('updateModelContext'), isFalse);
    expect(caps.containsKey('logging'), isFalse);
    expect(caps.containsKey('downloadFile'), isFalse);
    expect(t.bridge.state, BridgeState.awaitingInitialized);
  });

  test('capabilities follow the handlers that were given', () async {
    final t = setup(onMessage: (_) async => true);
    final caps = (((await t.view.initialize()) as JsonRpcResult)
        .result['hostCapabilities']!) as Map;
    expect(caps.containsKey('message'), isTrue);
    expect(caps.containsKey('openLinks'), isFalse);
  });

  test('notifications wait for initialized, then arrive in order', () async {
    final t = setup();
    t.bridge.sendToolInput({'n': 1});
    t.bridge.sendToolResult({'content': []});
    expect(t.bridge.queuedCount, 2);

    await t.view.initialize();
    await t.view.barrier();
    expect(t.view.notifications, isEmpty, reason: 'nothing before initialized');

    t.view.sendInitialized();
    await t.view.barrier();
    expect(t.view.notifications.map((n) => n.method),
        [UiMethods.toolInput, UiMethods.toolResult]);
    expect(t.bridge.queuedCount, 0);
    expect(t.bridge.state, BridgeState.ready);

    // After the handshake notifications go out directly.
    t.bridge.sendToolCancelled('user');
    await t.view.barrier();
    expect(t.view.notifications, hasLength(3));
  });

  test('the queue is bounded and drops the oldest', () async {
    final pipe = MemoryPipe();
    final bridge = HostBridge(
      transport: pipe.hostSide,
      server: FakeMcpServer(),
      hostInfo: const HostInfo(name: 't', version: '1'),
      hostContext: const HostContext(),
      maxQueued: 2,
    );
    bridge.sendToolInput({'n': 1});
    bridge.sendToolInput({'n': 2});
    bridge.sendToolInput({'n': 3});
    expect(bridge.queuedCount, 2);
    expect(bridge.audit.single.kind, 'queue');
  });
}
