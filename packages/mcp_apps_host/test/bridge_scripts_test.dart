import 'dart:convert';

import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:test/test.dart';

void main() {
  group('shim', () {
    test('overrides window.parent.postMessage and forwards to the channel', () {
      final script = BridgeScripts.shim();
      expect(script, contains('window.parent.postMessage = function'));
      expect(script, contains('window.mcpBridge.postMessage(text)'));
      expect(script, contains('JSON.stringify(message)'));
    });

    test('channel name is configurable and validated', () {
      expect(BridgeScripts.shim(channel: 'other'),
          contains('window.other.postMessage'));
      expect(
          () => BridgeScripts.shim(channel: 'a;alert(1)'), throwsArgumentError);
    });
  });

  group('dispatch', () {
    final literalPattern = RegExp(r'JSON\.parse\((".*")\)');

    test('builds a MessageEvent whose source is window', () {
      final script = BridgeScripts.dispatch('{"jsonrpc":"2.0","method":"x"}');
      expect(script, contains("new MessageEvent('message'"));
      expect(script, contains('source: window'));
      expect(script, startsWith('window.dispatchEvent('));
    });

    test(
        'escapes script terminators and quotes, and decodes back to the original',
        () {
      final ls = String.fromCharCode(0x2028);
      final ps = String.fromCharCode(0x2029);
      final payload = jsonEncode({
        'text': "</script><script>alert('x')</script> $ls $ps \"q\" \\ done",
      });
      final script = BridgeScripts.dispatch(payload);

      expect(script.toLowerCase(), isNot(contains('</script')));
      expect(script, isNot(contains(ls)));
      expect(script, isNot(contains(ps)));
      expect(script, isNot(contains("alert('x')")));
      // The only single quotes left belong to our own "'message'".
      expect("'".allMatches(script).length, 2);

      final literal = literalPattern.firstMatch(script)!.group(1)!;
      expect(jsonDecode(literal), payload);
    });
  });
}
