import 'package:mcp_apps_host/mcp_apps_host.dart';
import 'package:mcp_apps_host/testing.dart';

Future<void> main() async {
  final pipe = MemoryPipe();
  final bridge = HostBridge(
    transport: pipe.hostSide,
    server: FakeMcpServer(),
    hostInfo: const HostInfo(name: 'my-app', version: '1.0.0'),
    hostContext: const HostContext(theme: 'dark', platform: 'desktop'),
  );
  final view = ScriptedView(pipe.viewSide);
  bridge.sendToolInput({'city': 'Seoul'}); // held until the View is ready
  await view.initialize();
  print('queued before initialized: ${bridge.queuedCount}');
  view.sendInitialized();
  await view.barrier();
  print('View received: ${view.notifications.map((n) => n.method).join(', ')}');
  final r = await view.request('tools/call', {'name': 'delete_all'});
  print('delete_all -> ${(r as JsonRpcError).message}');
  await bridge.close();
  await pipe.close();
}
