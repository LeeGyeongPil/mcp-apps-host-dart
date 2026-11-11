/// Name and version of the host application, sent in the `ui/initialize` result.
class HostInfo {
  const HostInfo({required this.name, required this.version});

  final String name;
  final String version;

  Map<String, Object?> toJson() => {'name': name, 'version': version};
}

/// Insets in CSS pixels that the View should keep free (notches, system bars).
class SafeAreaInsets {
  const SafeAreaInsets({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  final double top;
  final double right;
  final double bottom;
  final double left;

  Map<String, Object?> toJson() =>
      {'top': top, 'right': right, 'bottom': bottom, 'left': left};
}

/// Information about the host environment, sent in `ui/initialize` and in
/// `ui/notifications/host-context-changed`.
class HostContext {
  const HostContext({
    this.theme,
    this.platform,
    this.displayMode,
    this.availableDisplayModes,
    this.locale,
    this.timeZone,
    this.userAgent,
    this.safeAreaInsets,
    this.touch,
    this.hover,
    this.maxHeight,
    this.maxWidth,
    this.height,
    this.width,
  });

  /// `light` or `dark`.
  final String? theme;

  /// `web`, `desktop` or `mobile`.
  final String? platform;

  /// `inline`, `fullscreen` or `pip`.
  final String? displayMode;
  final List<String>? availableDisplayModes;
  final String? locale;
  final String? timeZone;
  final String? userAgent;
  final SafeAreaInsets? safeAreaInsets;
  final bool? touch;
  final bool? hover;
  final double? maxHeight;
  final double? maxWidth;
  final double? height;
  final double? width;

  /// Wire form. Unset fields are left out.
  Map<String, Object?> toJson() {
    final dimensions = <String, Object?>{
      if (height != null) 'height': height,
      if (maxHeight != null) 'maxHeight': maxHeight,
      if (width != null) 'width': width,
      if (maxWidth != null) 'maxWidth': maxWidth,
    };
    final capabilities = <String, Object?>{
      if (touch != null) 'touch': touch,
      if (hover != null) 'hover': hover,
    };
    return {
      if (theme != null) 'theme': theme,
      if (platform != null) 'platform': platform,
      if (displayMode != null) 'displayMode': displayMode,
      if (availableDisplayModes != null)
        'availableDisplayModes': availableDisplayModes,
      if (locale != null) 'locale': locale,
      if (timeZone != null) 'timeZone': timeZone,
      if (userAgent != null) 'userAgent': userAgent,
      if (safeAreaInsets != null) 'safeAreaInsets': safeAreaInsets!.toJson(),
      if (capabilities.isNotEmpty) 'deviceCapabilities': capabilities,
      if (dimensions.isNotEmpty) 'containerDimensions': dimensions,
    };
  }
}

/// Who may call a tool: the model, the View (`app`), or both.
enum ToolVisibility {
  model,
  app;

  static ToolVisibility? tryParse(Object? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// CSP declarations from a resource's `_meta.ui.csp`.
class UiCsp {
  const UiCsp({
    this.connectDomains = const [],
    this.resourceDomains = const [],
    this.frameDomains = const [],
    this.baseUriDomains = const [],
  });

  factory UiCsp.fromJson(Map<String, Object?> json) {
    List<String> strings(String key) {
      final v = json[key];
      return v is List ? v.whereType<String>().toList() : const [];
    }

    return UiCsp(
      connectDomains: strings('connectDomains'),
      resourceDomains: strings('resourceDomains'),
      frameDomains: strings('frameDomains'),
      baseUriDomains: strings('baseUriDomains'),
    );
  }

  /// Origins for `fetch`, XHR and WebSocket (`connect-src`).
  final List<String> connectDomains;

  /// Origins for scripts, styles, images, fonts and media.
  final List<String> resourceDomains;

  /// Origins for nested frames (`frame-src`).
  final List<String> frameDomains;

  /// Origins allowed in `<base href>` (`base-uri`).
  final List<String> baseUriDomains;

  Map<String, Object?> toJson() => {
        'connectDomains': connectDomains,
        'resourceDomains': resourceDomains,
        'frameDomains': frameDomains,
        'baseUriDomains': baseUriDomains,
      };
}

/// Size reported by the View in `ui/notifications/size-changed`.
class ViewSize {
  const ViewSize({this.width, this.height});

  final double? width;
  final double? height;

  @override
  String toString() => 'ViewSize(width: $width, height: $height)';
}

/// Outcome of a policy decision.
enum Decision { allowed, denied }

/// One line of the audit trail kept by the bridge.
class AuditEntry {
  const AuditEntry({
    required this.kind,
    required this.subject,
    required this.decision,
    this.reason = '',
  });

  /// What was decided, for example `tools/call` or `ui/open-link`.
  final String kind;

  /// Tool name, URL or method the decision is about.
  final String subject;
  final Decision decision;
  final String reason;

  @override
  String toString() =>
      '${decision.name} $kind $subject${reason.isEmpty ? '' : ' ($reason)'}';
}

/// A log message sent by the View (`notifications/message`).
class LogEntry {
  const LogEntry({required this.level, required this.data, this.logger});

  final String level;
  final Object? data;
  final String? logger;
}

/// Thrown when something is sent through a bridge that is already closed.
class BridgeClosedException implements Exception {
  const BridgeClosedException([this.message = 'The bridge is closed']);

  final String message;

  @override
  String toString() => 'BridgeClosedException: $message';
}
