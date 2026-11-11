/// An error that is sent to the View as a JSON-RPC error with the same code.
///
/// Handlers and server adapters may throw it to choose the code and message.
class McpAppsRpcException implements Exception {
  const McpAppsRpcException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'McpAppsRpcException($code): $message';
}

/// The MCP server connection a bridge forwards View requests to.
///
/// One bridge talks to exactly one server. Implement this around any MCP
/// client; [McpDartServerAdapter] (in `package:mcp_apps_host/mcp_dart.dart`)
/// does it for `mcp_dart`.
abstract interface class McpServerAdapter {
  /// All tool definitions (`tools/list`, as JSON maps).
  Future<List<Map<String, Object?>>> listTools();

  /// Calls a tool and returns the `CallToolResult` as a JSON map.
  Future<Map<String, Object?>> callTool(
      String name, Map<String, Object?> arguments);

  /// Reads a resource and returns the `ReadResourceResult` as a JSON map.
  Future<Map<String, Object?>> readResource(String uri);
}
