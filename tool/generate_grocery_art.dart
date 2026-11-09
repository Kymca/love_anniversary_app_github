import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef Point<T extends num> = math.Point<T>;

const _names = <String>[
  'crumbs',
  'watermelon',
  'worm',
  'pizza',
  'apple',
  'cheese',
  'carrot',
  'milk',
];

const _ink = 0x3B302EFF;
const _cream = 0xFFF0C8FF;
const _paper = 0xFFE6B96FFF;
const _shadow = 0x8B5948FF;
const _red = 0xE94F48FF;
const _redLight = 0xFF7861FF;
const _redDark = 0xAE353EFF;
const _leaf = 0x46875AFF;
const _leafLight = 0x78B769FF;
const _gold = 0xF5C353FF;
const _goldLight = 0xFFE38AFF;
const _blue = 0x78B9C1FF;
const _blueDark = 0x4D8895FF;

void main() {
  final root = Directory.current;
  final productDirectory = Directory(
    '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}images'
    '${Platform.pathSeparator}grocery_products',
  );
  productDirectory.createSync(recursive: true);

  final frames = <PixelCanvas>[
    _drawCrumbs(),
    _drawWatermelon(),
    _drawWorm(),
    _drawPizza(),
    _drawApple(),
    _drawCheese(),
    _drawCarrot(),
    _drawMilk(),
  ];

  final sheet = PixelCanvas(64 * frames.length, 64);
  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    _validateCanvas(frame, _names[i]);
    sheet.blit(frame, i * 64, 0);
    final individualPath = _join(productDirectory.path, '${_names[i]}.png');
    File(individualPath).writeAsBytesSync(encodePng(frame));
    _validatePngFile(individualPath, 64, 64, _names[i]);
  }

  final imagesDirectory = Directory(productDirectory.parent.path);
  final sheetPath = _join(imagesDirectory.path, 'grocery_products_sheet.png');
  File(sheetPath).writeAsBytesSync(encodePng(sheet));
  _validatePngFile(sheetPath, 512, 64, 'product sheet');

  final basket = _drawBasket();
  _validateCanvas(basket, 'red basket');
  final basketPath = _join(imagesDirectory.path, 'grocery_basket_red.png');
  File(basketPath).writeAsBytesSync(encodePng(basket));
  _validatePngFile(basketPath, 96, 72, 'red basket');

  stdout.writeln('Generated ${_names.length} product frames: 512x64 sheet.');
  stdout.writeln('Generated ${_names.length} individual 64x64 product PNGs.');
  stdout.writeln('Generated red basket: 96x72 PNG.');
  stdout.writeln('Basket opaque bounds: ${_opaqueBounds(basket)}.');
  stdout.writeln(
    'Product opaque bounds: ${List.generate(frames.length, (index) => '${_names[index]}=${_opaqueBounds(frames[index])}').join(', ')}.',
  );
  stdout.writeln(
    'All images have transparent pixels and valid PNG dimensions.',
  );
}

String _join(String directory, String file) =>
    '$directory${Platform.pathSeparator}$file';

PixelCanvas _drawCrumbs() {
  final c = PixelCanvas(64, 64);
  c.polygon([
    const Point(15, 16),
    const Point(21, 10),
    const Point(43, 10),
    const Point(49, 16),
  ], _ink);
  c.polygon([
    const Point(18, 17),
    const Point(22, 13),
    const Point(42, 13),
    const Point(46, 17),
  ], _goldLight);
  c.polygon([
    const Point(14, 18),
    const Point(50, 18),
    const Point(47, 51),
    const Point(43, 55),
    const Point(21, 55),
    const Point(17, 51),
  ], _ink);
  c.polygon([
    const Point(18, 21),
    const Point(46, 21),
    const Point(43, 49),
    const Point(40, 52),
    const Point(24, 52),
    const Point(21, 49),
  ], _paper);
  c.rect(21, 24, 22, 4, _goldLight);
  c.rect(19, 30, 26, 13, _cream);
  c.rect(21, 32, 22, 2, _goldLight);
  c.rect(24, 36, 16, 2, _paper);
  c.rect(24, 41, 12, 2, _paper);
  c.rect(23, 45, 18, 3, _gold);
  c.rect(20, 49, 24, 2, _shadow);
  c.rect(27, 27, 3, 3, _gold);
  c.rect(35, 27, 4, 3, _gold);
  return c;
}

PixelCanvas _drawWatermelon() {
  final c = PixelCanvas(64, 64);
  c.polygon([
    const Point(9, 12),
    const Point(54, 37),
    const Point(52, 44),
    const Point(47, 49),
    const Point(40, 53),
    const Point(32, 54),
    const Point(24, 51),
    const Point(18, 46),
    const Point(13, 38),
    const Point(10, 29),
  ], _ink);
  c.polygon([
    const Point(13, 16),
    const Point(50, 38),
    const Point(48, 43),
    const Point(43, 47),
    const Point(37, 50),
    const Point(31, 50),
    const Point(25, 47),
    const Point(20, 43),
    const Point(16, 36),
    const Point(13, 28),
  ], _leaf);
  c.polygon([
    const Point(14, 17),
    const Point(48, 38),
    const Point(45, 42),
    const Point(40, 46),
    const Point(35, 48),
    const Point(29, 47),
    const Point(24, 44),
    const Point(20, 39),
    const Point(16, 32),
    const Point(14, 25),
  ], _cream);
  c.polygon([
    const Point(15, 18),
    const Point(46, 38),
    const Point(43, 41),
    const Point(39, 44),
    const Point(34, 46),
    const Point(29, 45),
    const Point(24, 42),
    const Point(20, 37),
    const Point(17, 31),
    const Point(15, 25),
  ], _red);
  c.rect(19, 23, 4, 3, _redLight);
  for (final p in const [
    Point(25, 27),
    Point(34, 31),
    Point(41, 36),
    Point(26, 36),
    Point(35, 40),
  ]) {
    c.rect(p.x, p.y, 2, 4, _ink);
    c.rect(p.x, p.y + 1, 1, 2, _cream);
  }
  return c;
}

PixelCanvas _drawWorm() {
  final c = PixelCanvas(64, 64);
  c.rect(13, 39, 38, 6, _ink);
  c.rect(16, 33, 8, 12, _ink);
  c.rect(23, 27, 9, 12, _ink);
  c.rect(31, 31, 9, 12, _ink);
  c.rect(39, 36, 11, 9, _ink);
  c.rect(16, 36, 6, 8, _leaf);
  c.rect(23, 30, 7, 8, _leafLight);
  c.rect(31, 34, 7, 8, _leaf);
  c.rect(39, 39, 8, 5, _leafLight);
  c.rect(19, 34, 3, 3, _leafLight);
  c.rect(27, 28, 3, 3, _leaf);
  c.rect(35, 32, 3, 3, _leafLight);
  c.rect(15, 35, 3, 4, _goldLight);
  c.rect(16, 37, 2, 2, _ink);
  c.rect(20, 38, 2, 2, _ink);
  c.rect(29, 34, 2, 2, _cream);
  c.rect(37, 37, 2, 2, _cream);
  c.rect(16, 47, 31, 2, _shadow);
  return c;
}

PixelCanvas _drawPizza() {
  final c = PixelCanvas(64, 64);
  c.polygon([
    const Point(8, 11),
    const Point(56, 11),
    const Point(34, 55),
  ], _ink);
  c.polygon([
    const Point(12, 16),
    const Point(52, 16),
    const Point(34, 49),
  ], _gold);
  c.rect(11, 12, 42, 6, _shadow);
  c.rect(13, 12, 38, 3, _goldLight);
  c.rect(15, 16, 34, 2, _gold);
  c.rect(19, 20, 26, 3, _goldLight);
  c.rect(23, 27, 20, 3, _gold);
  c.rect(25, 35, 13, 3, _goldLight);
  c.rect(30, 43, 7, 3, _gold);
  c.rect(17, 22, 6, 6, _redDark);
  c.rect(18, 21, 4, 4, _red);
  c.rect(30, 24, 6, 6, _redDark);
  c.rect(31, 23, 4, 4, _redLight);
  c.rect(39, 31, 6, 6, _redDark);
  c.rect(40, 30, 4, 4, _red);
  c.rect(23, 33, 5, 5, _redDark);
  c.rect(24, 32, 3, 3, _redLight);
  c.rect(34, 39, 5, 5, _redDark);
  c.rect(35, 38, 3, 3, _red);
  c.rect(15, 18, 5, 3, _cream);
  c.rect(27, 20, 4, 2, _goldLight);
  return c;
}

PixelCanvas _drawApple() {
  final c = PixelCanvas(64, 64);
  c.rect(29, 11, 7, 8, _ink);
  c.rect(31, 12, 3, 6, _shadow);
  c.polygon([
    const Point(33, 15),
    const Point(39, 12),
    const Point(45, 15),
    const Point(41, 19),
    const Point(34, 19),
  ], _ink);
  c.polygon([
    const Point(35, 15),
    const Point(39, 14),
    const Point(42, 16),
    const Point(39, 18),
  ], _leafLight);
  c.polygon([
    const Point(31, 17),
    const Point(38, 19),
    const Point(46, 17),
    const Point(52, 23),
    const Point(53, 35),
    const Point(49, 45),
    const Point(41, 51),
    const Point(32, 53),
    const Point(23, 50),
    const Point(15, 44),
    const Point(11, 34),
    const Point(12, 24),
    const Point(19, 18),
    const Point(25, 17),
  ], _ink);
  c.polygon([
    const Point(32, 21),
    const Point(39, 22),
    const Point(46, 20),
    const Point(49, 25),
    const Point(50, 35),
    const Point(46, 43),
    const Point(40, 48),
    const Point(32, 50),
    const Point(24, 47),
    const Point(18, 42),
    const Point(15, 34),
    const Point(16, 26),
    const Point(21, 21),
    const Point(26, 21),
  ], _red);
  c.rect(19, 27, 5, 14, _redLight);
  c.rect(24, 23, 4, 3, _redLight);
  c.rect(41, 25, 5, 5, _redDark);
  c.rect(46, 30, 3, 7, _redDark);
  c.rect(32, 18, 5, 4, _shadow);
  return c;
}

PixelCanvas _drawCheese() {
  final c = PixelCanvas(64, 64);
  c.polygon([
    const Point(11, 30),
    const Point(35, 13),
    const Point(53, 27),
    const Point(53, 46),
    const Point(17, 50),
    const Point(11, 45),
  ], _ink);
  c.polygon([
    const Point(15, 31),
    const Point(35, 18),
    const Point(49, 29),
    const Point(49, 42),
    const Point(19, 46),
    const Point(15, 43),
  ], _gold);
  c.polygon([
    const Point(15, 31),
    const Point(35, 18),
    const Point(49, 29),
    const Point(33, 34),
  ], _goldLight);
  c.rect(19, 35, 30, 3, _goldLight);
  c.rect(23, 40, 25, 3, _gold);
  c.rect(20, 34, 5, 4, _shadow);
  c.rect(36, 28, 5, 4, _shadow);
  c.rect(40, 37, 6, 5, _shadow);
  c.rect(29, 41, 4, 3, _shadow);
  c.rect(18, 30, 3, 3, _cream);
  return c;
}

PixelCanvas _drawCarrot() {
  final c = PixelCanvas(64, 64);
  c.rect(27, 11, 7, 9, _ink);
  c.rect(20, 14, 9, 7, _ink);
  c.rect(33, 14, 10, 7, _ink);
  c.rect(16, 20, 14, 6, _ink);
  c.rect(32, 20, 17, 6, _ink);
  c.rect(22, 16, 8, 4, _leafLight);
  c.rect(34, 16, 6, 4, _leaf);
  c.rect(19, 22, 10, 3, _leaf);
  c.rect(34, 22, 13, 3, _leafLight);
  c.polygon([
    const Point(17, 27),
    const Point(47, 27),
    const Point(44, 37),
    const Point(39, 47),
    const Point(33, 55),
    const Point(29, 55),
    const Point(24, 47),
    const Point(20, 38),
  ], _ink);
  c.polygon([
    const Point(21, 30),
    const Point(43, 30),
    const Point(40, 38),
    const Point(36, 46),
    const Point(32, 51),
    const Point(30, 51),
    const Point(26, 45),
    const Point(23, 37),
  ], 0xFFF08337);
  c.rect(23, 32, 8, 3, 0xFFFFA74D);
  c.rect(34, 36, 7, 3, 0xFFE16D2D);
  c.rect(28, 41, 8, 3, 0xFFFFA74D);
  c.rect(31, 48, 3, 3, 0xFFE16D2D);
  return c;
}

PixelCanvas _drawMilk() {
  final c = PixelCanvas(64, 64);
  c.rect(27, 10, 11, 5, _ink);
  c.rect(29, 7, 7, 5, _ink);
  c.rect(30, 8, 5, 4, _blue);
  c.polygon([
    const Point(20, 16),
    const Point(26, 11),
    const Point(39, 11),
    const Point(45, 16),
    const Point(47, 52),
    const Point(43, 56),
    const Point(21, 56),
    const Point(17, 52),
  ], _ink);
  c.polygon([
    const Point(23, 18),
    const Point(27, 15),
    const Point(38, 15),
    const Point(42, 18),
    const Point(44, 50),
    const Point(41, 53),
    const Point(23, 53),
    const Point(20, 50),
  ], _cream);
  c.polygon([
    const Point(23, 18),
    const Point(27, 15),
    const Point(38, 15),
    const Point(35, 23),
    const Point(24, 25),
  ], _blue);
  c.rect(37, 20, 4, 30, _blueDark);
  c.rect(24, 29, 15, 14, _blue);
  c.rect(27, 32, 9, 8, _cream);
  c.rect(29, 34, 5, 4, _blueDark);
  c.rect(24, 45, 12, 2, _blueDark);
  c.rect(25, 20, 5, 2, 0xFFDBF5F0);
  return c;
}

PixelCanvas _drawBasket() {
  final c = PixelCanvas(96, 72);
  // Thick, hollow handle stays open so groceries can be layered into the basket.
  c.line(24, 29, 28, 12, 7, _ink);
  c.line(28, 12, 36, 6, 7, _ink);
  c.line(36, 6, 60, 6, 7, _ink);
  c.line(60, 6, 68, 12, 7, _ink);
  c.line(68, 12, 72, 29, 7, _ink);
  c.line(24, 29, 28, 12, 3, _red);
  c.line(28, 12, 36, 6, 3, _redLight);
  c.line(36, 6, 60, 6, 3, _redLight);
  c.line(60, 6, 68, 12, 3, _red);
  c.line(68, 12, 72, 29, 3, _redDark);

  c.polygon(const [
    Point(11, 26),
    Point(85, 26),
    Point(78, 64),
    Point(72, 69),
    Point(24, 69),
    Point(18, 64),
  ], _ink);
  c.polygon(const [
    Point(16, 32),
    Point(80, 32),
    Point(74, 61),
    Point(70, 64),
    Point(26, 64),
    Point(22, 61),
  ], _redDark);
  c.rect(15, 25, 66, 9, _ink);
  c.rect(18, 26, 60, 5, _redLight);
  c.rect(20, 31, 56, 3, _red);
  c.rect(22, 36, 52, 3, _redLight);
  c.rect(23, 43, 50, 3, _red);
  c.rect(24, 51, 48, 3, _redLight);
  c.rect(25, 60, 46, 4, _red);

  // Dark slots make the slatted basket read clearly while leaving its center quiet.
  for (final x in const [27, 38, 49, 60, 70]) {
    c.rect(x, 35, 4, 4, _redDark);
    c.rect(x, 46, 4, 4, _redDark);
    c.rect(x + 1, 56, 3, 3, _redDark);
  }
  c.rect(20, 35, 3, 19, _redDark);
  c.rect(73, 35, 3, 19, _redDark);
  c.rect(22, 35, 2, 4, _redLight);
  c.rect(72, 35, 2, 4, _redLight);
  return c;
}

void _validateCanvas(PixelCanvas canvas, String label) {
  var transparent = 0;
  var opaque = 0;
  for (var i = 3; i < canvas.pixels.length; i += 4) {
    if (canvas.pixels[i] == 0) {
      transparent++;
    } else if (canvas.pixels[i] == 255) {
      opaque++;
    }
  }
  if (transparent == 0 || opaque == 0) {
    throw StateError('$label must contain both transparent and opaque pixels.');
  }
}

String _opaqueBounds(PixelCanvas canvas) {
  var left = canvas.width;
  var top = canvas.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < canvas.height; y++) {
    for (var x = 0; x < canvas.width; x++) {
      if (canvas.pixels[(y * canvas.width + x) * 4 + 3] == 0) continue;
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x);
      bottom = math.max(bottom, y);
    }
  }
  return 'x=$left..$right, y=$top..$bottom';
}

void _validatePngFile(String path, int width, int height, String label) {
  final bytes = File(path).readAsBytesSync();
  final header = ByteData.sublistView(bytes);
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) throw StateError('$label is not a PNG.');
  }
  final actualWidth = header.getUint32(16, Endian.big);
  final actualHeight = header.getUint32(20, Endian.big);
  if (actualWidth != width || actualHeight != height) {
    throw StateError(
      '$label has dimensions ${actualWidth}x$actualHeight; '
      'expected ${width}x$height.',
    );
  }
  if (bytes[25] != 6) {
    throw StateError('$label must have an RGBA alpha channel.');
  }
}

class PixelCanvas {
  PixelCanvas(this.width, this.height) : pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;

  void blit(PixelCanvas source, int x, int y) {
    for (var row = 0; row < source.height; row++) {
      final start = row * source.width * 4;
      pixels.setRange(
        ((y + row) * width + x) * 4,
        ((y + row) * width + x + source.width) * 4,
        source.pixels,
        start,
      );
    }
  }

  void rect(int x, int y, int w, int h, int color) {
    for (var py = y; py < y + h; py++) {
      for (var px = x; px < x + w; px++) {
        pixel(px, py, color);
      }
    }
  }

  void pixel(int x, int y, int color) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final offset = (y * width + x) * 4;
    pixels[offset] = (color >> 24) & 0xFF;
    pixels[offset + 1] = (color >> 16) & 0xFF;
    pixels[offset + 2] = (color >> 8) & 0xFF;
    pixels[offset + 3] = color & 0xFF;
  }

  void line(int x0, int y0, int x1, int y1, int thickness, int color) {
    var dx = (x1 - x0).abs();
    final sx = x0 < x1 ? 1 : -1;
    var dy = -(y1 - y0).abs();
    final sy = y0 < y1 ? 1 : -1;
    var error = dx + dy;
    while (true) {
      rect(
        x0 - thickness ~/ 2,
        y0 - thickness ~/ 2,
        thickness,
        thickness,
        color,
      );
      if (x0 == x1 && y0 == y1) break;
      final twiceError = error * 2;
      if (twiceError >= dy) {
        error += dy;
        x0 += sx;
      }
      if (twiceError <= dx) {
        error += dx;
        y0 += sy;
      }
    }
  }

  void polygon(List<Point<int>> points, int color) {
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);
    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        var inside = false;
        for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
          final a = points[i];
          final b = points[j];
          final crosses =
              (a.y > y) != (b.y > y) &&
              x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x;
          if (crosses) inside = !inside;
        }
        if (inside) pixel(x, y, color);
      }
    }
  }
}

Uint8List encodePng(PixelCanvas canvas) {
  final raw = Uint8List((canvas.width * 4 + 1) * canvas.height);
  for (var y = 0; y < canvas.height; y++) {
    final rowStart = y * (canvas.width * 4 + 1);
    raw[rowStart] = 0;
    final sourceStart = y * canvas.width * 4;
    raw.setRange(
      rowStart + 1,
      rowStart + 1 + canvas.width * 4,
      canvas.pixels,
      sourceStart,
    );
  }

  final header = BytesBuilder()
    ..add(_uint32(canvas.width))
    ..add(_uint32(canvas.height))
    ..add(const [8, 6, 0, 0, 0]);
  final output = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_pngChunk('IHDR', header.takeBytes()))
    ..add(
      _pngChunk('IDAT', Uint8List.fromList(ZLibEncoder(level: 9).convert(raw))),
    )
    ..add(_pngChunk('IEND', Uint8List(0)));
  return output.takeBytes();
}

Uint8List _uint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.big);
  return bytes.buffer.asUint8List();
}

Uint8List _pngChunk(String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final crcInput = Uint8List.fromList([...typeBytes, ...data]);
  final chunk = BytesBuilder()
    ..add(_uint32(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_uint32(_crc32(crcInput)));
  return chunk.takeBytes();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
