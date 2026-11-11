import 'types.dart';

/// Builds the Content-Security-Policy a host applies to a View.
///
/// With no declaration the result is exactly the restrictive default of the
/// MCP Apps spec. Declared domains are appended to the directive they belong
/// to and nothing else is loosened: a host may tighten the policy, never
/// widen it.
abstract final class CspBuilder {
  // scheme://host:port/path with an optional leading "*." wildcard. No
  // spaces, semicolons, quotes or commas, so a declaration cannot smuggle in
  // a second directive. A bare "*" is rejected on purpose.
  static final RegExp _domain = RegExp(
    r'^(?:[a-zA-Z][a-zA-Z0-9+.\-]*:\/\/)?(?:\*\.)?[a-zA-Z0-9][a-zA-Z0-9.\-]*(?::\d{1,5})?(?:\/[a-zA-Z0-9._~\-\/%]*)?$',
  );

  /// Whether [domain] is accepted in a declaration.
  static bool isValidDomain(String domain) => _domain.hasMatch(domain);

  /// The policy string for [declared] (the resource's `_meta.ui.csp`).
  /// Invalid domains are dropped.
  static String build([UiCsp? declared]) {
    List<String> clean(List<String> input) =>
        input.where(isValidDomain).toSet().toList();
    final connect = clean(declared?.connectDomains ?? const []);
    final resource = clean(declared?.resourceDomains ?? const []);
    final frame = clean(declared?.frameDomains ?? const []);
    final base = clean(declared?.baseUriDomains ?? const []);

    String join(List<String> parts) => parts.join(' ');
    return [
      "default-src 'none'",
      "script-src ${join(["'self'", "'unsafe-inline'", ...resource])}",
      "style-src ${join(["'self'", "'unsafe-inline'", ...resource])}",
      "img-src ${join(["'self'", 'data:', ...resource])}",
      "media-src ${join(["'self'", 'data:', ...resource])}",
      "connect-src ${connect.isEmpty ? "'none'" : join(connect)}",
      if (resource.isNotEmpty) "font-src ${join(["'self'", ...resource])}",
      if (frame.isNotEmpty) 'frame-src ${join(frame)}',
      if (base.isNotEmpty) 'base-uri ${join(base)}',
    ].join('; ');
  }
}
