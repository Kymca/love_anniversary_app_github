import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class LanPostcardServer {
  LanPostcardServer._(this._server, this._store, this._token);

  static const maxRequestBytes = 8192;
  static const maxMessageLength = 500;
  static const maxNameLength = 40;
  static const maxStoredPostcards = 10000;

  final HttpServer _server;
  final File _store;
  final String _token;
  final _writeLock = _AsyncLock();

  InternetAddress get address => _server.address;
  int get port => _server.port;

  static Future<LanPostcardServer> bind({
    InternetAddress? address,
    required int port,
    required String token,
    required File dataFile,
  }) async {
    if (token.length < 43 || token.length > 128) {
      throw ArgumentError.value(
        token.length,
        'token.length',
        'Use a 256-bit token.',
      );
    }
    if (port < 0 || port > 65535) {
      throw ArgumentError.value(port, 'port');
    }
    await dataFile.parent.create(recursive: true);
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    final instance = LanPostcardServer._(server, dataFile, token);
    unawaited(instance._serve());
    return instance;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        _json(request.response, HttpStatus.ok, {'status': 'ok'});
        return;
      }
      if (!_authorized(request)) {
        _json(request.response, HttpStatus.unauthorized, {
          'error': 'unauthorized',
        });
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/v1/postcards') {
        await _createPostcard(request);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/postcards') {
        await _listReceived(request);
        return;
      }
      final match = RegExp(r'^/v1/postcards/([A-Za-z0-9_-]+)$')
          .firstMatch(request.uri.path);
      if (request.method == 'GET' && match != null) {
        await _loadPostcard(request, match.group(1)!);
        return;
      }
      _json(request.response, HttpStatus.notFound, {'error': 'not_found'});
    } on _RequestException catch (error) {
      _json(request.response, error.status, {'error': error.code});
    } on FormatException {
      _json(request.response, HttpStatus.badRequest, {'error': 'invalid_json'});
    } catch (error, stackTrace) {
      stderr.writeln('Postcard server request failed: $error\n$stackTrace');
      _json(request.response, HttpStatus.internalServerError, {
        'error': 'server_error',
      });
    }
  }

  bool _authorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return false;
    final supplied = utf8.encode(header.substring(7));
    final expected = utf8.encode(_token);
    var difference = supplied.length ^ expected.length;
    final length = max(supplied.length, expected.length);
    for (var index = 0; index < length; index++) {
      difference |=
          (index < supplied.length ? supplied[index] : 0) ^
          (index < expected.length ? expected[index] : 0);
    }
    return difference == 0;
  }

  Future<void> _createPostcard(HttpRequest request) async {
    final data = await _readObject(request);
    const allowedKeys = {
      'senderSide',
      'recipientSide',
      'senderName',
      'recipientName',
      'message',
    };
    if (data.keys.any((key) => !allowedKeys.contains(key))) {
      throw const _RequestException(HttpStatus.badRequest, 'invalid_schema');
    }
    final senderSide = _side(data['senderSide']);
    final recipientSide = _side(data['recipientSide']);
    if (senderSide == recipientSide) {
      throw const _RequestException(HttpStatus.badRequest, 'invalid_recipient');
    }
    final senderName = _string(data['senderName'], maxNameLength);
    final recipientName = _string(data['recipientName'], maxNameLength);
    final message = _string(data['message'], maxMessageLength);
    if (message.trim().isEmpty) {
      throw const _RequestException(HttpStatus.badRequest, 'empty_message');
    }
    final postcard = await _writeLock.run(() async {
      final postcards = await _readStored();
      if (postcards.length >= maxStoredPostcards) {
        throw const _RequestException(507, 'storage_full');
      }
      final created = <String, Object>{
        'id': _newId(),
        'message': message.trim(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'senderSide': senderSide,
        'recipientSide': recipientSide,
        'senderName': senderName,
        'recipientName': recipientName,
      };
      postcards.add(created);
      await _writeStored(postcards);
      return created;
    });
    _json(request.response, HttpStatus.created, postcard);
  }

  Future<void> _listReceived(HttpRequest request) async {
    final side = _side(request.uri.queryParameters['side']);
    final postcards = await _load();
    _json(request.response, HttpStatus.ok, {
      'postcards': postcards
          .where((postcard) => postcard['recipientSide'] == side)
          .toList(),
    });
  }

  Future<void> _loadPostcard(HttpRequest request, String id) async {
    final side = _side(request.uri.queryParameters['side']);
    final postcard = (await _load()).where((item) => item['id'] == id);
    if (postcard.isEmpty || postcard.first['recipientSide'] != side) {
      throw const _RequestException(HttpStatus.notFound, 'postcard_not_found');
    }
    _json(request.response, HttpStatus.ok, postcard.first);
  }

  Future<Map<String, dynamic>> _readObject(HttpRequest request) async {
    if (request.contentLength > maxRequestBytes) {
      throw const _RequestException(
        HttpStatus.requestEntityTooLarge,
        'body_too_large',
      );
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      if (bytes.length + chunk.length > maxRequestBytes) {
        throw const _RequestException(
          HttpStatus.requestEntityTooLarge,
          'body_too_large',
        );
      }
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const _RequestException(HttpStatus.badRequest, 'invalid_schema');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _load() => _writeLock.run(_readStored);

  Future<List<Map<String, dynamic>>> _readStored() async {
    if (!await _store.exists()) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(await _store.readAsString());
    if (decoded is! List || decoded.length > maxStoredPostcards) {
      throw const FormatException('Postcard store is malformed.');
    }
    return decoded.whereType<Map<String, dynamic>>().toList(growable: true);
  }

  Future<void> _writeStored(List<Map<String, dynamic>> postcards) async {
    final temporary = File('${_store.path}.tmp');
    await temporary.writeAsString(jsonEncode(postcards), flush: true);
    if (!await _store.exists()) {
      await temporary.rename(_store.path);
      return;
    }
    if (!Platform.isWindows) {
      await temporary.rename(_store.path);
      return;
    }
    final backup = File('${_store.path}.bak');
    await _store.rename(backup.path);
    try {
      await temporary.rename(_store.path);
      await backup.delete();
    } catch (_) {
      if (!await _store.exists() && await backup.exists()) {
        await backup.rename(_store.path);
      }
      rethrow;
    }
  }

  String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _side(Object? value) {
    if (value == 'first') return 'first';
    if (value == 'second') return 'second';
    throw const _RequestException(HttpStatus.badRequest, 'invalid_side');
  }

  String _string(Object? value, int maxLength) {
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      throw const _RequestException(HttpStatus.badRequest, 'invalid_field');
    }
    return value.trim();
  }

  void _json(HttpResponse response, int status, Object body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(body));
    unawaited(response.close());
  }
}

class _RequestException implements Exception {
  const _RequestException(this.status, this.code);

  final int status;
  final String code;
}

class _AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
