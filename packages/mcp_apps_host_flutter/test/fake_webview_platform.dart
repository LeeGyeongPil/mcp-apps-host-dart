import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A WebViewPlatform that records what the app does and renders nothing.
class FakeWebViewPlatform extends WebViewPlatform {
  FakeController? controller;
  FakeNavigationDelegate? navigationDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = FakeController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return navigationDelegate = FakeNavigationDelegate(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return FakeWidget(params);
  }
}

class FakeController extends PlatformWebViewController {
  FakeController(super.params) : super.implementation();

  final loadedHtml = <({String html, String? baseUrl})>[];
  final scripts = <String>[];
  final channels = <String, void Function(JavaScriptMessage)>{};
  JavaScriptMode? mode;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    mode = javaScriptMode;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    channels[javaScriptChannelParams.name] =
        javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    channels.remove(javaScriptChannelName);
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loadedHtml.add((html: html, baseUrl: baseUrl));
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }

  /// Plays the part of the page: sends [text] through the channel.
  void postFromPage(String channel, String text) =>
      channels[channel]!(JavaScriptMessage(message: text));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(
    HttpAuthRequestCallback onHttpAuthRequest,
  ) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
}

class FakeWidget extends PlatformWebViewWidget {
  FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
