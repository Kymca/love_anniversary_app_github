import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final assetDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}images${Platform.pathSeparator}mood_envelopes',
  );
  final moods = ['joyful', 'calm', 'thoughtful', 'tired', 'blue', 'angry'];

  test('manifest defines six mood overlays and exact 30 FPS timing', () {
    final manifest = jsonDecode(
      File('${assetDirectory.path}${Platform.pathSeparator}manifest.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['frameRate'], 30);
    expect(manifest['frameCount'], 18);
    expect(manifest['frameDurationMs'], closeTo(1000 / 30, 0.000001));
    expect(manifest['durationMs'], 600);
    expect(manifest['closedFrameIndex'], 0);
    expect(manifest['closedFrames'], [0, 1, 2, 3]);
    expect(manifest['moodOverlayStartFrame'], 8);
    expect(manifest['moodOverlayBounds'], {
      'x': 20,
      'y': 5,
      'width': 24,
      'height': 24,
    });
    expect(
      manifest['moodOverlaySizing'],
      'scale 64x64 frame to bounds using nearest neighbor',
    );
    expect(
      (manifest['moods'] as Map<String, dynamic>).keys.toSet(),
      moods.toSet(),
    );
    for (final mood in moods) {
      final loop =
          ((manifest['moods'] as Map<String, dynamic>)[mood]
                  as Map<String, dynamic>)['loop']
              as Map<String, dynamic>;
      expect(loop['file'], '${mood}_loop.png');
      expect(loop['frameRate'], 30);
      expect(loop['frameCount'], 60);
      expect(loop['frameDurationMs'], closeTo(1000 / 30, 0.000001));
      expect(loop['durationMs'], 2000);
      expect(loop['looping'], isTrue);
      expect(loop['frameSize'], {'width': 64, 'height': 64});
      expect(loop['layout'], 'horizontal');
      expect(loop['filterQuality'], 'none');
    }
  });

  test(
    'sprites have expected dimensions, transparent pixels, and closed frame',
    () {
      final envelope = _decodePng(
        File('${assetDirectory.path}${Platform.pathSeparator}envelope.png')
            .readAsBytesSync(),
      );
      expect(envelope.width, 64);
      expect(envelope.height, 64);
      expect(envelope.hasTransparentPixels, isTrue);
      expect(envelope.hasOpaquePixels, isTrue);

      for (final mood in moods) {
        final face = _decodePng(
          File('${assetDirectory.path}${Platform.pathSeparator}$mood.png')
              .readAsBytesSync(),
        );
        expect(face.width, 64, reason: '$mood face width');
        expect(face.height, 64, reason: '$mood face height');
        expect(face.hasTransparentPixels, isTrue, reason: '$mood transparency');
        expect(face.hasOpaquePixels, isTrue, reason: '$mood opaque pixels');
        expect(face.hasIntermediateAlpha, isFalse, reason: '$mood pixel edges');

        final loop = _decodePng(
          File(
            '${assetDirectory.path}${Platform.pathSeparator}${mood}_loop.png',
          ).readAsBytesSync(),
        );
        expect(loop.width, 64 * 60, reason: '$mood loop width');
        expect(loop.height, 64, reason: '$mood loop height');
        expect(loop.hasTransparentPixels, isTrue, reason: '$mood loop alpha');
        expect(
          loop.hasIntermediateAlpha,
          isFalse,
          reason: '$mood loop pixel edges',
        );
        expect(
          loop.frameEquals(0, 59),
          isTrue,
          reason: '$mood animation should loop seamlessly',
        );
        expect(
          loop.frameEquals(0, 29),
          isFalse,
          reason: '$mood animation should include a blink',
        );
      }

      final sheet = _decodePng(
        File(
          '${assetDirectory.path}${Platform.pathSeparator}'
          'envelope_opening_sheet.png',
        ).readAsBytesSync(),
      );
      expect(sheet.width, 64 * 18);
      expect(sheet.height, 64);
      expect(sheet.hasTransparentPixels, isTrue);
      expect(sheet.hasIntermediateAlpha, isFalse);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          expect(
            sheet.pixel(x, y),
            envelope.pixel(x, y),
            reason: 'Opening sheet frame 0 must be the closed envelope.',
          );
        }
      }
      for (var frame = 1; frame <= 3; frame++) {
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            expect(
              sheet.pixel(frame * 64 + x, y),
              envelope.pixel(x, y),
              reason: 'Frame $frame should hold the closed envelope.',
            );
          }
        }
      }
    },
  );
}

class _DecodedPng {
  const _DecodedPng(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  int pixel(int x, int y) {
    final offset = (y * width + x) * 4;
    return (rgba[offset] << 24) |
        (rgba[offset + 1] << 16) |
        (rgba[offset + 2] << 8) |
        rgba[offset + 3];
  }

  bool get hasTransparentPixels => _containsAlpha(0);
  bool get hasOpaquePixels => _containsAlpha(255);
  bool get hasIntermediateAlpha => List.generate(
    width * height,
    (index) => rgba[index * 4 + 3],
  ).any((alpha) => alpha != 0 && alpha != 255);

  bool frameEquals(int firstFrame, int secondFrame) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < 64; x++) {
        if (pixel(firstFrame * 64 + x, y) != pixel(secondFrame * 64 + x, y)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _containsAlpha(int alpha) => List.generate(
    width * height,
    (index) => rgba[index * 4 + 3],
  ).contains(alpha);
}

_DecodedPng _decodePng(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  var width = 0;
  var height = 0;
  var offset = 8;
  final compressed = BytesBuilder();
  while (offset + 12 <= bytes.length) {
    final length = view.getUint32(offset, Endian.big);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    final dataStart = offset + 8;
    final dataEnd = dataStart + length;
    if (type == 'IHDR') {
      width = view.getUint32(dataStart, Endian.big);
      height = view.getUint32(dataStart + 4, Endian.big);
      expect(bytes[dataStart + 9], 6, reason: 'PNG must use RGBA color.');
    } else if (type == 'IDAT') {
      compressed.add(bytes.sublist(dataStart, dataEnd));
    }
    offset = dataEnd + 4;
    if (type == 'IEND') break;
  }
  expect(width, greaterThan(0));
  expect(height, greaterThan(0));

  final filtered = Uint8List.fromList(
    ZLibDecoder().convert(compressed.takeBytes()),
  );
  final rgba = Uint8List(width * height * 4);
  final rowLength = width * 4 + 1;
  for (var y = 0; y < height; y++) {
    final rowStart = y * rowLength;
    expect(filtered[rowStart], 0, reason: 'Expected unfiltered PNG rows.');
    rgba.setRange(y * width * 4, (y + 1) * width * 4, filtered, rowStart + 1);
  }
  return _DecodedPng(width, height, rgba);
}
