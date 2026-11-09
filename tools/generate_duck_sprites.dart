import 'dart:io';
import 'dart:typed_data';

const int frameSize = 64;

const int outline = 0xff51443d;
const int feather = 0xfffffcf1;
const int featherLight = 0xffffffff;
const int featherShade = 0xffd9dce0;
const int wingShade = 0xffece6dc;
const int eye = 0xff392f2c;
const int beak = 0xffffa52e;
const int beakShade = 0xffe47d20;
const int feet = 0xfff58a32;
const int feetShade = 0xffd96324;
const int blush = 0xffffa6ad;
const int sparkle = 0xffffffff;
const int jacketOutline = 0xff11141a;
const int jacketLeather = 0xff252a32;
const int jacketShadow = 0xff1b2028;
const int jacketHighlight = 0xff4b5664;
const int jacketStitch = 0xffb49a7b;
const int jacketSteel = 0xffc4cbd3;

const List<(int, int)> _frontJacketRows = [
  (22, 41),
  (19, 44),
  (16, 47),
  (14, 49),
  (13, 50),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (13, 50),
  (14, 49),
  (15, 48),
  (16, 47),
  (17, 46),
  (18, 45),
  (19, 44),
  (20, 43),
  (22, 41),
  (25, 38),
  (28, 35),
];

const List<(int, int)> _rearJacketRows = [
  (23, 40),
  (20, 43),
  (17, 46),
  (15, 48),
  (14, 49),
  (13, 50),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (12, 51),
  (13, 50),
  (14, 49),
  (15, 48),
  (16, 47),
  (17, 46),
  (18, 45),
  (19, 44),
  (20, 43),
  (22, 41),
  (25, 38),
  (28, 35),
];

class Raster {
  Raster(this.width, this.height)
    : pixels = List<int>.filled(width * height, 0, growable: false);

  final int width;
  final int height;
  final List<int> pixels;

  int getPixel(int x, int y) => pixels[y * width + x];

  void setPixel(int x, int y, int color) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      pixels[y * width + x] = color;
    }
  }

  void fillRect(int x, int y, int w, int h, int color) {
    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        setPixel(x + dx, y + dy, color);
      }
    }
  }

  void ellipseMask(
    List<bool> mask, {
    required int centerX,
    required int centerY,
    required int radiusX,
    required int radiusY,
  }) {
    for (var y = centerY - radiusY; y <= centerY + radiusY; y++) {
      for (var x = centerX - radiusX; x <= centerX + radiusX; x++) {
        final dx = (x - centerX) / radiusX;
        final dy = (y - centerY) / radiusY;
        if (dx * dx + dy * dy <= 1) {
          mask[y * frameSize + x] = true;
        }
      }
    }
  }
}

Raster drawDuck({
  required int frame,
  required bool rear,
  bool jacket = false,
  bool heartPajamas = false,
}) {
  final image = Raster(frameSize, frameSize);
  final bob = rear
      ? const [0, -1, 0, 1][frame]
      : const [0, -1, 0, 0, 1, 0][frame];
  final body = List<bool>.filled(frameSize * frameSize, false);
  image.ellipseMask(
    body,
    centerX: 32,
    centerY: 23 + bob,
    radiusX: 15,
    radiusY: 14,
  );
  if (!jacket) {
    image.ellipseMask(
      body,
      centerX: 32,
      centerY: 41 + bob,
      radiusX: 21,
      radiusY: 15,
    );
  }

  final leftLift = rear
      ? const [0, -1, 0, 1][frame]
      : const [0, -1, 0, 0, 1, 0][frame];
  final rightLift = rear ? -leftLift : const [0, 0, -1, 0, 0, 1][frame];
  for (final (index, baseX) in [24, 34].indexed) {
    final lift = index == 0 ? leftLift : rightLift;
    final footX = baseX + (lift == 0 ? 0 : (index == 0 ? -1 : 1));
    final footY = 57 + bob + lift;
    image.fillRect(footX + 3, 52 + bob + lift, 3, 5, feetShade);
    image.fillRect(footX + 4, 53 + bob + lift, 2, 4, feet);
    image.fillRect(footX + 1, footY, 8, 2, feetShade);
    image.fillRect(footX + 2, footY, 6, 1, feet);
    image.setPixel(footX, footY - 1, feetShade);
    image.setPixel(footX + 9, footY - 1, feetShade);
  }

  for (var y = 0; y < frameSize; y++) {
    for (var x = 0; x < frameSize; x++) {
      if (!body[y * frameSize + x]) continue;
      final edge =
          !body[(y - 1) * frameSize + x] ||
          !body[(y + 1) * frameSize + x] ||
          !body[y * frameSize + x - 1] ||
          !body[y * frameSize + x + 1];
      if (edge) {
        image.setPixel(x, y, outline);
      } else {
        final head = y < 31 + bob;
        final shade =
            !head &&
            ((x < 32 && !body[y * frameSize + x - 3]) ||
                (x > 32 && !body[y * frameSize + x + 3]) ||
                (y > 42 + bob && !body[(y + 3) * frameSize + x]));
        image.setPixel(
          x,
          y,
          shade ? featherShade : (head ? featherLight : feather),
        );
      }
    }
  }

  final wingLift = rear
      ? const [0, -2, -3, -1][frame]
      : const [0, -1, -3, -1, 1, 0][frame];
  if (!jacket) {
    for (final side in [-1, 1]) {
      final cx = 32 + side * 16;
      final cy = 40 + bob + wingLift;
      for (var y = cy - 6; y <= cy + 6; y++) {
        for (var x = cx - 5; x <= cx + 5; x++) {
          final dx = (x - cx) / 5;
          final dy = (y - cy) / 6;
          if (dx * dx + dy * dy > 1) continue;
          final edge =
              ((x - 1 - cx) / 5) * ((x - 1 - cx) / 5) + dy * dy > 1 ||
              ((x + 1 - cx) / 5) * ((x + 1 - cx) / 5) + dy * dy > 1 ||
              dx * dx + ((y - 1 - cy) / 6) * ((y - 1 - cy) / 6) > 1 ||
              dx * dx + ((y + 1 - cy) / 6) * ((y + 1 - cy) / 6) > 1;
          final featherMark =
              (x == cx - 2 && y == cy + 1) ||
              (x == cx - 1 && y == cy + 2) ||
              (x == cx && y == cy + 3);
          image.setPixel(
            x,
            y,
            edge ? outline : (featherMark ? wingShade : feather),
          );
        }
      }
    }
  }

  if (jacket) {
    // Jacket variants are constructed from the head, feet, and clothing only.
    _drawFittedJacket(image, rear: rear, bob: bob);
  } else if (heartPajamas) {
    _drawHeartPajamas(image, rear: rear, bob: bob);
  }

  if (rear) {
    if (!jacket) {
      for (var featherIndex = 0; featherIndex < 3; featherIndex++) {
        final x = 28 + featherIndex * 4;
        final y = (featherIndex == 1 ? 45 : 46) + bob;
        image.setPixel(x, y, featherShade);
        image.setPixel(x + 1, y + 1, outline);
      }
    }
    return image;
  }

  final eyeY = 21 + bob;
  for (final eyeX in [25, 39]) {
    if (frame == 3) {
      image.fillRect(eyeX - 2, eyeY + 1, 5, 1, eye);
      image.setPixel(eyeX - 3, eyeY, eye);
      image.setPixel(eyeX + 3, eyeY, eye);
    } else {
      image.fillRect(eyeX - 1, eyeY - 2, 3, 5, eye);
      image.setPixel(eyeX - 1, eyeY - 2, sparkle);
    }
  }

  for (final cheekX in [19, 42]) {
    image.fillRect(cheekX, 27 + bob, 4, 2, blush);
    image.setPixel(cheekX + 1, 29 + bob, blush);
  }

  image.fillRect(29, 26 + bob, 6, 2, beakShade);
  image.fillRect(28, 27 + bob, 8, 2, beak);
  image.fillRect(29, 29 + bob, 6, 2, beak);
  image.fillRect(30, 31 + bob, 4, 1, beakShade);
  image.setPixel(30, 27 + bob, sparkle);
  return image;
}

void _drawFittedJacket(Raster image, {required bool rear, required int bob}) {
  final rows = rear ? _rearJacketRows : _frontJacketRows;
  final top = rear ? 33 : 32;

  void pixel(int x, int y, int color) => image.setPixel(x, y + bob, color);
  void row(int left, int right, int y, int color) {
    for (var x = left; x <= right; x++) {
      pixel(x, y, color);
    }
  }

  void block(int left, int top, int width, int height, int color) {
    for (var y = top; y < top + height; y++) {
      row(left, left + width - 1, y, color);
    }
  }

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final (left, right) = rows[rowIndex];
    final y = top + rowIndex;
    row(left, right, y, jacketOutline);
    row(left + 1, right - 1, y, jacketLeather);
    if (rowIndex >= 3 && rowIndex <= 16) {
      row(left + 1, left + 3, y, jacketShadow);
      row(right - 3, right - 1, y, jacketShadow);
      if (rowIndex >= 5 && rowIndex <= 12) {
        pixel(left + 4, y, jacketHighlight);
        pixel(right - 4, y, jacketHighlight);
      }
    }
  }

  void drawWingAt(int x, int y, int color) {
    pixel(x, y, color);
    pixel(63 - x, y, color);
  }

  final wingRows = [
    (15, 18),
    (13, 19),
    (10, 19),
    (9, 18),
    (10, 19),
    (12, 20),
    (15, 21),
  ];
  for (var rowIndex = 0; rowIndex < wingRows.length; rowIndex++) {
    final (left, right) = wingRows[rowIndex];
    final y = (rear ? 40 : 39) + rowIndex;
    for (var x = left; x <= right; x++) {
      drawWingAt(x, y, jacketOutline);
    }
    for (var x = left + 1; x < right; x++) {
      drawWingAt(x, y, rowIndex == 1 || rowIndex == 5 ? wingShade : feather);
    }
  }
  for (final (x, y) in [
    (13, 41),
    (12, 42),
    (11, 43),
    (12, 44),
    (14, 45),
    (15, 46),
  ]) {
    drawWingAt(x, y, featherLight);
  }

  if (rear) {
    row(28, 35, 31, jacketOutline);
    row(27, 36, 32, jacketOutline);
    row(28, 35, 32, jacketLeather);
    row(26, 37, 33, jacketOutline);
    row(27, 36, 33, jacketHighlight);
    row(25, 38, 34, jacketOutline);
    row(26, 37, 34, jacketLeather);
    row(24, 39, 35, jacketOutline);
    row(25, 38, 35, jacketHighlight);
    row(23, 40, 36, jacketOutline);
    row(24, 39, 36, jacketHighlight);
    row(27, 36, 37, jacketStitch);
    row(20, 27, 37, jacketStitch);
    row(36, 43, 37, jacketStitch);
    block(24, 39, 2, 9, jacketShadow);
    block(38, 39, 2, 9, jacketShadow);
    block(25, 40, 1, 8, jacketStitch);
    block(38, 40, 1, 8, jacketStitch);
    block(31, 39, 1, 12, jacketShadow);
    block(32, 40, 1, 11, jacketHighlight);
    row(28, 35, 44, jacketStitch);
    row(25, 38, 48, jacketStitch);
    row(21, 42, 50, jacketOutline);
    row(22, 41, 50, jacketHighlight);
    row(24, 39, 52, jacketStitch);
    row(27, 36, 54, jacketShadow);
    return;
  }

  // A low stand collar and small stepped lapels soften the neckline.
  row(28, 35, 32, jacketOutline);
  row(27, 36, 33, jacketOutline);
  row(28, 35, 33, jacketHighlight);
  row(28, 35, 34, jacketLeather);
  row(29, 34, 34, jacketHighlight);
  for (final (x, y, color) in [
    (24, 34, jacketOutline),
    (25, 34, jacketHighlight),
    (25, 35, jacketOutline),
    (26, 35, jacketStitch),
    (26, 36, jacketOutline),
    (27, 36, jacketHighlight),
    (27, 37, jacketOutline),
    (28, 37, jacketStitch),
    (28, 38, jacketOutline),
    (29, 38, jacketHighlight),
    (29, 39, jacketOutline),
    (30, 39, jacketStitch),
  ]) {
    drawWingAt(x, y, color);
  }

  // Continuous metal zip, shoulder piping, fitted sleeves and cuff hems.
  block(31, 40, 3, 12, jacketOutline);
  block(32, 40, 1, 11, jacketSteel);
  block(32, 50, 2, 2, jacketOutline);
  pixel(33, 51, jacketSteel);
  for (final y in [41, 43, 45, 47, 49]) {
    pixel(31, y, jacketStitch);
  }
  row(20, 26, 36, jacketStitch);
  row(37, 43, 36, jacketStitch);
  block(16, 39, 2, 5, jacketHighlight);
  block(46, 39, 2, 5, jacketHighlight);
  block(19, 41, 2, 5, jacketStitch);
  block(43, 41, 2, 5, jacketStitch);
  block(13, 46, 8, 2, jacketOutline);
  row(14, 19, 46, jacketHighlight);
  block(43, 46, 8, 2, jacketOutline);
  row(44, 49, 46, jacketHighlight);

  // Two shaped flap pockets with metal snaps sit on the rounded body panels.
  block(20, 43, 9, 5, jacketOutline);
  block(21, 44, 7, 3, jacketShadow);
  row(22, 27, 44, jacketHighlight);
  row(22, 27, 45, jacketStitch);
  pixel(27, 43, jacketSteel);
  block(35, 43, 9, 5, jacketOutline);
  block(36, 44, 7, 3, jacketShadow);
  row(36, 44, 44, jacketHighlight);
  row(36, 41, 45, jacketStitch);
  pixel(36, 43, jacketSteel);
  row(24, 39, 51, jacketHighlight);
  row(23, 40, 52, jacketOutline);
  row(25, 38, 52, jacketStitch);
}

void _drawHeartPajamas(Raster image, {required bool rear, required int bob}) {
  const pajamaOutline = 0xff8c4a65;
  const pajamaPink = 0xfff3aec5;
  const pajamaLight = 0xffffdce7;
  const pajamaShadow = 0xffd77e9c;
  const heart = 0xffc64f78;
  final rows = rear ? _rearJacketRows : _frontJacketRows;

  void pixel(int x, int y, int color) => image.setPixel(x, y + bob, color);
  void row(int left, int right, int y, int color) {
    for (var x = left; x <= right; x++) {
      pixel(x, y, color);
    }
  }

  for (var index = 0; index < rows.length; index++) {
    final (left, right) = rows[index];
    final y = (rear ? 33 : 32) + index;
    row(left, right, y, pajamaOutline);
    row(left + 1, right - 1, y, pajamaPink);
    if (index >= 4 && index <= 16) {
      pixel(left + 3, y, pajamaShadow);
      pixel(right - 3, y, pajamaShadow);
    }
  }

  void drawWingAt(int x, int y, int color) {
    pixel(x, y, color);
    pixel(63 - x, y, color);
  }

  const wingRows = [
    (15, 18),
    (13, 19),
    (10, 19),
    (9, 18),
    (10, 19),
    (12, 20),
    (15, 21),
  ];
  for (var index = 0; index < wingRows.length; index++) {
    final (left, right) = wingRows[index];
    final y = (rear ? 40 : 39) + index;
    for (var x = left; x <= right; x++) {
      drawWingAt(x, y, pajamaOutline);
    }
    for (var x = left + 1; x < right; x++) {
      drawWingAt(x, y, index == 1 || index == 5 ? pajamaLight : pajamaPink);
    }
  }

  void drawHeart(int left, int top) {
    for (final (x, y) in [
      (1, 0),
      (3, 0),
      (0, 1),
      (1, 1),
      (2, 1),
      (3, 1),
      (4, 1),
      (1, 2),
      (2, 2),
      (3, 2),
      (2, 3),
    ]) {
      pixel(left + x, top + y, heart);
    }
  }

  if (rear) {
    row(28, 35, 31, pajamaOutline);
    row(28, 35, 32, pajamaLight);
    row(27, 36, 33, pajamaOutline);
    row(28, 35, 34, pajamaPink);
    drawHeart(29, 42);
    drawHeart(23, 48);
  } else {
    row(28, 35, 32, pajamaOutline);
    row(28, 35, 33, pajamaLight);
    row(27, 36, 34, pajamaOutline);
    row(28, 35, 35, pajamaPink);
    drawHeart(21, 41);
    drawHeart(38, 45);
  }
  row(14, 20, 46, pajamaOutline);
  row(44, 50, 46, pajamaOutline);
  row(15, 19, 47, pajamaLight);
  row(45, 49, 47, pajamaLight);
}

Raster composeSheet(List<Raster> frames) {
  final sheet = Raster(frameSize * frames.length, frameSize);
  for (var frame = 0; frame < frames.length; frame++) {
    for (var y = 0; y < frameSize; y++) {
      for (var x = 0; x < frameSize; x++) {
        sheet.setPixel(frame * frameSize + x, y, frames[frame].getPixel(x, y));
      }
    }
  }
  return sheet;
}

Raster makePreview(List<Raster> front, List<Raster> rear) {
  const gap = 4;
  const columns = 4;
  const rows = 3;
  final preview = Raster(
    columns * frameSize + (columns + 1) * gap,
    rows * frameSize + (rows + 1) * gap,
  );
  for (var i = 0; i < preview.pixels.length; i++) {
    preview.pixels[i] = 0xfffff5e6;
  }
  final allFrames = [...front, ...rear];
  for (var i = 0; i < allFrames.length; i++) {
    final row = i < 6 ? i ~/ 4 : 2;
    final column = i < 6 ? i % 4 : i - 6;
    final frame = allFrames[i];
    for (var y = 0; y < frameSize; y++) {
      for (var x = 0; x < frameSize; x++) {
        final px = gap + column * (frameSize + gap) + x;
        final py = gap + row * (frameSize + gap) + y;
        if (frame.getPixel(x, y) != 0) {
          preview.setPixel(px, py, frame.getPixel(x, y));
        } else {
          preview.setPixel(
            px,
            py,
            (column + row).isEven ? 0xffffecd9 : 0xfffff0e2,
          );
        }
      }
    }
  }
  return preview;
}

Raster enlarge(Raster source, int scale) {
  final enlarged = Raster(source.width * scale, source.height * scale);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final color = source.getPixel(x, y);
      for (var dy = 0; dy < scale; dy++) {
        for (var dx = 0; dx < scale; dx++) {
          enlarged.setPixel(x * scale + dx, y * scale + dy, color);
        }
      }
    }
  }
  return enlarged;
}

Raster makeTransparentCharacterPreview(Raster front, Raster rear) {
  const scale = 4;
  final preview = Raster(frameSize * scale * 2, frameSize * scale);
  void copy(Raster source, int targetLeft) {
    for (var y = 0; y < frameSize; y++) {
      for (var x = 0; x < frameSize; x++) {
        final color = source.getPixel(x, y);
        if (color == 0) continue;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            preview.setPixel(
              targetLeft + x * scale + dx,
              y * scale + dy,
              color,
            );
          }
        }
      }
    }
  }

  copy(front, 0);
  copy(rear, frameSize * scale);
  return preview;
}

Raster _drawGroceryProduct(String id) {
  const size = 16;
  const ink = 0xff382f2c;
  const cream = 0xffffe19a;
  const paper = 0xffd4a54e;
  const paperShade = 0xffb88b50;
  const green = 0xff3e794c;
  const greenLight = 0xff79ad5f;
  const red = 0xffd85254;
  const redLight = 0xfff18369;
  const glass = 0xff78a5a0;
  const metal = 0xffadb8aa;
  const worm = 0xff77b957;
  const wormLight = 0xffb4d96a;
  const pizza = 0xffffcf68;
  const leaf = 0xff477a4f;
  const honeyLight = 0xffffd66b;

  final image = Raster(size, size);
  switch (id) {
    case 'crumbs':
      image
        ..fillRect(3, 1, 10, 1, ink)
        ..fillRect(2, 2, 12, 11, ink)
        ..fillRect(4, 13, 8, 1, ink)
        ..fillRect(3, 2, 10, 10, paperShade)
        ..fillRect(4, 2, 7, 9, cream)
        ..fillRect(5, 4, 5, 4, paper)
        ..fillRect(6, 4, 3, 1, 0xfff4d47b)
        ..fillRect(5, 8, 5, 1, ink)
        ..fillRect(6, 9, 3, 1, 0xfff4d47b)
        ..fillRect(5, 11, 5, 1, ink)
        ..fillRect(11, 3, 1, 8, paperShade);
    case 'watermelon':
      for (var y = 4; y <= 13; y++) {
        final width = 2 * (y - 3);
        final left = 8 - width ~/ 2;
        image.fillRect(left, y, width, 1, ink);
        if (y < 13) image.fillRect(left + 1, y + 1, width - 2, 1, red);
      }
      image
        ..fillRect(3, 10, 10, 2, green)
        ..fillRect(4, 12, 8, 1, greenLight)
        ..fillRect(5, 5, 2, 1, redLight)
        ..setPixel(7, 8, ink)
        ..setPixel(9, 9, ink)
        ..setPixel(6, 10, ink);
    case 'worm':
      image
        ..fillRect(3, 1, 10, 2, ink)
        ..fillRect(4, 1, 8, 1, metal)
        ..fillRect(2, 3, 12, 10, ink)
        ..fillRect(3, 4, 10, 8, glass)
        ..fillRect(4, 4, 2, 7, 0xffc7d8bf)
        ..fillRect(6, 5, 2, 2, worm)
        ..fillRect(8, 6, 2, 2, wormLight)
        ..fillRect(5, 8, 3, 2, worm)
        ..fillRect(9, 9, 2, 2, wormLight)
        ..setPixel(7, 5, ink)
        ..setPixel(9, 7, ink)
        ..setPixel(6, 10, ink)
        ..fillRect(3, 12, 10, 1, ink);
    case 'pizza':
      image
        ..fillRect(2, 4, 12, 8, ink)
        ..fillRect(3, 3, 10, 8, 0xffd45b43)
        ..fillRect(4, 4, 8, 6, pizza)
        ..fillRect(5, 4, 5, 2, 0xffffe19a)
        ..fillRect(6, 6, 2, 2, 0xffd85254)
        ..setPixel(10, 7, 0xff3e794c)
        ..setPixel(5, 9, 0xff3e794c)
        ..fillRect(3, 11, 10, 1, 0xffb88b50)
        ..fillRect(4, 12, 8, 1, ink)
        ..fillRect(5, 2, 6, 1, 0xffd45b43);
    case 'apple':
      image
        ..fillRect(7, 2, 2, 2, ink)
        ..fillRect(9, 1, 3, 2, leaf)
        ..fillRect(4, 4, 8, 1, ink)
        ..fillRect(2, 5, 12, 6, ink)
        ..fillRect(3, 11, 10, 2, ink)
        ..fillRect(4, 5, 8, 6, red)
        ..fillRect(5, 5, 3, 3, redLight)
        ..fillRect(4, 11, 2, 1, red)
        ..fillRect(11, 11, 2, 1, red);
    case 'cheese':
      image
        ..fillRect(2, 8, 12, 5, ink)
        ..fillRect(3, 5, 10, 8, 0xffe7bb55)
        ..fillRect(4, 4, 8, 2, ink)
        ..fillRect(4, 6, 8, 6, honeyLight)
        ..fillRect(5, 7, 3, 2, cream)
        ..fillRect(9, 8, 2, 2, 0xffd99a37)
        ..fillRect(6, 10, 2, 1, 0xffd99a37)
        ..fillRect(3, 12, 10, 1, 0xffb88b50);
    case 'carrot':
      image
        ..fillRect(6, 1, 2, 4, ink)
        ..fillRect(4, 2, 3, 2, leaf)
        ..fillRect(8, 2, 4, 2, greenLight)
        ..fillRect(3, 4, 10, 2, ink)
        ..fillRect(4, 5, 8, 2, 0xffffa34b)
        ..fillRect(5, 7, 6, 2, 0xffff8c35)
        ..fillRect(6, 9, 4, 2, 0xffed702b)
        ..fillRect(7, 11, 2, 2, ink)
        ..fillRect(6, 6, 2, 1, 0xffffd268)
        ..fillRect(8, 8, 2, 1, 0xffffd268);
    case 'milk':
      image
        ..fillRect(5, 1, 6, 2, ink)
        ..fillRect(4, 3, 8, 10, ink)
        ..fillRect(5, 4, 6, 8, 0xfff4f0db)
        ..fillRect(6, 4, 3, 6, 0xffd7e5df)
        ..fillRect(8, 7, 3, 3, 0xff6fa4aa)
        ..fillRect(9, 8, 1, 1, 0xfff4f0db)
        ..fillRect(5, 11, 6, 1, 0xffb6c8bd)
        ..fillRect(6, 2, 4, 1, 0xfffaf7e9);
  }
  return image;
}

Raster _makeDetailedGroceryProduct(String id) {
  final image = enlarge(_drawGroceryProduct(id), 4);
  final details = switch (id) {
    'crumbs' => [
      (19, 36, 0xffd5a24f),
      (23, 36, 0xffffedbd),
      (27, 36, 0xffd5a24f),
      (31, 36, 0xffffedbd),
      (35, 36, 0xffd5a24f),
      (22, 40, 0xffb88b50),
      (26, 40, 0xffffedbd),
      (30, 40, 0xffb88b50),
      (34, 40, 0xffffedbd),
      (18, 29, 0xffb88b50),
      (41, 28, 0xffb88b50),
      (20, 44, 0xffb88b50),
      (39, 44, 0xffb88b50),
      (24, 47, 0xffd5a24f),
      (29, 47, 0xffffedbd),
      (34, 47, 0xffd5a24f),
    ],
    'watermelon' => [
      (27, 25, 0xff382f2c),
      (36, 30, 0xff382f2c),
      (23, 35, 0xff382f2c),
      (41, 38, 0xff382f2c),
      (32, 42, 0xff382f2c),
      (20, 44, 0xff3e794c),
      (28, 45, 0xff79ad5f),
      (38, 45, 0xff3e794c),
      (46, 44, 0xff79ad5f),
      (23, 48, 0xff315f3c),
      (31, 48, 0xff9fca68),
      (41, 48, 0xff315f3c),
      (26, 20, 0xfff18369),
      (30, 18, 0xffffb28a),
      (43, 36, 0xfff18369),
    ],
    'worm' => [
      (17, 19, 0xfff3fff0),
      (18, 20, 0xfff3fff0),
      (17, 27, 0xfff3fff0),
      (18, 28, 0xfff3fff0),
      (46, 20, 0xfff3fff0),
      (47, 21, 0xfff3fff0),
      (46, 38, 0xffd9ece2),
      (47, 39, 0xffd9ece2),
      (27, 23, 0xff4c8f49),
      (31, 23, 0xffd3ed80),
      (35, 27, 0xff4c8f49),
      (39, 31, 0xffd3ed80),
      (27, 35, 0xff4c8f49),
      (31, 35, 0xffd3ed80),
      (39, 39, 0xff4c8f49),
      (35, 43, 0xffd3ed80),
      (24, 43, 0xff4c8f49),
    ],
    'pizza' => [
      (21, 22, 0xffbd4a3e),
      (22, 23, 0xfff48b64),
      (39, 22, 0xffbd4a3e),
      (40, 23, 0xfff48b64),
      (31, 31, 0xffbd4a3e),
      (32, 32, 0xfff48b64),
      (23, 38, 0xffbd4a3e),
      (24, 39, 0xfff48b64),
      (42, 36, 0xffbd4a3e),
      (43, 37, 0xfff48b64),
      (28, 20, 0xffffe8a1),
      (29, 21, 0xffffe8a1),
      (37, 42, 0xff558047),
      (38, 41, 0xff79ad5f),
      (18, 43, 0xffa66d43),
      (26, 45, 0xffa66d43),
      (37, 45, 0xffa66d43),
    ],
    'apple' => [
      (20, 25, 0xffffa184),
      (21, 26, 0xffffa184),
      (20, 33, 0xffb93847),
      (44, 28, 0xffb93847),
      (24, 43, 0xffb93847),
      (41, 42, 0xffb93847),
      (29, 47, 0xffb93847),
      (35, 47, 0xffb93847),
      (38, 11, 0xff79ad5f),
      (42, 12, 0xff3e794c),
      (39, 8, 0xffa7c96d),
      (33, 16, 0xff6a4330),
      (36, 17, 0xff6a4330),
    ],
    'cheese' => [
      (21, 31, 0xffffe991),
      (22, 32, 0xffffe991),
      (36, 28, 0xffc88932),
      (37, 29, 0xffffd66b),
      (42, 37, 0xffc88932),
      (43, 38, 0xffffd66b),
      (28, 41, 0xffc88932),
      (29, 42, 0xffffd66b),
      (35, 45, 0xffc88932),
      (36, 46, 0xffffd66b),
      (19, 47, 0xffb88b50),
      (44, 47, 0xffb88b50),
      (25, 21, 0xffffe991),
      (26, 22, 0xffffe991),
    ],
    'carrot' => [
      (27, 28, 0xffffd268),
      (28, 29, 0xffffd268),
      (36, 36, 0xffffd268),
      (37, 37, 0xffffd268),
      (31, 43, 0xffffbd53),
      (32, 44, 0xffffbd53),
      (25, 48, 0xffed702b),
      (39, 47, 0xffed702b),
      (21, 22, 0xff79ad5f),
      (22, 23, 0xff79ad5f),
      (38, 16, 0xff3e794c),
      (42, 17, 0xff3e794c),
      (45, 15, 0xff9bc568),
      (30, 13, 0xff79ad5f),
    ],
    'milk' => [
      (24, 18, 0xfffffff1),
      (25, 19, 0xfffffff1),
      (24, 26, 0xfffffff1),
      (25, 27, 0xfffffff1),
      (42, 20, 0xffb3d3cc),
      (43, 21, 0xffb3d3cc),
      (39, 32, 0xff4e8388),
      (40, 33, 0xff4e8388),
      (34, 38, 0xff4e8388),
      (35, 39, 0xff4e8388),
      (29, 43, 0xffb6c8bd),
      (30, 44, 0xffb6c8bd),
      (37, 47, 0xffb6c8bd),
      (38, 48, 0xffb6c8bd),
      (31, 29, 0xfff4f0db),
      (32, 29, 0xfff4f0db),
    ],
    _ => <(int, int, int)>[],
  };
  for (final (x, y, color) in details) {
    image.setPixel(x, y, color);
  }
  return image;
}

Raster _makeGroceryProductSheet(List<String> productIds) {
  const iconScale = 1;
  final sheet = Raster(productIds.length * 64 * iconScale, 64 * iconScale);
  for (var index = 0; index < productIds.length; index++) {
    final icon = _makeDetailedGroceryProduct(productIds[index]);
    for (var y = 0; y < icon.height; y++) {
      for (var x = 0; x < icon.width; x++) {
        sheet.setPixel(index * icon.width + x, y, icon.getPixel(x, y));
      }
    }
  }
  return sheet;
}

Raster _makeProductPriceTag() {
  final tag = Raster(48, 24);
  tag
    ..fillRect(1, 2, 46, 20, 0xff382f2c)
    ..fillRect(3, 1, 42, 20, 0xfff1dfb8)
    ..fillRect(4, 2, 40, 16, 0xfffff3d9)
    ..fillRect(5, 3, 2, 14, 0xffc7aa72)
    ..fillRect(41, 3, 2, 14, 0xffc7aa72)
    ..fillRect(8, 19, 32, 1, 0xffa98b59);
  return tag;
}

void _fillPolygon(Raster image, List<(int, int)> points, int color) {
  final minY = points.map((point) => point.$2).reduce((a, b) => a < b ? a : b);
  final maxY = points.map((point) => point.$2).reduce((a, b) => a > b ? a : b);
  for (var y = minY; y <= maxY; y++) {
    final intersections = <double>[];
    for (var i = 0; i < points.length; i++) {
      final (x1, y1) = points[i];
      final (x2, y2) = points[(i + 1) % points.length];
      if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
        intersections.add(x1 + (y - y1) * (x2 - x1) / (y2 - y1));
      }
    }
    intersections.sort();
    for (var i = 0; i + 1 < intersections.length; i += 2) {
      for (
        var x = intersections[i].ceil();
        x <= intersections[i + 1].floor();
        x++
      ) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _drawLine(Raster image, int x0, int y0, int x1, int y1, int color) {
  final dx = (x1 - x0).abs();
  final dy = (y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final sy = y0 < y1 ? 1 : -1;
  var error = dx - dy;
  while (true) {
    image.setPixel(x0, y0, color);
    if (x0 == x1 && y0 == y1) return;
    final doubled = error * 2;
    if (doubled > -dy) {
      error -= dy;
      x0 += sx;
    }
    if (doubled < dx) {
      error += dx;
      y0 += sy;
    }
  }
}

void _copyRaster(Raster target, Raster source, int left, int top) {
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final color = source.getPixel(x, y);
      if ((color >> 24) == 0) continue;
      target.setPixel(left + x, top + y, color);
    }
  }
}

Raster _makePixelMarketScene(List<String> productIds) {
  const width = 320;
  const height = 240;
  const ink = 0xff40352f;
  const wall = 0xffdfd0aa;
  const wallLight = 0xfff4e8c9;
  const shadow = 0xff89725a;
  const shelf = 0xff845640;
  const shelfLight = 0xffbb8757;
  const teal = 0xff477c70;
  const tealShade = 0xff315f58;
  const floor = 0xffc29669;
  const floorLight = 0xffe0b985;
  final scene = Raster(width, height);
  scene.fillRect(0, 0, width, height, wall);
  scene.fillRect(0, 0, width, 75, wallLight);
  scene.fillRect(0, 70, width, 5, shadow);

  // Back wall panels and a distant illuminated aisle sign.
  for (final x in [20, 82, 144, 206, 268]) {
    scene
      ..fillRect(x, 15, 44, 42, 0xffd2c19b)
      ..fillRect(x + 3, 18, 38, 36, 0xfff5eacd)
      ..fillRect(x + 4, 19, 35, 3, 0xfffff7df);
  }
  scene
    ..fillRect(116, 4, 88, 14, ink)
    ..fillRect(120, 6, 80, 9, teal)
    ..fillRect(124, 8, 72, 2, 0xff80ad91);

  _fillPolygon(scene, [(0, 74), (320, 74), (320, 240), (0, 240)], floor);
  _fillPolygon(scene, [
    (144, 74),
    (176, 74),
    (302, 240),
    (18, 240),
  ], floorLight);
  _fillPolygon(scene, [(151, 74), (169, 74), (256, 240), (64, 240)], floor);
  for (var row = 0; row < 7; row++) {
    final y = 91 + row * row * 2;
    _drawLine(scene, 0, y, 320, y, row.isEven ? 0xffa77e58 : 0xffd2a779);
    final widthInset = 13 + row * 12;
    _drawLine(scene, widthInset, 75, 0, y + 22, 0xffa77e58);
    _drawLine(scene, 320 - widthInset, 75, 320, y + 22, 0xffa77e58);
  }

  // Deep side gondolas with perspective rails and shaded end panels.
  for (final side in [0, 1]) {
    final leftShelf = side == 0;
    final outer = leftShelf ? 0 : 320;
    final inner = leftShelf ? 113 : 207;
    for (var level = 0; level < 4; level++) {
      final y = 76 + level * 37;
      final inset = 6 + level * 5;
      final x1 = leftShelf ? outer : inner + inset;
      final x2 = leftShelf ? inner - inset : outer;
      final face = shelf;
      final railShade = 0xff5d4034;
      _fillPolygon(scene, [
        (x1, y),
        (x2, y - 4),
        (x2, y + 2),
        (x1, y + 9),
      ], railShade);
      _fillPolygon(scene, [
        (x1, y + 2),
        (x2, y - 2),
        (x2, y + 7),
        (x1, y + 13),
      ], face);
      _drawLine(scene, x1, y + 2, x2, y - 2, shelfLight);
      _drawLine(scene, x1, y + 13, x2, y + 7, ink);
      _fillPolygon(
        scene,
        leftShelf
            ? [(0, y + 14), (x1 + 4, y + 14), (x1 + 8, y + 35), (0, y + 42)]
            : [
                (x1 - 4, y + 14),
                (320, y + 14),
                (320, y + 42),
                (x1 - 8, y + 35),
              ],
        leftShelf ? teal : tealShade,
      );
    }
  }

  // Put all products on two readable shelf levels with blank dynamic price cards.
  for (var index = 0; index < productIds.length; index++) {
    final rowIndex = index ~/ 4;
    final col = index % 4;
    final x = 13 + col * 76;
    final y = rowIndex == 0 ? 99 : 174;
    final icon = enlarge(_drawGroceryProduct(productIds[index]), 2);
    _copyRaster(scene, icon, x + 1, y - 46);
    scene
      ..fillRect(x, y - 12, 34, 17, ink)
      ..fillRect(x + 1, y - 11, 32, 15, 0xfffff0d0)
      ..fillRect(x + 2, y - 10, 30, 2, 0xffd6c08e)
      ..fillRect(x + 3, y + 1, 28, 1, 0xffc6ad7b);
    _drawLine(scene, x + 1, y + 16, x + 32, y + 16, 0xffd6c08e);
  }

  // Perspective aisle-end feature table and a small paper bag stack.
  _fillPolygon(scene, [(100, 204), (220, 204), (241, 231), (79, 231)], shelf);
  _fillPolygon(scene, [
    (105, 204),
    (215, 204),
    (231, 222),
    (89, 222),
  ], shelfLight);
  scene
    ..fillRect(105, 191, 18, 12, ink)
    ..fillRect(108, 188, 12, 15, 0xfff0d899)
    ..fillRect(126, 197, 15, 6, ink)
    ..fillRect(128, 195, 11, 8, 0xffc59854)
    ..fillRect(182, 191, 22, 12, ink)
    ..fillRect(185, 188, 16, 15, 0xfff0d899);
  return scene;
}

Raster _makePixelCheckoutScene() {
  const width = 320;
  const height = 240;
  const ink = 0xff40352f;
  const wall = 0xffe5d6b3;
  const wallLight = 0xfffff0d2;
  const teal = 0xff477c70;
  const floor = 0xffbd9367;
  const woodLight = 0xffbd8756;
  const metal = 0xff657678;
  const belt = 0xff515b5c;
  final scene = Raster(width, height);
  scene
    ..fillRect(0, 0, width, height, wall)
    ..fillRect(0, 0, width, 86, wallLight)
    ..fillRect(0, 82, width, 4, 0xff89725a);

  for (final x in [18, 82, 146, 210, 274]) {
    scene
      ..fillRect(x, 17, 44, 52, 0xffd6c49c)
      ..fillRect(x + 3, 20, 38, 45, 0xfff5e9c9)
      ..fillRect(x + 4, 21, 3, 42, 0xfffff6dc);
  }
  scene
    ..fillRect(102, 5, 116, 15, ink)
    ..fillRect(106, 7, 108, 10, teal)
    ..fillRect(114, 9, 92, 2, 0xff9bc5a0);

  _fillPolygon(scene, [(0, 87), (320, 87), (320, 240), (0, 240)], floor);
  _fillPolygon(scene, [
    (145, 87),
    (175, 87),
    (286, 240),
    (34, 240),
  ], 0xffd7ae7b);
  for (var i = 0; i < 6; i++) {
    final y = 101 + i * i * 3;
    _drawLine(scene, 0, y, 320, y, i.isEven ? 0xffa27a55 : 0xffdfb987);
  }
  for (var x = 42; x < 320; x += 40) {
    _drawLine(scene, 160, 88, x, 239, 0xffa9815b);
  }

  // A floor mat marks the cashier's standing point behind the counter.
  _fillPolygon(scene, [(126, 111), (194, 111), (205, 132), (115, 132)], ink);
  _fillPolygon(scene, [(131, 113), (189, 113), (198, 129), (122, 129)], teal);
  _drawLine(scene, 135, 117, 185, 117, 0xffa8c9a5);
  for (final x in [132, 188]) {
    scene
      ..fillRect(x, 121, 3, 3, 0xffd7cf9f)
      ..fillRect(x + 1, 122, 1, 1, ink);
  }

  // Cash register housing, display, scanner and conveyor belt.
  _fillPolygon(scene, [(212, 81), (265, 81), (278, 111), (204, 111)], ink);
  _fillPolygon(scene, [(216, 83), (261, 83), (271, 107), (209, 107)], metal);
  scene
    ..fillRect(224, 71, 34, 19, ink)
    ..fillRect(227, 73, 28, 13, 0xff243338)
    ..fillRect(230, 76, 22, 7, 0xff83b399)
    ..fillRect(233, 78, 4, 2, 0xffd5e0ac)
    ..fillRect(240, 78, 9, 2, 0xffd5e0ac)
    ..fillRect(207, 100, 13, 5, 0xffe96858)
    ..fillRect(209, 101, 9, 2, 0xffffb16d);

  // Front counter uses stepped depth bands and a long scan belt.
  _fillPolygon(scene, [(18, 133), (302, 133), (320, 158), (0, 158)], ink);
  _fillPolygon(scene, [(22, 135), (298, 135), (312, 151), (8, 151)], woodLight);
  _drawLine(scene, 28, 138, 292, 138, 0xffe1b06d);
  _fillPolygon(scene, [(42, 147), (278, 147), (286, 170), (34, 170)], ink);
  _fillPolygon(scene, [(47, 150), (273, 150), (279, 166), (41, 166)], belt);
  for (var x = 50; x < 270; x += 16) {
    scene
      ..fillRect(x, 153, 7, 2, 0xff748080)
      ..fillRect(x + 5, 159, 5, 1, 0xff384445);
  }
  scene
    ..fillRect(286, 142, 17, 8, ink)
    ..fillRect(288, 144, 13, 4, 0xffe3d8b8)
    ..fillRect(292, 145, 5, 2, 0xff8bb7a5);

  _fillPolygon(scene, [(0, 171), (320, 171), (320, 240), (0, 240)], 0xff72503d);
  scene
    ..fillRect(0, 174, 320, 4, 0xff9e704d)
    ..fillRect(12, 185, 26, 36, 0xff5b4437)
    ..fillRect(17, 188, 16, 27, 0xffa77c52)
    ..fillRect(45, 190, 25, 30, 0xff5b4437)
    ..fillRect(49, 193, 17, 23, 0xffd7be8e)
    ..fillRect(247, 185, 28, 35, 0xff5b4437)
    ..fillRect(252, 188, 18, 27, 0xff7f9d78)
    ..fillRect(284, 190, 24, 30, 0xff5b4437)
    ..fillRect(288, 193, 16, 22, 0xffd2a45e);
  return scene;
}

Raster _makeCashierDuck(int frame) {
  const ink = 0xff40352f;
  final image = drawDuck(frame: frame, rear: false);
  final bob = const [0, -1, 0, 0, 1, 0][frame];
  void rect(int x, int y, int width, int height, int color) =>
      image.fillRect(x, y + bob, width, height, color);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final replacement = switch (pixel) {
        featherLight => 0xffffed9a,
        feather => 0xffffd95b,
        featherShade => 0xffe7b94d,
        wingShade => 0xffffe789,
        _ => pixel,
      };
      image.setPixel(x, y, replacement);
    }
  }

  // Teal cashier cap and striped apron are painted into the yellow character.
  rect(23, 10, 18, 2, ink);
  rect(21, 12, 22, 3, 0xff315f58);
  rect(23, 12, 17, 1, 0xff6fa48c);
  rect(19, 15, 27, 2, ink);
  rect(21, 15, 23, 1, 0xff315f58);
  rect(21, 35, 22, 2, ink);
  rect(23, 37, 18, 12, 0xff315f58);
  rect(24, 38, 16, 9, 0xff477c70);
  rect(25, 40, 14, 1, 0xffa8c9a5);
  rect(25, 43, 14, 1, 0xffa8c9a5);
  rect(28, 38, 2, 5, 0xff294c49);
  rect(34, 38, 2, 5, 0xff294c49);
  rect(29, 46, 6, 2, 0xffd2ad54);
  rect(31, 46, 2, 2, 0xffffe09a);
  return image;
}

Raster _makeCheckoutPreview(Raster scene, Raster cashier) {
  final preview = enlarge(scene, 3);
  _copyRaster(preview, enlarge(cashier, 3), 128 * 3, 50 * 3);
  return preview;
}

Raster _joinScenePreviews(Raster market, Raster checkout) {
  final preview = Raster(market.width + checkout.width, market.height);
  _copyRaster(preview, market, 0, 0);
  _copyRaster(preview, checkout, market.width, 0);
  return preview;
}

Raster _makeFrameStrip(List<Raster> frames) {
  final strip = Raster(frames.length * frameSize, frameSize);
  for (var index = 0; index < frames.length; index++) {
    _copyRaster(strip, frames[index], index * frameSize, 0);
  }
  return strip;
}

Uint8List encodePng(Raster image) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < image.height; y++) {
    raw.addByte(0);
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      raw
        ..addByte((pixel >> 16) & 0xff)
        ..addByte((pixel >> 8) & 0xff)
        ..addByte(pixel & 0xff)
        ..addByte((pixel >> 24) & 0xff);
    }
  }

  final header = BytesBuilder(copy: false)
    ..add(_uint32(image.width))
    ..add(_uint32(image.height))
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
  return (crc ^ 0xffffffff) & 0xffffffff;
}

class _PreviewCell {
  const _PreviewCell(this.image, this.label);

  final Raster image;
  final String label;
}

class _PreviewSection {
  const _PreviewSection(this.title, this.cells);

  final String title;
  final List<_PreviewCell> cells;
}

const int _previewCellWidth = 84;
const int _previewCellHeight = 102;
const int _previewSpriteTop = 20;

const Map<String, List<String>> _font = {
  ' ': ['000', '000', '000', '000', '000'],
  '>': ['100', '010', '001', '010', '100'],
  '0': ['111', '101', '101', '101', '111'],
  '1': ['010', '110', '010', '010', '111'],
  '2': ['110', '001', '010', '100', '111'],
  '3': ['110', '001', '010', '001', '110'],
  '4': ['101', '101', '111', '001', '001'],
  '5': ['111', '100', '110', '001', '110'],
  '6': ['011', '100', '110', '101', '010'],
  '7': ['111', '001', '010', '010', '010'],
  'A': ['010', '101', '111', '101', '101'],
  'D': ['110', '101', '101', '101', '110'],
  'E': ['111', '100', '110', '100', '111'],
  'F': ['111', '100', '110', '100', '100'],
  'I': ['111', '010', '010', '010', '111'],
  'J': ['011', '001', '001', '101', '010'],
  'K': ['101', '101', '110', '101', '101'],
  'L': ['100', '100', '100', '100', '111'],
  'M': ['101', '111', '111', '101', '101'],
  'O': ['010', '101', '101', '101', '010'],
  'P': ['110', '101', '110', '100', '100'],
  'R': ['110', '101', '110', '101', '101'],
  'S': ['011', '100', '010', '001', '110'],
  'U': ['101', '101', '101', '101', '111'],
  'Y': ['101', '101', '010', '010', '010'],
};

void _drawText(Raster image, String text, int x, int y, int color) {
  var cursor = x;
  for (final character in text.split('')) {
    final glyph = _font[character];
    if (glyph != null) {
      for (var row = 0; row < glyph.length; row++) {
        for (var column = 0; column < glyph[row].length; column++) {
          if (glyph[row][column] == '1') {
            image.setPixel(cursor + column, y + row, color);
          }
        }
      }
    }
    cursor += 4;
  }
}

void _fillPreviewCell(Raster image, int left, int top) {
  for (var y = 0; y < _previewCellHeight; y++) {
    for (var x = 0; x < _previewCellWidth; x++) {
      final checker = ((x ~/ 8) + (y ~/ 8)).isEven;
      image.setPixel(left + x, top + y, checker ? 0xfffff5e6 : 0xffffead7);
    }
  }
}

void _drawSprite(
  Raster target,
  Raster source, {
  required double centerX,
  required double centerY,
  double scaleX = 1,
  double scaleY = 1,
  double opacity = 1,
}) {
  int blend(int foreground, int background, double alpha) =>
      ((foreground * alpha + background * (255 - alpha)) / 255).round();

  for (var y = -8; y < frameSize + 8; y++) {
    for (var x = -8; x < frameSize + 8; x++) {
      final sourceX = ((x - 32) / scaleX + 32).round();
      final sourceY = ((y - 32) / scaleY + 32).round();
      if (sourceX < 0 ||
          sourceX >= frameSize ||
          sourceY < 0 ||
          sourceY >= frameSize) {
        continue;
      }
      final color = source.getPixel(sourceX, sourceY);
      if (color == 0) continue;
      final targetX = (centerX - 32 + x).round();
      final targetY = (centerY - 32 + y).round();
      if (targetX < 0 ||
          targetX >= target.width ||
          targetY < 0 ||
          targetY >= target.height) {
        continue;
      }
      final alpha = ((color >> 24) & 0xff) * opacity;
      if (alpha <= 0) continue;
      final under = target.getPixel(targetX, targetY);
      final underAlpha = (under >> 24) & 0xff;
      target.setPixel(
        targetX,
        targetY,
        0xff000000 |
            (blend((color >> 16) & 0xff, (under >> 16) & 0xff, alpha) << 16) |
            (blend((color >> 8) & 0xff, (under >> 8) & 0xff, alpha) << 8) |
            blend(color & 0xff, underAlpha == 0 ? 255 : under & 0xff, alpha),
      );
    }
  }
}

Raster _makePoseCell(
  Raster source, {
  double dx = 0,
  double dy = 0,
  double scaleX = 1,
  double scaleY = 1,
}) {
  final cell = Raster(_previewCellWidth, _previewCellHeight);
  _fillPreviewCell(cell, 0, 0);
  _drawSprite(
    cell,
    source,
    centerX: _previewCellWidth / 2 + dx,
    centerY: _previewSpriteTop + frameSize / 2 + dy,
    scaleX: scaleX,
    scaleY: scaleY,
  );
  return cell;
}

Raster _moodFrame(Raster source, String mood, int frame) {
  final image = Raster(frameSize, frameSize)..pixels.setAll(0, source.pixels);
  if (mood == 'neutral') return image;
  final bob = const [0, -1, 0, 0, 1, 0][frame];
  const patch = 0xfffffcf1;
  const ink = 0xff392f2c;
  void pixels(int x, int y, int width, int height, int color) {
    image.fillRect(x, y + bob, width, height, color);
  }

  for (final eyeX in [22, 36]) {
    pixels(eyeX, 18, 7, 7, patch);
  }
  switch (mood) {
    case 'joyful':
    case 'calm':
      for (final eyeX in [23, 37]) {
        pixels(eyeX, 21, 5, 1, ink);
      }
    case 'thoughtful':
      pixels(24, 20, 3, 3, ink);
      pixels(38, 21, 2, 2, ink);
      pixels(37, 18, 4, 1, ink);
    case 'tired':
      pixels(23, 21, 5, 2, ink);
      pixels(37, 21, 5, 2, ink);
      pixels(23, 23, 5, 1, ink);
      pixels(37, 23, 5, 1, ink);
    case 'blue':
      pixels(24, 20, 3, 4, ink);
      pixels(38, 20, 3, 4, ink);
      pixels(37, 18, 4, 1, ink);
      pixels(40, 25, 2, 3, 0xff91cde0);
    case 'angry':
      pixels(22, 18, 2, 1, ink);
      pixels(23, 19, 3, 1, ink);
      pixels(25, 20, 3, 1, ink);
      pixels(42, 18, 2, 1, ink);
      pixels(40, 19, 3, 1, ink);
      pixels(37, 20, 3, 1, ink);
      pixels(24, 22, 3, 2, ink);
      pixels(38, 22, 3, 2, ink);
      pixels(46, 19, 2, 2, 0xffff9da7);
      pixels(48, 17, 1, 1, 0xffff9da7);
  }
  return image;
}

Raster _transitionCell(
  Raster source, {
  required double progress,
  required double outgoingDirection,
  required double incomingDirection,
}) {
  final cell = Raster(_previewCellWidth, _previewCellHeight);
  _fillPreviewCell(cell, 0, 0);
  final centerX = _previewCellWidth / 2;
  final centerY = _previewSpriteTop + frameSize / 2;
  _drawSprite(
    cell,
    source,
    centerX: centerX + outgoingDirection * frameSize * progress,
    centerY: centerY,
    opacity: 1 - progress,
  );
  _drawSprite(
    cell,
    source,
    centerX: centerX + incomingDirection * frameSize * (1 - progress),
    centerY: centerY,
    opacity: progress,
  );
  return cell;
}

Raster _makeKeyframesPreview(
  List<Raster> frontFrames,
  List<Raster> rearFrames,
) {
  const sectionsGap = 9;
  const headingHeight = 12;
  const cellGap = 3;
  const columns = 7;
  final front = frontFrames[0];
  final jumpCells = [
    _PreviewCell(_makePoseCell(front, scaleY: 0.92), '0'),
    _PreviewCell(
      _makePoseCell(front, dy: -25, scaleX: 0.946, scaleY: 1.09),
      '1',
    ),
    _PreviewCell(_makePoseCell(front, scaleX: 1.054, scaleY: 0.897), '2'),
  ];
  final moods = [
    'neutral',
    'joyful',
    'calm',
    'thoughtful',
    'tired',
    'blue',
    'angry',
  ];
  final sections = [
    _PreviewSection('IDLE 6', [
      for (var i = 0; i < frontFrames.length; i++)
        _PreviewCell(_makePoseCell(frontFrames[i]), '$i'),
    ]),
    _PreviewSection('BLINK 3', [
      _PreviewCell(_makePoseCell(frontFrames[0]), '0'),
      _PreviewCell(_makePoseCell(frontFrames[3]), '1'),
      _PreviewCell(_makePoseCell(frontFrames[0]), '2'),
    ]),
    _PreviewSection('JUMP 3', jumpCells),
    _PreviewSection('1 > 2', [
      for (final (index, progress) in [0.0, 0.5, 1.0].indexed)
        _PreviewCell(
          _transitionCell(
            front,
            progress: progress,
            outgoingDirection: 1,
            incomingDirection: -1,
          ),
          '$index',
        ),
    ]),
    _PreviewSection('2 > 1', [
      for (final (index, progress) in [0.0, 0.5, 1.0].indexed)
        _PreviewCell(
          _transitionCell(
            front,
            progress: progress,
            outgoingDirection: -1,
            incomingDirection: 1,
          ),
          '$index',
        ),
    ]),
    _PreviewSection('MOOD 7', [
      for (final (index, mood) in moods.indexed)
        _PreviewCell(_makePoseCell(_moodFrame(front, mood, 0)), '$index'),
    ]),
    _PreviewSection('REAR 4', [
      for (var i = 0; i < rearFrames.length; i++)
        _PreviewCell(_makePoseCell(rearFrames[i]), '$i'),
    ]),
  ];
  final width =
      columns * _previewCellWidth + (columns + 1) * cellGap + sectionsGap * 2;
  final height =
      sections.length * (headingHeight + _previewCellHeight + cellGap) +
      sectionsGap * 2;
  final preview = Raster(width, height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      preview.setPixel(x, y, 0xfffff2e2);
    }
  }
  _drawText(preview, 'KEY FRAMES', sectionsGap, 2, 0xff51443d);
  var top = sectionsGap + 10;
  for (final section in sections) {
    _drawText(preview, section.title, sectionsGap, top, 0xff51443d);
    final cellTop = top + headingHeight;
    for (var index = 0; index < section.cells.length; index++) {
      final cell = section.cells[index];
      final left =
          sectionsGap + cellGap + index * (_previewCellWidth + cellGap);
      for (var y = 0; y < _previewCellHeight; y++) {
        for (var x = 0; x < _previewCellWidth; x++) {
          preview.setPixel(left + x, cellTop + y, cell.image.getPixel(x, y));
        }
      }
      _drawText(
        preview,
        cell.label,
        left + _previewCellWidth ~/ 2 - 1,
        cellTop + _previewCellHeight - 7,
        0xff51443d,
      );
    }
    top += headingHeight + _previewCellHeight + cellGap;
  }
  return preview;
}

Future<void> main() async {
  final frontFrames = List.generate(
    6,
    (frame) => drawDuck(frame: frame, rear: false),
  );
  final rearFrames = List.generate(
    4,
    (frame) => drawDuck(frame: frame, rear: true),
  );
  final jacketFrontFrames = List.generate(
    6,
    (frame) => drawDuck(frame: frame, rear: false, jacket: true),
  );
  final jacketRearFrames = List.generate(
    4,
    (frame) => drawDuck(frame: frame, rear: true, jacket: true),
  );
  final heartPajamasFrontFrames = List.generate(
    6,
    (frame) => drawDuck(frame: frame, rear: false, heartPajamas: true),
  );
  final heartPajamasRearFrames = List.generate(
    4,
    (frame) => drawDuck(frame: frame, rear: true, heartPajamas: true),
  );
  final directory = Directory('assets/images');
  await directory.create(recursive: true);
  await File('${directory.path}/duck_front_sheet.png')
      .writeAsBytes(encodePng(composeSheet(frontFrames)));
  await File('${directory.path}/duck_rear_sheet.png')
      .writeAsBytes(encodePng(composeSheet(rearFrames)));
  await File('${directory.path}/duck_front_jacket_sheet.png')
      .writeAsBytes(encodePng(composeSheet(jacketFrontFrames)));
  await File('${directory.path}/duck_rear_jacket_sheet.png')
      .writeAsBytes(encodePng(composeSheet(jacketRearFrames)));
  await File('${directory.path}/duck_front_heart_pajamas_sheet.png')
      .writeAsBytes(encodePng(composeSheet(heartPajamasFrontFrames)));
  await File('${directory.path}/duck_rear_heart_pajamas_sheet.png')
      .writeAsBytes(encodePng(composeSheet(heartPajamasRearFrames)));
  final plainCharacterPreview = makeTransparentCharacterPreview(
    frontFrames.first,
    rearFrames.first,
  );
  await File('${directory.path}/duck_base_character_preview.png')
      .writeAsBytes(encodePng(plainCharacterPreview));
  final preview = enlarge(makePreview(frontFrames, rearFrames), 4);
  await File('${directory.path}/duck_sprite_preview.png')
      .writeAsBytes(encodePng(preview));
  final jacketCharacterPreview = makeTransparentCharacterPreview(
    jacketFrontFrames.first,
    jacketRearFrames.first,
  );
  await File('${directory.path}/duck_jacket_character_preview.png')
      .writeAsBytes(encodePng(jacketCharacterPreview));
  await File('${directory.path}/duck_front_jacket_character.png')
      .writeAsBytes(encodePng(enlarge(jacketFrontFrames.first, 4)));
  await File('${directory.path}/duck_rear_jacket_character.png')
      .writeAsBytes(encodePng(enlarge(jacketRearFrames.first, 4)));
  await File('${directory.path}/duck_heart_pajamas_character_preview.png')
      .writeAsBytes(
        encodePng(
          makeTransparentCharacterPreview(
            heartPajamasFrontFrames.first,
            heartPajamasRearFrames.first,
          ),
        ),
      );
  await File('${directory.path}/duck_front_base_character.png')
      .writeAsBytes(encodePng(enlarge(frontFrames.first, 4)));
  await File('${directory.path}/duck_rear_base_character.png')
      .writeAsBytes(encodePng(enlarge(rearFrames.first, 4)));
  final keyframes = enlarge(_makeKeyframesPreview(frontFrames, rearFrames), 2);
  await File('${directory.path}/duck_animation_keyframes.png')
      .writeAsBytes(encodePng(keyframes));
  final jacketKeyframes = enlarge(
    _makeKeyframesPreview(jacketFrontFrames, jacketRearFrames),
    2,
  );
  await File('${directory.path}/duck_jacket_animation_keyframes.png')
      .writeAsBytes(encodePng(jacketKeyframes));
  const productIds = [
    'crumbs',
    'watermelon',
    'worm',
    'pizza',
    'apple',
    'cheese',
    'carrot',
    'milk',
  ];
  final productDirectory = Directory('${directory.path}/grocery_products');
  await productDirectory.create(recursive: true);
  for (final id in productIds) {
    await File('${productDirectory.path}/$id.png')
        .writeAsBytes(encodePng(_makeDetailedGroceryProduct(id)));
  }
  final productsSheet = _makeGroceryProductSheet(productIds);
  await File('${directory.path}/grocery_products_sheet.png')
      .writeAsBytes(encodePng(productsSheet));
  final priceTag = enlarge(_makeProductPriceTag(), 3);
  await File('${directory.path}/grocery_price_tag_blank.png')
      .writeAsBytes(encodePng(priceTag));

  final marketScene = _makePixelMarketScene(productIds);
  await File('${directory.path}/grocery_market_scene.png')
      .writeAsBytes(encodePng(enlarge(marketScene, 3)));
  await File('${directory.path}/grocery_aisle_scene.png')
      .writeAsBytes(encodePng(enlarge(marketScene, 3)));
  final checkoutScene = _makePixelCheckoutScene();
  await File('${directory.path}/grocery_checkout_scene.png')
      .writeAsBytes(encodePng(enlarge(checkoutScene, 3)));
  await File('${directory.path}/grocery_cashier_scene.png')
      .writeAsBytes(encodePng(enlarge(checkoutScene, 3)));
  final cashierFrames = List.generate(6, _makeCashierDuck, growable: false);
  final cashierSheet = _makeFrameStrip(cashierFrames);
  await File('${directory.path}/duck_cashier_front_sheet.png')
      .writeAsBytes(encodePng(cashierSheet));
  await File('${directory.path}/grocery_cashier_duck.png')
      .writeAsBytes(encodePng(cashierFrames.first));
  await File('${directory.path}/duck_cashier_front_preview.png')
      .writeAsBytes(encodePng(enlarge(cashierFrames.first, 4)));
  final checkoutPreview = _makeCheckoutPreview(
    checkoutScene,
    cashierFrames.first,
  );
  await File('${directory.path}/grocery_checkout_preview.png')
      .writeAsBytes(encodePng(checkoutPreview));
  final marketPreview = enlarge(marketScene, 3);
  await File(
    '${directory.path}/grocery_scenes_preview.png',
  ).writeAsBytes(encodePng(_joinScenePreviews(marketPreview, checkoutPreview)));
  stdout.writeln(
    'Wrote front ${frameSize * frontFrames.length}x$frameSize, '
    'rear ${frameSize * rearFrames.length}x$frameSize, '
    'jacket front ${frameSize * jacketFrontFrames.length}x$frameSize, '
    'jacket rear ${frameSize * jacketRearFrames.length}x$frameSize, '
    'preview ${preview.width}x${preview.height}, '
    'keyframes ${keyframes.width}x${keyframes.height}, '
    'product icons ${productIds.length} at 64x64, '
    'product sheet ${productsSheet.width}x${productsSheet.height}, '
    'market scene ${marketPreview.width}x${marketPreview.height}, '
    'checkout cashier sheet ${cashierSheet.width}x${cashierSheet.height}, '
    'jacket preview ${jacketCharacterPreview.width}x'
    '${jacketCharacterPreview.height}, '
    'jacket keyframes ${jacketKeyframes.width}x${jacketKeyframes.height}',
  );
}
