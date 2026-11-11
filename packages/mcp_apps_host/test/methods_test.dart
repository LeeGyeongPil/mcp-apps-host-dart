import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:test/test.dart';

import 'fixtures/ext_apps_2_0_4_methods.dart';

void main() {
  test('UiMethods.all equals the 17 ui/* methods of ext-apps 2.0.4', () {
    expect(extApps204UiMethods, hasLength(17));
    expect(UiMethods.all.difference(extApps204UiMethods), isEmpty,
        reason: 'constants the schema does not have');
    expect(extApps204UiMethods.difference(UiMethods.all), isEmpty,
        reason: 'schema methods without a constant');
  });

  test('protocol version, extension id and MIME type match the spec', () {
    expect(UiMethods.protocolVersion, '2026-01-26');
    expect(UiMethods.extensionId, 'io.modelcontextprotocol/ui');
    expect(UiMethods.mimeType, 'text/html;profile=mcp-app');
  });
}
