import 'methods.dart';
import 'types.dart';

Map<String, Object?>? _asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

/// UI metadata of a tool (`_meta.ui`).
class UiToolMeta {
  const UiToolMeta({this.resourceUri, required this.visibility});

  /// Reads the metadata from a tool definition (a `tools/list` entry).
  ///
  /// Understands the current `_meta.ui.resourceUri` key and the legacy flat
  /// key that older servers still send. A missing `visibility` means
  /// `["model", "app"]`, as the spec says.
  factory UiToolMeta.fromTool(Map<String, Object?> tool) {
    final meta = _asMap(tool['_meta']);
    final ui = _asMap(meta?['ui']);
    final uri = ui?['resourceUri'] ?? meta?[UiMethods.legacyResourceUriKey];
    final raw = ui?['visibility'];
    final visibility = raw is List
        ? raw.map(ToolVisibility.tryParse).whereType<ToolVisibility>().toList()
        : const [ToolVisibility.model, ToolVisibility.app];
    return UiToolMeta(
      resourceUri: uri is String ? uri : null,
      visibility: visibility,
    );
  }

  final String? resourceUri;
  final List<ToolVisibility> visibility;

  bool get visibleToApp => visibility.contains(ToolVisibility.app);
  bool get visibleToModel => visibility.contains(ToolVisibility.model);
}

/// UI metadata of a `ui://` resource (`_meta.ui` of the resource contents).
class UiResourceMeta {
  const UiResourceMeta(
      {this.csp, this.permissions, this.domain, this.prefersBorder});

  /// Reads the metadata from a resource contents entry (an item of the
  /// `contents` list of a `resources/read` result).
  factory UiResourceMeta.fromResource(Map<String, Object?> resource) {
    final ui = _asMap(_asMap(resource['_meta'])?['ui']);
    final csp = _asMap(ui?['csp']);
    final domain = ui?['domain'];
    final border = ui?['prefersBorder'];
    return UiResourceMeta(
      csp: csp == null ? null : UiCsp.fromJson(csp),
      permissions: _asMap(ui?['permissions']),
      domain: domain is String ? domain : null,
      prefersBorder: border is bool ? border : null,
    );
  }

  final UiCsp? csp;
  final Map<String, Object?>? permissions;
  final String? domain;
  final bool? prefersBorder;
}

/// [tools] without the app-only ones, i.e. what may be shown to the model.
List<Map<String, Object?>> modelVisibleTools(
        List<Map<String, Object?>> tools) =>
    tools.where((t) => UiToolMeta.fromTool(t).visibleToModel).toList();
