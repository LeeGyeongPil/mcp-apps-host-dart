import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:test/test.dart';

const defaults = [
  "default-src 'none'",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data:",
  "media-src 'self' data:",
  "connect-src 'none'",
];

void main() {
  group('CspBuilder', () {
    test('no declaration gives exactly the six default directives', () {
      expect(CspBuilder.build().split('; '), defaults);
      expect(CspBuilder.build(const UiCsp()).split('; '), defaults);
    });

    test('declared domains go to their own directive only', () {
      final csp = CspBuilder.build(const UiCsp(
        connectDomains: ['https://api.example.com'],
        resourceDomains: ['https://cdn.example.com'],
        frameDomains: ['https://embed.example.com'],
        baseUriDomains: ['https://base.example.com'],
      ));
      final directives = {
        for (final d in csp.split('; ')) d.split(' ').first: d,
      };
      expect(directives['connect-src'], 'connect-src https://api.example.com');
      expect(directives['script-src'],
          "script-src 'self' 'unsafe-inline' https://cdn.example.com");
      expect(directives['frame-src'], 'frame-src https://embed.example.com');
      expect(directives['base-uri'], 'base-uri https://base.example.com');
      expect(directives['default-src'], "default-src 'none'");
      expect(directives['connect-src']!.contains('cdn.example.com'), isFalse);
      expect(directives['frame-src']!.contains('api.example.com'), isFalse);
    });

    test('never wider than the default: bad declarations are dropped', () {
      final csp = CspBuilder.build(const UiCsp(
        connectDomains: [
          '*',
          "'unsafe-eval'",
          'https://a.com; script-src *',
          'https://ok.example.com'
        ],
      ));
      expect(csp, contains('connect-src https://ok.example.com'));
      expect(csp.split('; ').where((d) => d.startsWith('script-src')),
          [defaults[1]]);
      expect(csp, isNot(contains('unsafe-eval')));
      expect(csp, isNot(contains(' * ')));
    });
  });

  group('HtmlInjector', () {
    const csp = "default-src 'none'";
    const shim = 'window.__x=1;';

    test('puts CSP meta and shim first in <head>, before document scripts', () {
      final out = HtmlInjector.prepare(
          '<!doctype html><html><head><title>t</title><script>doc()</script></head><body></body></html>',
          csp: csp,
          shim: shim);
      final meta = out.indexOf('<meta http-equiv="Content-Security-Policy"');
      expect(out.indexOf('<head>') + '<head>'.length, meta);
      expect(out.indexOf(shim), lessThan(out.indexOf('doc()')));
      expect(meta, lessThan(out.indexOf('<title>')));
    });

    test('handles head attributes and upper case', () {
      final out = HtmlInjector.prepare(
          '<HTML><HEAD lang="x"><title>t</title></HEAD></HTML>',
          csp: csp,
          shim: shim);
      expect(out, startsWith('<HTML><HEAD lang="x"><meta '));
    });

    test('does not mistake <header> for <head>', () {
      final out = HtmlInjector.prepare(
          '<html><body><header>h</header></body></html>',
          csp: csp,
          shim: shim);
      expect(out, startsWith('<html><head><meta '));
    });

    test('creates a head when missing, after the doctype', () {
      final out = HtmlInjector.prepare('<!doctype html><p>hi</p>',
          csp: csp, shim: shim);
      expect(out, startsWith('<!doctype html><head><meta '));
      expect(out, endsWith('</head><p>hi</p>'));
      expect(HtmlInjector.prepare('<p>hi</p>', csp: csp, shim: shim),
          startsWith('<head><meta '));
    });

    test('a quote in the policy cannot break out of the attribute', () {
      final out = HtmlInjector.prepare('<head></head>', csp: 'a"b', shim: shim);
      expect(out, contains('content="a&quot;b"'));
    });
  });
}
