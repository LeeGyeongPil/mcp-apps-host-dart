import '../server_adapter.dart';

/// An in-memory MCP server for tests and examples.
///
/// It offers three tools and one `ui://` resource:
/// - `show_dashboard`: no visibility given, so model and app both see it
/// - `refresh_data`: visible to the app only
/// - `delete_all`: visible to the model only
class FakeMcpServer implements McpServerAdapter {
  FakeMcpServer({List<Map<String, Object?>>? tools, String? dashboardHtml})
      : tools = tools ?? defaultTools(),
        dashboardHtml = dashboardHtml ?? defaultDashboardHtml;

  /// Tool definitions returned by [listTools].
  final List<Map<String, Object?>> tools;

  /// The HTML served for [dashboardUri].
  final String dashboardHtml;

  /// URI of the demo View.
  static const dashboardUri = 'ui://demo/dashboard';

  /// Names of the tools called so far, in order.
  final List<String> calls = [];

  /// A small View document written for this package.
  static const defaultDashboardHtml = '''<!doctype html>
<html>
<head><title>Demo dashboard</title></head>
<body>
<h1 id="title">Demo dashboard</h1>
<script>document.getElementById('title').textContent += ' (ready)';</script>
</body>
</html>''';

  static List<Map<String, Object?>> defaultTools() => [
        {
          'name': 'show_dashboard',
          'description': 'Show the dashboard',
          'inputSchema': {'type': 'object'},
          '_meta': {
            'ui': {'resourceUri': dashboardUri},
          },
        },
        {
          'name': 'refresh_data',
          'description': 'Reload dashboard data (called by the View)',
          'inputSchema': {'type': 'object'},
          '_meta': {
            'ui': {
              'resourceUri': dashboardUri,
              'visibility': ['app'],
            },
          },
        },
        {
          'name': 'delete_all',
          'description': 'Delete everything (model only)',
          'inputSchema': {'type': 'object'},
          '_meta': {
            'ui': {
              'resourceUri': dashboardUri,
              'visibility': ['model'],
            },
          },
        },
      ];

  @override
  Future<List<Map<String, Object?>>> listTools() async => tools;

  @override
  Future<Map<String, Object?>> callTool(
      String name, Map<String, Object?> arguments) async {
    calls.add(name);
    return {
      'content': [
        {'type': 'text', 'text': 'ok: $name'}
      ],
    };
  }

  @override
  Future<Map<String, Object?>> readResource(String uri) async {
    if (uri != dashboardUri) {
      throw McpAppsRpcException(-32002, 'Resource not found: $uri');
    }
    return {
      'contents': [
        {
          'uri': dashboardUri,
          'mimeType': 'text/html;profile=mcp-app',
          'text': dashboardHtml,
          '_meta': {
            'ui': {
              'csp': {
                'connectDomains': ['https://api.example.com'],
              },
            },
          },
        }
      ],
    };
  }
}
