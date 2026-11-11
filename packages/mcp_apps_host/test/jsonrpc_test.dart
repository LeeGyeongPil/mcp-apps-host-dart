import 'dart:convert';

import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:test/test.dart';

void main() {
  group('codec', () {
    final samples = <Map<String, Object?>>[
      {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ui/initialize',
        'params': {'a': 1}
      },
      {
        'jsonrpc': '2.0',
        'method': 'ui/notifications/size-changed',
        'params': {'height': 200}
      },
      {'jsonrpc': '2.0', 'id': 'a', 'result': <String, Object?>{}},
      {
        'jsonrpc': '2.0',
        'id': 2,
        'error': {'code': -32000, 'message': 'Invalid URL'}
      },
    ];

    test('request, notification, result and error round-trip', () {
      final types = <Type>[];
      for (final sample in samples) {
        final message = JsonRpcMessage.decode(jsonEncode(sample));
        types.add(message.runtimeType);
        expect(jsonDecode(message.encode()), sample);
      }
      expect(types,
          [JsonRpcRequest, JsonRpcNotification, JsonRpcResult, JsonRpcError]);
    });

    test('five kinds of invalid input throw FormatException', () {
      const bad = [
        '{broken',
        '[]',
        '{"method":"x"}',
        '{"jsonrpc":"2.0","id":1.5,"method":"x"}',
        '{"jsonrpc":"2.0","id":1}',
      ];
      for (final raw in bad) {
        expect(() => JsonRpcMessage.decode(raw), throwsFormatException,
            reason: raw);
      }
    });
  });

  test('the bridge answers a broken message with -32600', () async {
    final pipe = MemoryPipe();
    final bridge = HostBridge(
      transport: pipe.hostSide,
      server: FakeMcpServer(),
      hostInfo: const HostInfo(name: 't', version: '1'),
      hostContext: const HostContext(),
    );
    final view = ScriptedView(pipe.viewSide);
    view.sendRaw('{broken');
    final answer = await view.nextFromHost();
    expect(answer, isA<JsonRpcError>());
    expect((answer as JsonRpcError).code, -32600);
    await bridge.close();
  });
}
