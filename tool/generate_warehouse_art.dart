import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef Point = math.Point<int>;

const _ink = 0x352E32FF;
const _wall = 0xD6B77FFF;
const _wallLight = 0xF0D8A5FF;
const _wallShade = 0xA9825EFF;
const _steel = 0x536F73FF;
const _steelLight = 0x91A7A0FF;
const _steelDark = 0x374C52FF;
const _wood = 0xA96E49FF;
const _woodLight = 0xD19A5FFF;
const _woodShade = 0x79503FFF;
const _box = 0xB87843FF;
const _boxLight = 0xD99B5AFF;
const _boxDark = 0x80503AFF;
const _cream = 0xFFF0C8FF;
const _orange = 0xF08C32FF;

void main() {
  final directory = Directory(
    _joinAll(Directory.current.path, ['assets', 'images', 'warehouse']),
  )..createSync(recursive: true);

  final background = _drawBackground();
  final jack = _drawPalletJack();
  final platform = _drawCatchPlatform();
  final boxes = <PixelCanvas>[
    _drawBox(0),
    _drawBox(1),
    _drawBox(2),
    _drawBox(3),
  ];
  final sheet = PixelCanvas(128, 32);
  for (var i = 0; i < boxes.length; i++) {
    sheet.blit(boxes[i], i * 32, 0);
    _write(directory, 'warehouse_box_${i + 1}.png', boxes[i], 32, 32, true);
  }

  _write(directory, 'warehouse_background.png', background, 320, 240, false);
  _write(directory, 'warehouse_pallet_jack.png', jack, 96, 64, true);
  _write(directory, 'warehouse_catch_platform.png', platform, 160, 32, true);
  _write(directory, 'warehouse_box_variants.png', sheet, 128, 32, true);

  stdout.writeln('Generated warehouse pixel art in ${directory.path}.');
  stdout.writeln('warehouse_background.png: 320x240 RGBA, opaque scene.');
  stdout.writeln(
    'warehouse_pallet_jack.png: 96x64 RGBA, bounds ${jack.opaqueBounds}.',
  );
  stdout.writeln(
    'warehouse_catch_platform.png: 160x32 RGBA, bounds ${platform.opaqueBounds}.',
  );
  stdout.writeln(
    'warehouse_box_variants.png: 128x32 RGBA, 4 frames at 32x32; '
    'individual box PNGs also emitted.',
  );
}

String _joinAll(String root, List<String> parts) =>
    [root, ...parts].join(Platform.pathSeparator);

void _write(
  Directory directory,
  String name,
  PixelCanvas canvas,
  int width,
  int height,
  bool transparent,
) {
  _validateCanvas(canvas, name, transparent);
  final path = _joinAll(directory.path, [name]);
  File(path).writeAsBytesSync(encodePng(canvas));
  _validatePng(path, width, height, name, transparent);
}

PixelCanvas _drawBackground() {
  final c = PixelCanvas(320, 240);
  c.rect(0, 0, 320, 240, _wallShade);

  // High ceiling beams and a bright rear wall establish the vanishing point.
  c.polygon(const [
    Point(0, 0),
    Point(320, 0),
    Point(320, 111),
    Point(0, 111),
  ], _wall);
  c.polygon(const [
    Point(0, 0),
    Point(320, 0),
    Point(254, 43),
    Point(66, 43),
  ], 0x6E5548FF);
  for (var x = 0; x < 320; x += 40) {
    c.polygon([
      Point(x, 0),
      Point(x + 5, 0),
      Point(x + 32, 42),
      Point(x + 27, 42),
    ], 0x8B6C51FF);
    c.rect(x + 8, 10, 22, 3, 0xA58968FF);
    c.rect(x + 10, 13, 18, 2, 0x594A43FF);
  }
  // Recessed strip lights cast pale pools on the upper wall.
  for (final x in const [48, 132, 216]) {
    c.rect(x, 27, 38, 4, _ink);
    c.rect(x + 3, 28, 32, 2, 0xF5DEA9FF);
    c.rect(x + 6, 30, 26, 1, 0xD5BD8FFF);
  }
  c.line(0, 42, 320, 42, 4, _ink);
  c.line(0, 46, 320, 46, 2, _wallLight);

  // Distant loading bay and its light spill.
  c.rect(111, 48, 98, 97, _ink);
  c.rect(117, 54, 86, 91, 0x73684FFF);
  c.rect(125, 59, 70, 77, 0xA4A17BFF);
  c.rect(130, 65, 60, 67, 0xD4C18AFF);
  c.rect(145, 71, 30, 60, 0xE8D59DFF);
  c.rect(149, 76, 22, 53, 0xF5E3B0FF);
  c.rect(116, 139, 88, 5, _steelDark);
  c.rect(120, 144, 80, 3, _steelLight);
  c.rect(154, 76, 4, 53, 0xFFF0C8FF);
  c.rect(162, 76, 3, 53, 0xFFF0C8FF);
  c.rect(123, 51, 74, 3, _steelLight);
  c.rect(119, 53, 4, 12, _steelDark);
  c.rect(197, 53, 4, 12, _steelDark);
  // Loading-bay bumper blocks and warning stripes.
  for (var x = 123; x < 198; x += 10) {
    c.rect(x, 134, 5, 3, x % 20 == 3 ? _orange : _cream);
  }

  // Wall panels gradually widen toward the foreground.
  for (final y in const [60, 84, 108]) {
    final spread = (y - 42) * 2;
    c.line(160 - spread, y, 160 - spread - 18, y + 20, 2, _wallShade);
    c.line(160 + spread, y, 160 + spread + 18, y + 20, 2, _wallShade);
  }
  c.rect(17, 58, 38, 21, 0xB99363FF);
  c.rect(20, 61, 32, 15, 0xE8D3A4FF);
  c.rect(263, 58, 38, 21, 0xB99363FF);
  c.rect(266, 61, 32, 15, 0xE8D3A4FF);
  c.rect(27, 66, 18, 3, 0x8B7657FF);
  c.rect(276, 66, 18, 3, 0x8B7657FF);
  // Wall-mounted conduit, junction boxes and a small no-text work lamp.
  c.line(16, 86, 87, 86, 2, 0xA78963FF);
  c.line(233, 86, 304, 86, 2, 0xA78963FF);
  for (final x in const [80, 238]) {
    c.rect(x, 80, 10, 12, _ink);
    c.rect(x + 2, 82, 6, 8, _steel);
    c.rect(x + 3, 83, 4, 2, 0xE7C467FF);
    c.rect(x + 3, 86, 4, 3, _steelLight);
  }
  c.rect(62, 94, 24, 3, 0x604A40FF);
  c.rect(65, 97, 18, 2, 0xA5C1A1FF);
  c.rect(234, 94, 24, 3, 0x604A40FF);
  c.rect(237, 97, 18, 2, 0xA5C1A1FF);

  // Rack uprights converge toward the loading bay; the foreground racks are darker.
  _drawRack(c, true);
  _drawRack(c, false);

  // A perspective floor leads from the open aisle into the bright loading bay.
  c.polygon(const [
    Point(0, 127),
    Point(320, 127),
    Point(320, 240),
    Point(0, 240),
  ], 0xB4865FFF);
  c.polygon(const [
    Point(145, 127),
    Point(175, 127),
    Point(320, 240),
    Point(0, 240),
  ], 0xC99A68FF);
  c.line(0, 128, 320, 128, 4, _steelDark);
  c.line(0, 133, 320, 133, 2, _woodLight);
  for (var y = 148; y < 240; y += 19) {
    final dy = y - 126;
    final half = 4 + dy * 2;
    c.line(160 - half, y, 160 + half, y, 2, 0x9E714FFF);
    c.line(160 - half - 2, y + 2, 160 + half + 2, y + 2, 1, 0xD3A16AFF);
  }
  for (final x in const [48, 94, 226, 272]) {
    c.line(160, 134, x, 239, 2, 0xA77B56FF);
  }
  // Floor safety lanes and small reflective studs fade into the distance.
  c.line(108, 143, 13, 239, 2, 0xE8BD70FF);
  c.line(212, 143, 307, 239, 2, 0xE8BD70FF);
  for (final y in const [157, 181, 207, 234]) {
    final spread = y - 126;
    for (final side in const [-1, 1]) {
      final x = 160 + side * (18 + spread);
      c.rect(x - 1, y, 3, 2, 0xEBD4A1FF);
    }
  }
  // Floor drain, a scuffed patch, and a dropped packing slip add scale cues.
  c.rect(146, 189, 28, 3, 0x815E48FF);
  c.rect(149, 191, 22, 2, 0x60483DFF);
  for (var x = 150; x < 171; x += 5) {
    c.rect(x, 190, 2, 1, 0xB28A60FF);
  }
  c.polygon(const [
    Point(82, 180),
    Point(88, 178),
    Point(92, 181),
    Point(90, 187),
    Point(84, 186),
  ], 0xE9DAB7FF);
  c.rect(85, 181, 4, 1, 0xA9916DFF);

  // Foreground pallets and stored cartons frame, rather than block, the play lane.
  _drawPallet(c, 4, 204, 68, 16, false);
  _drawStack(c, 11, 171, 49, 34, 2);
  _drawPallet(c, 248, 201, 68, 18, true);
  _drawStack(c, 261, 165, 42, 37, 1);
  c.rect(0, 231, 320, 9, 0x624A40FF);
  c.line(0, 231, 320, 231, 2, 0xD29A5FFF);
  // Foreground steel guard rails give the open aisle a clear boundary.
  c.rect(0, 146, 5, 78, _ink);
  c.rect(2, 148, 2, 73, 0xD6B654FF);
  c.rect(315, 146, 5, 78, _ink);
  c.rect(316, 148, 2, 73, 0xD6B654FF);
  for (final y in const [158, 182, 207]) {
    c.rect(0, y, 6, 2, 0xFFF0C8FF);
    c.rect(314, y, 6, 2, 0xFFF0C8FF);
  }
  return c;
}

void _drawRack(PixelCanvas c, bool left) {
  int px(int local) => left ? local : 320 - local;
  for (var row = 0; row < 3; row++) {
    final y = 58 + row * 28;
    final xNear = 0;
    final xFar = left ? 102 - row * 4 : 218 + row * 4;
    final shade = row == 0 ? 0x688080FF : _steel;
    c.polygon([
      Point(px(xNear), y),
      Point(px(xFar), y - 8),
      Point(px(xFar), y - 3),
      Point(px(xNear), y + 5),
    ], _steelDark);
    c.polygon([
      Point(px(xNear), y - 4),
      Point(px(xFar), y - 12),
      Point(px(xFar), y - 8),
      Point(px(xNear), y),
    ], shade);
    c.line(px(xNear), y + 7, px(xFar), y - 1, 3, _ink);
    final shelfStart = left ? 8 : xFar + 8;
    var packageIndex = 0;
    final shelfEnd = left ? xFar : 320;
    for (var bx = shelfStart; bx < shelfEnd - 18; bx += 23) {
      final h = row == 0 ? 12 : 16;
      final packageWidth = packageIndex.isEven ? 18 : 14;
      final by = y - h - 2 - (packageIndex % 3 == 2 ? 2 : 0);
      final boxX = bx;
      final colors = switch (packageIndex % 4) {
        0 => (_boxDark, _box, _boxLight),
        1 => (0x846045FF, 0xC27E4CFF, 0xE6B86FFF),
        2 => (0x765844FF, 0xA8794DFF, 0xD3AA70FF),
        _ => (0x73534AFF, 0xB47D59FF, 0xE0B989FF),
      };
      c.rect(boxX, by, packageWidth, h, _ink);
      c.rect(boxX + 2, by + 2, packageWidth - 4, h - 4, colors.$2);
      c.rect(boxX + 2, by + 2, packageWidth ~/ 3, 3, colors.$3);
      c.rect(boxX + packageWidth ~/ 2, by + 2, 2, h - 4, colors.$1);
      c.rect(boxX + 4, by + h ~/ 2, packageWidth - 8, 3, 0xEBD7A8FF);
      c.rect(boxX + 5, by + h ~/ 2 + 1, 3, 1, colors.$2);
      if (packageIndex.isEven) {
        c.rect(boxX + 3, by + h - 5, 2, 2, 0x4F5550FF);
      }
      packageIndex++;
    }
  }
  final uprightX = left ? 13 : 302;
  c.rect(uprightX, 58, 7, 86, _steelDark);
  c.rect(uprightX + (left ? 2 : -2), 60, 2, 82, _steelLight);
  c.rect(uprightX, 58, 12, 4, _steel);
  c.rect(uprightX - 2, 86, 12, 4, _steel);
  c.rect(uprightX - 3, 114, 13, 4, _steel);
  c.rect(uprightX - 4, 142, 14, 4, _steel);
  // Bolt plates and alternating safety paint mark each rack bay.
  for (final y in const [68, 95, 122]) {
    c.rect(uprightX - 1, y, 9, 5, _steel);
    c.rect(uprightX + 1, y + 1, 2, 1, _cream);
    c.rect(uprightX + 5, y + 1, 2, 1, _cream);
    c.rect(uprightX, y + 5, 7, 2, _orange);
  }
}

void _drawPallet(
  PixelCanvas c,
  int x,
  int y,
  int width,
  int height,
  bool flipped,
) {
  final face = flipped ? 0x81573FFF : _woodShade;
  c.polygon([
    Point(x, y + 4),
    Point(x + width, y),
    Point(x + width, y + height - 4),
    Point(x + 5, y + height),
    Point(x, y + height - 3),
  ], _ink);
  c.polygon([
    Point(x + 3, y + 4),
    Point(x + width - 2, y + 2),
    Point(x + width - 4, y + height - 6),
    Point(x + 7, y + height - 3),
  ], face);
  for (var bx = x + 7; bx < x + width - 8; bx += 17) {
    c.rect(bx, y + 5, 3, height - 10, _woodLight);
  }
}

void _drawStack(PixelCanvas c, int x, int y, int width, int height, int count) {
  final unit = width ~/ count;
  for (var i = 0; i < count; i++) {
    final bx = x + i * unit;
    final bw = unit - 2;
    final bh = height - (i.isEven ? 4 : 0);
    final by = y + (i.isEven ? 4 : 0);
    c.rect(bx, by, bw, bh, _ink);
    c.rect(bx + 2, by + 2, bw - 5, bh - 4, i.isEven ? _box : _boxDark);
    c.rect(bx + 3, by + 3, bw - 8, 4, _boxLight);
    c.rect(bx + bw ~/ 2 - 1, by + 8, 3, bh - 13, _boxDark);
    c.rect(bx + bw ~/ 2 - 3, by + 8, 7, 2, _woodLight);
    c.rect(bx + 4, by + bh - 8, bw ~/ 3, 3, 0xF0D8A5FF);
    c.rect(bx + 5, by + bh - 7, 2, 1, 0x8E6448FF);
  }
}

PixelCanvas _drawPalletJack() {
  final c = PixelCanvas(96, 64);
  // Wheels and hydraulic base.
  c.rect(19, 51, 10, 7, _ink);
  c.rect(20, 52, 7, 4, _steelLight);
  c.rect(68, 51, 10, 7, _ink);
  c.rect(69, 52, 7, 4, _steelLight);
  c.rect(27, 44, 43, 9, _ink);
  c.rect(32, 45, 32, 5, 0xC84F3FFF);
  c.rect(40, 42, 18, 7, 0xE36A45FF);
  c.rect(43, 40, 10, 5, _woodLight);
  c.rect(46, 37, 4, 5, _ink);

  // Upright handle and control grip.
  c.line(70, 48, 79, 19, 5, _ink);
  c.line(71, 47, 79, 20, 2, _steelLight);
  c.rect(74, 15, 14, 5, _ink);
  c.rect(77, 12, 8, 5, _ink);
  c.rect(78, 13, 6, 2, _orange);
  c.rect(80, 20, 4, 10, _steelDark);

  // Friendly driver: hard hat, white duck silhouette, beak, eyes and blush.
  c.rect(37, 8, 19, 3, _ink);
  c.rect(40, 5, 14, 5, _ink);
  c.rect(42, 6, 10, 3, 0xF2B84EFF);
  c.rect(39, 10, 16, 3, 0xE99B3DFF);
  c.polygon(const [
    Point(38, 13),
    Point(42, 10),
    Point(51, 10),
    Point(56, 14),
    Point(58, 21),
    Point(55, 27),
    Point(60, 34),
    Point(58, 39),
    Point(35, 39),
    Point(32, 34),
    Point(35, 27),
    Point(32, 21),
    Point(34, 15),
  ], _ink);
  c.polygon(const [
    Point(39, 14),
    Point(43, 12),
    Point(50, 12),
    Point(54, 15),
    Point(56, 21),
    Point(53, 26),
    Point(57, 33),
    Point(55, 36),
    Point(38, 36),
    Point(35, 33),
    Point(38, 26),
    Point(35, 21),
    Point(36, 16),
  ], _cream);
  c.rect(38, 19, 3, 3, _ink);
  c.rect(49, 19, 3, 3, _ink);
  c.rect(36, 23, 3, 3, 0xF59AA2FF);
  c.rect(51, 23, 3, 3, 0xF59AA2FF);
  c.rect(42, 23, 8, 5, _ink);
  c.rect(40, 24, 12, 3, _orange);
  c.rect(43, 28, 6, 2, 0xC86A2DFF);
  c.rect(37, 35, 7, 5, _cream);
  c.rect(49, 35, 7, 5, _cream);
  c.rect(38, 39, 7, 4, _orange);
  c.rect(49, 39, 7, 4, _orange);

  // Small steering-arm footplate and highlight.
  c.rect(26, 51, 47, 3, _steelDark);
  c.rect(28, 51, 42, 1, _steelLight);
  return c;
}

PixelCanvas _drawCatchPlatform() {
  final c = PixelCanvas(160, 32);
  c.polygon(const [
    Point(8, 5),
    Point(151, 5),
    Point(157, 26),
    Point(2, 26),
  ], _ink);
  c.polygon(const [
    Point(12, 7),
    Point(147, 7),
    Point(151, 21),
    Point(8, 21),
  ], _wood);
  c.polygon(const [
    Point(14, 8),
    Point(145, 8),
    Point(147, 13),
    Point(12, 13),
  ], _woodLight);
  c.line(8, 23, 151, 23, 3, _woodShade);
  c.rect(18, 25, 16, 3, _steelDark);
  c.rect(73, 25, 15, 3, _steelDark);
  c.rect(129, 25, 16, 3, _steelDark);
  c.rect(21, 26, 10, 2, _steelLight);
  c.rect(76, 26, 9, 2, _steelLight);
  c.rect(132, 26, 10, 2, _steelLight);
  c.rect(4, 29, 152, 2, _ink);
  return c;
}

PixelCanvas _drawBox(int variant) {
  final c = PixelCanvas(32, 32);
  final colors = <List<int>>[
    [0xB87843FF, 0xD99B5AFF, 0x80503AFF],
    [0x9E6546FF, 0xC98A55FF, 0x70483AFF],
    [0xC18A4DFF, 0xE0B66AFF, 0x87613FFF],
    [0xA96E49FF, 0xD19A5FFF, 0x79503FFF],
  ][variant];
  final top = 5 + variant % 2;
  c.polygon([
    Point(5, top + 5),
    Point(16, top),
    Point(27, top + 5),
    Point(27, top + 21),
    Point(16, top + 27),
    Point(5, top + 21),
  ], _ink);
  c.polygon([
    Point(7, top + 6),
    Point(16, top + 2),
    Point(25, top + 6),
    Point(25, top + 19),
    Point(16, top + 24),
    Point(7, top + 19),
  ], colors[0]);
  c.polygon([
    Point(7, top + 6),
    Point(16, top + 2),
    Point(16, top + 12),
    Point(7, top + 17),
  ], colors[1]);
  c.polygon([
    Point(16, top + 12),
    Point(25, top + 6),
    Point(25, top + 19),
    Point(16, top + 24),
  ], colors[2]);
  c.line(7, top + 6, 16, top + 12, 2, colors[2]);
  c.rect(14 + variant % 3, top + 10, 3, 2, 0xE8C17CFF);
  c.rect(15, top + 13, 2, 4, colors[1]);
  if (variant == 1) {
    c.rect(20, top + 14, 3, 2, 0x6E5040FF);
    c.rect(20, top + 16, 2, 2, 0x6E5040FF);
  } else if (variant == 2) {
    c.rect(8, top + 18, 3, 2, 0xE4C07DFF);
  } else if (variant == 3) {
    c.rect(20, top + 9, 3, 2, 0xF0D38DFF);
  }
  return c;
}

void _validateCanvas(PixelCanvas canvas, String label, bool transparent) {
  var clear = 0;
  var solid = 0;
  for (var i = 3; i < canvas.pixels.length; i += 4) {
    if (canvas.pixels[i] == 0) {
      clear++;
    } else if (canvas.pixels[i] == 255) {
      solid++;
    }
  }
  if (solid == 0 ||
      (transparent && clear == 0) ||
      (!transparent && clear != 0)) {
    throw StateError('$label has unexpected alpha coverage.');
  }
}

void _validatePng(
  String path,
  int width,
  int height,
  String label,
  bool transparent,
) {
  final bytes = File(path).readAsBytesSync();
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) throw StateError('$label is not a PNG.');
  }
  final header = ByteData.sublistView(bytes);
  final actualWidth = header.getUint32(16, Endian.big);
  final actualHeight = header.getUint32(20, Endian.big);
  if (actualWidth != width || actualHeight != height || bytes[25] != 6) {
    throw StateError('$label has invalid dimensions or is missing RGBA alpha.');
  }
  final decoded = _decodePngAlpha(bytes, actualWidth, actualHeight);
  final hasClear = decoded.any((alpha) => alpha == 0);
  final hasOpaque = decoded.any((alpha) => alpha == 255);
  if (hasOpaque != true ||
      (transparent && !hasClear) ||
      (!transparent && hasClear)) {
    throw StateError('$label has unexpected PNG alpha channel values.');
  }
}

List<int> _decodePngAlpha(Uint8List bytes, int width, int height) {
  var offset = 8;
  final compressed = BytesBuilder();
  while (offset < bytes.length) {
    final chunkLength = ByteData.sublistView(
      bytes,
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    if (type == 'IDAT') {
      compressed.add(bytes.sublist(offset + 8, offset + 8 + chunkLength));
    }
    offset += 12 + chunkLength;
    if (type == 'IEND') break;
  }
  final raw = ZLibDecoder().convert(compressed.takeBytes());
  final stride = width * 4;
  final result = List<int>.filled(width * height, 0);
  final previous = List<int>.filled(stride, 0);
  var source = 0;
  for (var y = 0; y < height; y++) {
    final filter = raw[source++];
    final row = List<int>.filled(stride, 0);
    for (var x = 0; x < stride; x++) {
      final value = raw[source++];
      final left = x >= 4 ? row[x - 4] : 0;
      final up = previous[x];
      final upperLeft = x >= 4 ? previous[x - 4] : 0;
      final predictor = switch (filter) {
        0 => 0,
        1 => left,
        2 => up,
        3 => (left + up) ~/ 2,
        4 => _paeth(left, up, upperLeft),
        _ => throw StateError('Unsupported PNG filter $filter.'),
      };
      row[x] = (value + predictor) & 0xFF;
    }
    for (var x = 0; x < width; x++) {
      result[y * width + x] = row[x * 4 + 3];
    }
    for (var x = 0; x < stride; x++) {
      previous[x] = row[x];
    }
  }
  return result;
}

int _paeth(int left, int up, int upperLeft) {
  final estimate = left + up - upperLeft;
  final dl = (estimate - left).abs();
  final du = (estimate - up).abs();
  final dul = (estimate - upperLeft).abs();
  if (dl <= du && dl <= dul) return left;
  return du <= dul ? up : upperLeft;
}

class PixelCanvas {
  PixelCanvas(this.width, this.height) : pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;

  String get opaqueBounds {
    var left = width;
    var top = height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (pixels[(y * width + x) * 4 + 3] == 0) continue;
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x);
        bottom = math.max(bottom, y);
      }
    }
    return 'x=$left..$right, y=$top..$bottom';
  }

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
    pixels[offset] = color >> 24 & 0xFF;
    pixels[offset + 1] = color >> 16 & 0xFF;
    pixels[offset + 2] = color >> 8 & 0xFF;
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

  void polygon(List<Point> points, int color) {
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
      crc = crc & 1 == 1 ? crc >> 1 ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
