import 'dart:io';
import 'dart:typed_data';

const int _gridSize = 32;
const int _pixelSize = 32;
const int _imageSize = _gridSize * _pixelSize;

const int _outline = 0xff51443d;
const int _heart = 0xfff45c73;
const int _heartShadow = 0xffd84961;
const int _heartLight = 0xffff8c9a;
const int _heartShine = 0xffffc5c6;
const int _background = 0xfffff0e0;

const Map<int, List<(int, int)>> _heartRows = {
  5: [(11, 14), (17, 20)],
  6: [(9, 15), (16, 22)],
  7: [(8, 23)],
  8: [(7, 24)],
  9: [(7, 24)],
  10: [(7, 24)],
  11: [(7, 24)],
  12: [(7, 24)],
  13: [(8, 23)],
  14: [(9, 22)],
  15: [(10, 21)],
  16: [(11, 20)],
  17: [(12, 19)],
  18: [(13, 18)],
  19: [(14, 17)],
  20: [(15, 16)],
  21: [(15, 16)],
};

class _Raster {
  _Raster()
    : pixels = List<int>.filled(_imageSize * _imageSize, 0, growable: false);

  final List<int> pixels;

  void fill(int color) {
    pixels.fillRange(0, pixels.length, color);
  }

  void fillCell(int x, int y, int color) {
    final left = x * _pixelSize;
    final top = y * _pixelSize;
    for (var dy = 0; dy < _pixelSize; dy++) {
      final rowOffset = (top + dy) * _imageSize + left;
      pixels.fillRange(rowOffset, rowOffset + _pixelSize, color);
    }
  }
}

bool _isHeartCell(int x, int y) =>
    _heartRows[y]?.any((range) => x >= range.$1 && x <= range.$2) ?? false;

int _cellColor(int x, int y) {
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      if (!_isHeartCell(x + dx, y + dy)) return _outline;
    }
  }

  if ((x == 10 || x == 11) && y == 8 || x == 10 && y == 9) {
    return _heartShine;
  }
  if (y <= 9 && x <= 15) return _heartLight;
  if (y >= 15 || x >= 18) return _heartShadow;
  return _heart;
}

_Raster _drawHeart({required bool withBackground}) {
  final image = _Raster();
  if (withBackground) image.fill(_background);
  for (var y = 0; y < _gridSize; y++) {
    for (var x = 0; x < _gridSize; x++) {
      if (_isHeartCell(x, y) ||
          _isHeartCell(x - 1, y) ||
          _isHeartCell(x + 1, y) ||
          _isHeartCell(x, y - 1) ||
          _isHeartCell(x, y + 1) ||
          _isHeartCell(x - 1, y - 1) ||
          _isHeartCell(x + 1, y - 1) ||
          _isHeartCell(x - 1, y + 1) ||
          _isHeartCell(x + 1, y + 1)) {
        image.fillCell(x, y, _cellColor(x, y));
      }
    }
  }
  return image;
}

Uint8List _encodePng(_Raster image) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < _imageSize; y++) {
    raw.addByte(0);
    for (var x = 0; x < _imageSize; x++) {
      final pixel = image.pixels[y * _imageSize + x];
      raw
        ..addByte((pixel >> 16) & 0xff)
        ..addByte((pixel >> 8) & 0xff)
        ..addByte(pixel & 0xff)
        ..addByte((pixel >> 24) & 0xff);
    }
  }

  final header = BytesBuilder(copy: false)
    ..add(_uint32(_imageSize))
    ..add(_uint32(_imageSize))
    ..add([8, 6, 0, 0, 0]);
  return Uint8List.fromList([
    ...[137, 80, 78, 71, 13, 10, 26, 10],
    ..._chunk('IHDR', header.takeBytes()),
    ..._chunk('IDAT', Uint8List.fromList(zlib.encode(raw.takeBytes()))),
    ..._chunk('IEND', Uint8List(0)),
  ]);
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final crcInput = [...typeBytes, ...data];
  return [
    ..._uint32(data.length),
    ...typeBytes,
    ...data,
    ..._uint32(_crc32(crcInput)),
  ];
}

List<int> _uint32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

Future<void> main() async {
  final directory = Directory('assets/icons');
  await directory.create(recursive: true);
  await File('${directory.path}/app_icon.png')
      .writeAsBytes(_encodePng(_drawHeart(withBackground: true)));
  await File('${directory.path}/app_icon_foreground.png')
      .writeAsBytes(_encodePng(_drawHeart(withBackground: false)));
}
