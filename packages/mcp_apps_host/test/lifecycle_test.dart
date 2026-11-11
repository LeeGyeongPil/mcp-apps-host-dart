import 'dart:async';

import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:test/test.dart';

class Rig {
  Rig({OpenLinkHandler? onOpenLink, bool answerTeardown = true}) {
    final pipe = MemoryPipe();
    bridge = HostBridge(
      transport: pipe.hostSide,
      server: FakeMcpServer(),
      hostInfo: const HostInfo(name: 't', version: '1'),
      hostContext: const HostContext(),
      onOpenLink: onOpenLink,
      onSizeChanged: sizes.add,
      onLog: logs.add,
    );
    view = ScriptedView(pipe.viewSide, answerTeardown: answerTeardown);
  }

  late final HostBridge bridge;
  late final ScriptedView view;
  final sizes = <ViewSize>[];
  final logs = <LogEntry>[];

  Future<void> ready() async {
    await view.initialize();
    view.sendInitialized();
    await view.barrier();
  }
}

int codeOf(JsonRpcMessage m) => (m as JsonRpcError).code;
String messageOf(JsonRpcMessage m) => (m as JsonRpcError).message;

void main() {
  test('teardown sends ui/resource-teardown and closes after the answer',
      () async {
    final r = Rig();
    await r.ready();
    final states = <BridgeState>[];
    r.bridge.stateChanges.listen(states.add);
    await r.bridge.teardown('done');
    expect(r.bridge.state, BridgeState.closed);
    expect(r.view.received.whereType<JsonRpcRequest>().map((m) => m.method),
        [UiMethods.resourceTeardown]);
    await Future<void>.delayed(Duration.zero);
    expect(states, [BridgeState.closed]);
  });

  test('without an answer and a zero timeout: TimeoutException, still closed',
      () async {
    final r = Rig(answerTeardown: false);
    await r.ready();
    await expectLater(r.bridge.teardown('done', timeout: Duration.zero),
        throwsA(isA<TimeoutException>()));
    expect(r.bridge.state, BridgeState.closed);
  });

  test('requests after close are refused with -32000; sending throws',
      () async {
    final r = Rig();
    await r.ready();
    await r.bridge.teardown('done');
    final answer = await r.view.request('ping');
    expect(codeOf(answer), -32000);
    expect(() => r.bridge.sendToolInput({}),
        throwsA(isA<BridgeClosedException>()));
  });

  group('ui/open-link', () {
    test('only http and https', () async {
      final r = Rig(onOpenLink: (_) async => true);
      await r.ready();
      for (final url in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'not a url'
      ]) {
        final answer = await r.view.request(UiMethods.openLink, {'url': url});
        expect(codeOf(answer), -32000, reason: url);
        expect(messageOf(answer), 'Invalid URL');
      }
    });

    test('handler returning false is reported as denied by user', () async {
      final r = Rig(onOpenLink: (_) async => false);
      await r.ready();
      final answer = await r.view
          .request(UiMethods.openLink, {'url': 'https://example.com'});
      expect(messageOf(answer), 'Link opening denied by user');
    });

    test('allowed link reaches the handler', () async {
      final opened = <Uri>[];
      final r = Rig(onOpenLink: (u) async {
        opened.add(u);
        return true;
      });
      await r.ready();
      expect(
          await r.view
              .request(UiMethods.openLink, {'url': 'https://example.com/a'}),
          isA<JsonRpcResult>());
      expect(opened.single.host, 'example.com');
    });
  });

  test('size-changed and log notifications reach the callbacks', () async {
    final r = Rig();
    await r.ready();
    r.view.notify(UiMethods.sizeChanged, {'width': 300, 'height': 420});
    r.view.notify('notifications/message', {'level': 'warning', 'data': 'hi'});
    await r.view.barrier();
    expect(r.sizes.single.height, 420);
    expect(r.sizes.single.width, 300);
    expect(r.logs.single.level, 'warning');
  });

  test('unknown methods give -32601, also draft download-file', () async {
    final r = Rig();
    await r.ready();
    expect(codeOf(await r.view.request('ui/nope')), -32601);
    expect(codeOf(await r.view.request(UiMethods.downloadFile)), -32601);
  });

  test('a second ui/initialize is refused', () async {
    final r = Rig();
    await r.ready();
    expect(codeOf(await r.view.initialize()), -32600);
  });

  test('server errors become JSON-RPC errors', () async {
    final r = Rig();
    await r.ready();
    final answer =
        await r.view.request('resources/read', {'uri': 'ui://missing'});
    expect(codeOf(answer), -32002);
  });
}
