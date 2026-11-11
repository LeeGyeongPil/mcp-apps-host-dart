import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart' as mcp;

import 'server_adapter.dart';

/// The `clientCapabilities.extensions` entry that tells an MCP server this
/// client can render `ui://` resources:
/// `{"io.modelcontextprotocol/ui": {"mimeTypes": ["text/html;profile=mcp-app"]}}`.
///
/// Reuses `withMcpUiExtension()` of `mcp_dart`.
Map<String, Object?> mcpAppsClientCapabilities() {
  final json = jsonDecode(jsonEncode(mcp.withMcpUiExtension()));
  return (json as Map).cast<String, Object?>();
}

/// A [McpServerAdapter] on top of a connected `mcp_dart` client.
class McpDartServerAdapter implements McpServerAdapter {
  McpDartServerAdapter(this.client);

  /// A client that already finished `connect`.
  final mcp.McpClient client;

  Map<String, Object?> _plain(Map<String, dynamic> json) =>
      (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

  @override
  Future<List<Map<String, Object?>>> listTools() async {
    final tools = <Map<String, Object?>>[];
    String? cursor;
    do {
      final page = await client.listTools(
          params: cursor == null ? null : mcp.ListToolsRequest(cursor: cursor));
      tools.addAll(page.tools.map((t) => _plain(t.toJson())));
      cursor = page.nextCursor;
    } while (cursor != null);
    return tools;
  }

  @override
  Future<Map<String, Object?>> callTool(
      String name, Map<String, Object?> arguments) async {
    final result = await client
        .callTool(mcp.CallToolRequest(name: name, arguments: arguments));
    return _plain(result.toJson());
  }

  @override
  Future<Map<String, Object?>> readResource(String uri) async {
    final result = await client.readResource(mcp.ReadResourceRequest(uri: uri));
    return _plain(result.toJson());
  }
}
