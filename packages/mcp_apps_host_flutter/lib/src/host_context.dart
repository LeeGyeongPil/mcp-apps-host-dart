import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mcp_apps_host/mcp_apps_host.dart';

/// Builds the [HostContext] the View should see from the Flutter environment:
/// theme (light/dark), platform (mobile/desktop), locale, safe-area insets,
/// touch/hover capabilities and the width available to the View.
///
/// Reads `Theme` and `MediaQuery`, so the widget using it rebuilds when these change.
HostContext hostContextOf(BuildContext context, {double? maxHeight}) {
  final media = MediaQuery.of(context);
  final platform = defaultTargetPlatform;
  final mobile =
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  final locale = Localizations.maybeLocaleOf(context);
  final padding = media.viewPadding;
  return HostContext(
    theme: Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light',
    platform: mobile ? 'mobile' : 'desktop',
    displayMode: 'inline',
    availableDisplayModes: const ['inline'],
    locale: locale?.toLanguageTag(),
    safeAreaInsets: SafeAreaInsets(
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
      left: padding.left,
    ),
    touch: mobile,
    hover: !mobile,
    maxWidth: media.size.width,
    maxHeight: maxHeight,
  );
}
