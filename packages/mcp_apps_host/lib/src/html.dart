import 'dart:convert';

/// Builds the two JavaScript snippets a WebView host needs.
///
/// In a native WebView the View document is the top-level window, so
/// `window.parent === window`. The View SDK posts to `window.parent` and
/// ignores incoming messages whose `event.source` is not `window.parent`.
/// [shim] therefore redirects outgoing messages to a native channel, and
/// [dispatch] delivers incoming ones with `source: window`.
abstract final class BridgeScripts {
  static final RegExp _channelName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Script injected at the start of the document. Messages the View passes to
  /// `window.parent.postMessage` are sent to `window.<channel>.postMessage` as
  /// a JSON string.
  static String shim({String channel = 'mcpBridge'}) {
    if (!_channelName.hasMatch(channel)) {
      throw ArgumentError.value(channel, 'channel',
          'Use a plain JavaScript identifier such as "mcpBridge".');
    }
    return '''
(function () {
  if (window.__mcpAppsHostShim) { return; }
  window.__mcpAppsHostShim = true;
  window.parent.postMessage = function (message, targetOrigin) {
    var text = typeof message === 'string' ? message : JSON.stringify(message);
    window.$channel.postMessage(text);
  };
})();''';
  }

  /// Script that delivers [json] to the View as a `message` event whose
  /// `source` is `window`. [json] is escaped so it can not end the script
  /// (`</script>`, U+2028, U+2029, quotes).
  static String dispatch(String json) {
    // Backslash + "u" + hex digits: a JavaScript unicode escape. Built from
    // char codes so the source file holds no escape sequences to misread.
    String esc(int unit) =>
        '${String.fromCharCode(0x5c)}u${unit.toRadixString(16).padLeft(4, '0')}';
    final literal = jsonEncode(json)
        .replaceAll('<', esc(0x3c))
        .replaceAll(String.fromCharCode(0x2028), esc(0x2028))
        .replaceAll(String.fromCharCode(0x2029), esc(0x2029))
        .replaceAll("'", esc(0x27));
    return "window.dispatchEvent(new MessageEvent('message', "
        '{data: JSON.parse($literal), source: window}));';
  }
}

/// Puts the CSP and the bridge shim into a View document.
abstract final class HtmlInjector {
  static final RegExp _head =
      RegExp(r'<head(?=[\s>/])[^>]*>', caseSensitive: false);
  static final RegExp _html =
      RegExp(r'<html(?=[\s>/])[^>]*>', caseSensitive: false);
  static final RegExp _doctype =
      RegExp(r'^\s*<!doctype[^>]*>', caseSensitive: false);

  /// Returns [html] with a CSP `<meta>` and the [shim] script as the first
  /// children of `<head>`, so they run before any script of the document.
  /// Creates a `<head>` when the document has none.
  static String prepare(String html,
      {required String csp, required String shim}) {
    final safeCsp = csp.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
    final safeShim = shim.replaceAll('</script', r'<\/script');
    final tags =
        '<meta http-equiv="Content-Security-Policy" content="$safeCsp">'
        '<script>$safeShim</script>';

    final head = _head.firstMatch(html);
    if (head != null) return html.replaceRange(head.end, head.end, tags);

    final newHead = '<head>$tags</head>';
    final root = _html.firstMatch(html);
    if (root != null) return html.replaceRange(root.end, root.end, newHead);

    // A <head> before the doctype would switch the page to quirks mode.
    final doctype = _doctype.firstMatch(html);
    if (doctype != null) {
      return html.replaceRange(doctype.end, doctype.end, newHead);
    }
    return '$newHead$html';
  }
}
