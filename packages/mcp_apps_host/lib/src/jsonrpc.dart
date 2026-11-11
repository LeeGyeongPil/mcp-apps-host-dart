import 'dart:convert';

/// A JSON-RPC 2.0 message as exchanged with a View over `postMessage`.
sealed class JsonRpcMessage {
  const JsonRpcMessage();

  /// The wire representation as a JSON-compatible map.
  Map<String, Object?> toJson();

  /// The wire representation as a JSON string.
  String encode() => jsonEncode(toJson());

  /// Parses [raw]. Throws [FormatException] when it is not a valid message.
  static JsonRpcMessage decode(String raw) {
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Message is not valid JSON');
    }
    if (value is! Map<String, Object?>) {
      throw const FormatException('Message must be a JSON object');
    }
    return fromJson(value);
  }

  /// Builds a message from a decoded JSON object.
  static JsonRpcMessage fromJson(Map<String, Object?> map) {
    if (map['jsonrpc'] != '2.0') {
      throw const FormatException('"jsonrpc" must be "2.0"');
    }
    final id = map['id'];
    if (id != null && id is! String && id is! int) {
      throw const FormatException('"id" must be a string or an integer');
    }
    final method = map['method'];
    if (method != null) {
      if (method is! String) {
        throw const FormatException('"method" must be a string');
      }
      final params = map['params'];
      if (params != null && params is! Map<String, Object?>) {
        throw const FormatException('"params" must be an object');
      }
      final p = (params as Map<String, Object?>?) ?? const <String, Object?>{};
      return id == null
          ? JsonRpcNotification(method, p)
          : JsonRpcRequest(id, method, p);
    }
    if (map.containsKey('error')) {
      final error = map['error'];
      if (error is! Map<String, Object?> || error['code'] is! int) {
        throw const FormatException(
            '"error" must be an object with an int code');
      }
      return JsonRpcError(
        id,
        error['code'] as int,
        '${error['message'] ?? ''}',
        error['data'],
      );
    }
    if (id == null) {
      throw const FormatException('A response needs an "id"');
    }
    final result = map['result'];
    if (!map.containsKey('result') || result is! Map<String, Object?>) {
      throw const FormatException(
          'A response needs an object "result" or an "error"');
    }
    return JsonRpcResult(id, result);
  }
}

/// A request that expects a response.
final class JsonRpcRequest extends JsonRpcMessage {
  const JsonRpcRequest(this.id, this.method, [this.params = const {}]);

  final Object id;
  final String method;
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() =>
      {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params};
}

/// A one-way message without an id.
final class JsonRpcNotification extends JsonRpcMessage {
  const JsonRpcNotification(this.method, [this.params = const {}]);

  final String method;
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() =>
      {'jsonrpc': '2.0', 'method': method, 'params': params};
}

/// A successful response.
final class JsonRpcResult extends JsonRpcMessage {
  const JsonRpcResult(this.id, this.result);

  final Object id;
  final Map<String, Object?> result;

  @override
  Map<String, Object?> toJson() =>
      {'jsonrpc': '2.0', 'id': id, 'result': result};
}

/// An error response. [id] is `null` when the request id could not be read.
final class JsonRpcError extends JsonRpcMessage {
  const JsonRpcError(this.id, this.code, this.message, [this.data]);

  final Object? id;
  final int code;
  final String message;
  final Object? data;

  @override
  Map<String, Object?> toJson() => {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': code,
          'message': message,
          if (data != null) 'data': data,
        },
      };
}
