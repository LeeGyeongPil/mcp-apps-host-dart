import 'dart:async';

/// A two-way channel of JSON strings between the host and one View.
///
/// A WebView adapter implements this on top of its JavaScript channel.
abstract interface class ViewTransport {
  /// Raw messages coming from the View.
  Stream<String> get incoming;

  /// Sends a raw message to the View.
  void send(String raw);
}

/// An in-memory pair of connected transports, for tests and examples.
class MemoryPipe {
  final _toHost = StreamController<String>();
  final _toView = StreamController<String>();

  late final ViewTransport hostSide = _End(_toHost.stream, _toView.add);
  late final ViewTransport viewSide = _End(_toView.stream, _toHost.add);

  /// Closes both directions.
  Future<void> close() async {
    await _toHost.close();
    await _toView.close();
  }
}

class _End implements ViewTransport {
  _End(this.incoming, this._send);

  @override
  final Stream<String> incoming;
  final void Function(String) _send;

  @override
  void send(String raw) => _send(raw);
}
