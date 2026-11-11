import 'package:test/test.dart';

import '../example/mcp_apps_host_example.dart';

void main() {
  test('mock mode shows the lessons and exits with 0', () async {
    final out = StringBuffer();
    expect(await runExample(out), 0);
    final text = out.toString();
    expect(text.split('\n').first, contains('mock'));
    for (final line in [
      '[handshake] protocolVersion=2026-01-26',
      '[queue] held 2',
      '[deny] tools/call delete_all',
      '[approve] asked 1 time(s) for 3 call(s)',
      "[csp] default-src 'none'",
      '[teardown] state=closed',
    ]) {
      expect(text, contains(line));
    }
  });

  test('--print-html prints a document with the CSP meta before its script',
      () async {
    final out = StringBuffer();
    expect(await runExample(out, args: ['--print-html']), 0);
    final text = out.toString();
    expect(text.indexOf('Content-Security-Policy'),
        lessThan(text.indexOf('(ready)')));
  });
}
