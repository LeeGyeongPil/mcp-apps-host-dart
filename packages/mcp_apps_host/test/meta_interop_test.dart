import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/mcp_dart.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:test/test.dart';

void main() {
  final modern = <String, Object?>{
    'name': 'show_chart',
    'inputSchema': {'type': 'object'},
    '_meta': {
      'ui': {
        'resourceUri': 'ui://chart/view',
        'visibility': ['app'],
      },
    },
  };
  final legacy = <String, Object?>{
    'name': 'old_chart',
    'inputSchema': {'type': 'object'},
    '_meta': {'ui/resourceUri': 'ui://old/view'},
  };
  final plain = <String, Object?>{
    'name': 'plain',
    'inputSchema': {'type': 'object'},
  };

  test('reads both the current and the legacy resourceUri key', () {
    expect(UiToolMeta.fromTool(modern).resourceUri, 'ui://chart/view');
    expect(UiToolMeta.fromTool(legacy).resourceUri, 'ui://old/view');
    expect(UiToolMeta.fromTool(plain).resourceUri, isNull);
  });

  test('visibility defaults to model and app', () {
    final meta = UiToolMeta.fromTool(legacy);
    expect(meta.visibleToApp, isTrue);
    expect(meta.visibleToModel, isTrue);
    expect(UiToolMeta.fromTool(modern).visibleToModel, isFalse);
  });

  test('modelVisibleTools drops app-only tools', () {
    final names =
        modelVisibleTools([modern, legacy, plain]).map((t) => t['name']);
    expect(names, ['old_chart', 'plain']);
  });

  test('resource metadata exposes the CSP declaration', () {
    final meta = UiResourceMeta.fromResource({
      '_meta': {
        'ui': {
          'csp': {
            'connectDomains': ['https://api.example.com']
          },
          'prefersBorder': true,
        },
      },
    });
    expect(meta.csp!.connectDomains, ['https://api.example.com']);
    expect(meta.prefersBorder, isTrue);
  });

  test('agrees with mcp_dart 2.4.3', () {
    expect(mcp.Tool.fromJson(modern).mcpUiMeta?.resourceUri,
        UiToolMeta.fromTool(modern).resourceUri);
    expect(mcp.mcpUiExtensionId, UiMethods.extensionId);
    expect(mcp.mcpUiResourceMimeType, UiMethods.mimeType);
  });

  test('client capabilities announce the MIME type', () {
    expect(mcpAppsClientCapabilities(), {
      'io.modelcontextprotocol/ui': {
        'mimeTypes': ['text/html;profile=mcp-app'],
      },
    });
  });
}
