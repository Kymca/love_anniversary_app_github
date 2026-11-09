import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:love_anniversary_app/services/lan_postcard_server.dart';

Future<void> main(List<String> arguments) async {
  final port = _readPort(arguments);
  final configuredToken = Platform.environment['POSTCARD_ACCESS_TOKEN'];
  final token = configuredToken == null || configuredToken.isEmpty
      ? _newToken()
      : configuredToken;
  final server = await LanPostcardServer.bind(
    port: port,
    token: token,
    dataFile: File(
      '${Directory.current.path}${Platform.pathSeparator}postcard_data'
      '${Platform.pathSeparator}postcards.json',
    ),
  );
  stdout
    ..writeln('LAN postcard server listening on 0.0.0.0:${server.port}')
    ..writeln(
      'Data file: ${Directory.current.path}${Platform.pathSeparator}'
      'postcard_data${Platform.pathSeparator}postcards.json',
    )
    ..writeln('Health: http://127.0.0.1:${server.port}/health')
    ..writeln('Access token (enter privately in the app on both phones):')
    ..writeln(token)
    ..writeln(
      'Use a trusted private Wi-Fi only; HTTP traffic is not encrypted.',
    )
    ..writeln('Press Ctrl+C to stop.');
  for (final interface in await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  )) {
    for (final address in interface.addresses) {
      stdout.writeln('Phone URL: http://${address.address}:${server.port}');
    }
  }
  await ProcessSignal.sigint.watch().first;
  await server.close();
}

int _readPort(List<String> arguments) {
  if (arguments.isEmpty) return 8787;
  if (arguments.length != 2 || arguments.first != '--port') {
    throw ArgumentError(
      'Usage: dart run tools/postcard_server.dart [--port N]',
    );
  }
  final port = int.tryParse(arguments.last);
  if (port == null || port < 1 || port > 65535) {
    throw ArgumentError.value(arguments.last, 'port', 'Must be 1..65535.');
  }
  return port;
}

String _newToken() {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
