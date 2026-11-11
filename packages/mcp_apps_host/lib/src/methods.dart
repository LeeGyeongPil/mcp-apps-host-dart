/// Wire-level constants of the MCP Apps (SEP-1865) extension.
///
/// Method names are checked against `@modelcontextprotocol/ext-apps` 2.0.4
/// (`dist/src/generated/schema.json`, checked 2026-11-10) by the test suite.
abstract final class UiMethods {
  /// Spec revision implemented by this package.
  static const protocolVersion = '2026-01-26';

  /// Extension identifier used in capability negotiation.
  static const extensionId = 'io.modelcontextprotocol/ui';

  /// MIME type of `ui://` resources.
  static const mimeType = 'text/html;profile=mcp-app';

  /// Legacy flat `_meta` key that older servers still send.
  static const legacyResourceUriKey = 'ui/resourceUri';

  // View -> Host requests.
  static const initialize = 'ui/initialize';
  static const openLink = 'ui/open-link';
  static const message = 'ui/message';
  static const requestDisplayMode = 'ui/request-display-mode';
  static const updateModelContext = 'ui/update-model-context';

  /// Draft in ext-apps 2.x, not part of the 2026-01-26 spec. Never advertised.
  static const downloadFile = 'ui/download-file';

  // View -> Host notifications.
  static const initialized = 'ui/notifications/initialized';
  static const sizeChanged = 'ui/notifications/size-changed';

  /// Draft in ext-apps 2.x. Received notifications are only audited.
  static const requestTeardown = 'ui/notifications/request-teardown';

  // Host -> View notifications.
  static const toolInput = 'ui/notifications/tool-input';
  static const toolInputPartial = 'ui/notifications/tool-input-partial';
  static const toolResult = 'ui/notifications/tool-result';
  static const toolCancelled = 'ui/notifications/tool-cancelled';
  static const hostContextChanged = 'ui/notifications/host-context-changed';

  // Host -> View request.
  static const resourceTeardown = 'ui/resource-teardown';

  // Web hosts only (double-iframe sandbox). Native WebView hosts do not use
  // them; the names are kept so the full list can be compared with the schema.
  static const sandboxProxyReady = 'ui/notifications/sandbox-proxy-ready';
  static const sandboxResourceReady = 'ui/notifications/sandbox-resource-ready';

  /// Every `ui/*` method name in the schema.
  static const Set<String> all = {
    initialize,
    openLink,
    message,
    requestDisplayMode,
    updateModelContext,
    downloadFile,
    initialized,
    sizeChanged,
    requestTeardown,
    toolInput,
    toolInputPartial,
    toolResult,
    toolCancelled,
    hostContextChanged,
    resourceTeardown,
    sandboxProxyReady,
    sandboxResourceReady,
  };
}
