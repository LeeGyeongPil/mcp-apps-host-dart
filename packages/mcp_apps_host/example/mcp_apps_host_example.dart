// Example: drive a real HostBridge with a scripted View.
//
//   dart run example/mcp_apps_host_example.dart                 mock mode (default)
//   dart run example/mcp_apps_host_example.dart --print-html    print the prepared HTML
//   dart run example/mcp_apps_host_example.dart --server URL    use a real MCP server
//
// In mock mode only the View (ScriptedView) and the MCP server (FakeMcpServer)
// are fake. HostBridge, ToolCallPolicy, CspBuilder and HtmlInjector are the
// real code, so the output shows what they really do.
import 'dart:io';

import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/mcp_dart.dart';
import 'package:mcp_apps_host/testing.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;

Future<void> main(List<String> args) async {
  final code = await runExample(stdout, args: args);
  exit(code);
}

/// Runs the example and writes to [out]. Returns the process exit code.
Future<int> runExample(StringSink out, {List<String> args = const []}) async {
  final printHtml = args.contains('--print-html');
  final serverIndex = args.indexOf('--server');
  final serverUrl = serverIndex >= 0 && serverIndex + 1 < args.length
      ? args[serverIndex + 1]
      : null;

  mcp.McpClient? client;
  McpServerAdapter server;
  if (serverUrl == null) {
    // --print-html prints only the document, so it can be piped to a file.
    if (!printHtml) {
      out.writeln(
          '[mock] practice mode: the View and the MCP server are fakes; '
          'HostBridge, ToolCallPolicy, CspBuilder and HtmlInjector are real.');
    }
    server = FakeMcpServer();
  } else {
    if (!printHtml) out.writeln('[real] connecting to $serverUrl');
    try {
      client = mcp.McpClient(const mcp.Implementation(
          name: 'mcp-apps-host-example', version: '0.1.0'));
      await client
          .connect(mcp.StreamableHttpClientTransport(Uri.parse(serverUrl)));
      server = McpDartServerAdapter(client);
    } catch (e) {
      out.writeln('[error] could not connect: $e');
      return 2;
    }
  }

  try {
    return await _scenario(out, server,
        printHtml: printHtml, real: serverUrl != null);
  } catch (e) {
    out.writeln('[error] $e');
    return 2;
  } finally {
    await client?.close();
  }
}

Future<int> _scenario(StringSink out, McpServerAdapter server,
    {required bool printHtml, required bool real}) async {
  // 1. Find a tool that has a View, read the View document, build the CSP.
  final tools = await server.listTools();
  final withUi =
      tools.where((t) => UiToolMeta.fromTool(t).resourceUri != null).toList();
  if (withUi.isEmpty) {
    out.writeln('[error] the server has no tool with _meta.ui.resourceUri');
    return 2;
  }
  final uri = UiToolMeta.fromTool(withUi.first).resourceUri!;
  final contents =
      (await server.readResource(uri))['contents']! as List<Object?>;
  final resource = (contents.first! as Map).cast<String, Object?>();
  final csp = CspBuilder.build(UiResourceMeta.fromResource(resource).csp);
  final html = HtmlInjector.prepare('${resource['text']}',
      csp: csp, shim: BridgeScripts.shim());
  if (printHtml) {
    out.writeln(html);
    return 0;
  }
  out.writeln('[csp] $csp');
  out.writeln('[html] prepared ${html.length} chars: CSP meta and shim are '
      'the first children of <head>');

  final appTools = withUi
      .where((t) => UiToolMeta.fromTool(t).visibleToApp)
      .map((t) => '${t['name']}')
      .toList();
  out.writeln('[tools] app can call: ${appTools.join(', ')}');

  // 2. Connect a bridge to a scripted View. Ask once per tool per session.
  var asked = 0;
  final pipe = MemoryPipe();
  final bridge = HostBridge(
    transport: pipe.hostSide,
    server: server,
    hostInfo: const HostInfo(name: 'example-host', version: '0.1.0'),
    hostContext: const HostContext(
        theme: 'dark', platform: 'desktop', displayMode: 'inline'),
    policy: ToolCallPolicy(
      mode: ApprovalMode.perToolPerSession,
      approver: (request) async {
        asked++;
        return true;
      },
    ),
    onOpenLink: (url) async => false,
  );
  final view = ScriptedView(pipe.viewSide);

  // 3. The host has data before the View is ready: it must wait.
  bridge.sendToolInput({'city': 'Seoul'});
  bridge.sendToolResult({'content': []});
  final init = await view.initialize();
  await view.barrier();
  out.writeln('[queue] held ${bridge.queuedCount}, View received '
      '${view.notifications.length} before initialized');
  final result = (init as JsonRpcResult).result;
  out.writeln('[handshake] protocolVersion=${result['protocolVersion']} '
      'capabilities=${(result['hostCapabilities']! as Map).keys.join(',')}');
  view.sendInitialized();
  await view.barrier();
  out.writeln('[queue] flushed, View received ${view.notifications.length} '
      'notifications in order: ${view.notifications.map((n) => n.method.split('/').last).join(', ')}');

  // 4. The View calls app tools; the user is asked once.
  var calls = 0;
  // Prefer a tool that only the View may call (visibility: [app]).
  final appOnly = withUi
      .where((t) => !UiToolMeta.fromTool(t).visibleToModel)
      .map((t) => '${t['name']}')
      .toList();
  final target = appOnly.isNotEmpty
      ? appOnly.first
      : (appTools.isNotEmpty ? appTools.first : null);
  if (target != null) {
    for (var i = 0; i < 3; i++) {
      await view.request('tools/call', {'name': target});
      calls++;
    }
    out.writeln('[approve] asked $asked time(s) for $calls call(s)');
  }

  // 5. A tool that is not for apps is refused without reaching the server.
  final modelOnly = tools
      .map((t) => '${t['name']}')
      .where((n) => !appTools.contains(n))
      .toList();
  for (final name in modelOnly.isEmpty ? ['delete_all'] : modelOnly.take(1)) {
    final answer = await view.request('tools/call', {'name': name});
    out.writeln('[deny] tools/call $name -> '
        '${answer is JsonRpcError ? '${answer.code} ${answer.message}' : 'allowed?!'}');
  }
  final badLink =
      await view.request(UiMethods.openLink, {'url': 'javascript:alert(1)'});
  out.writeln('[deny] ui/open-link javascript: -> '
      '${badLink is JsonRpcError ? badLink.message : 'allowed?!'}');

  out.writeln('[audit] ${bridge.audit.length} decisions:');
  for (final entry in bridge.audit) {
    out.writeln('  $entry');
  }

  // 6. Close down; the View answers ui/resource-teardown.
  await bridge.teardown('example finished');
  out.writeln('[teardown] state=${bridge.state.name}');
  await bridge.close();
  await pipe.close();
  if (real) out.writeln('[real] done');
  return 0;
}
