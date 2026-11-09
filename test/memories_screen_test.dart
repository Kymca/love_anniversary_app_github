import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:love_anniversary_app/models/memory_media.dart';
import 'package:love_anniversary_app/screens/memories_screen.dart';
import 'package:love_anniversary_app/services/memory_media_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_app.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'copies selected files and restores metadata after recreation',
    () async {
      final root = await Directory.systemTemp.createTemp('memory-media-test');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}${Platform.pathSeparator}photo.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);
      final preferences = await SharedPreferences.getInstance();
      final service = MemoryMediaService(
        preferences: preferences,
        directoryProvider: () async => root,
        clock: () => DateTime(2026, 11, 4, 12),
      );

      final saved = await service.addFile(
        sourcePath: source.path,
        type: MemoryMediaType.photo,
        caption: '  Наш вечер  ',
      );
      final restored = await MemoryMediaService(
        preferences: preferences,
        directoryProvider: () async => root,
      ).load();

      expect(restored, hasLength(1));
      expect(restored.single.id, saved.id);
      expect(restored.single.type, MemoryMediaType.photo);
      expect(restored.single.caption, 'Наш вечер');
      expect(restored.single.timestamp, DateTime(2026, 11, 4, 12));
      expect(restored.single.filePath, isNot(source.path));
      expect(await File(restored.single.filePath).readAsBytes(), [1, 2, 3, 4]);
    },
  );

  testWidgets('gallery selection opens the photo picker', (tester) async {
    final picker = _FakePicker(photo: XFile('synthetic.jpg'));
    final service = _FakeMemoryMediaService();
    await tester.pumpWidget(
      localizedTestApp(
        home: MemoriesScreen(service: service, picker: picker),
      ),
    );
    await _pumpTransition(tester);
    expect(find.text('Добавить\nвоспоминание'), findsOneWidget);
    await tester.tap(find.text('Добавить\nвоспоминание'));
    await _pumpTransition(tester);
    expect(find.text('Выбрать фотографию'), findsOneWidget);
    await tester.tap(find.text('Выбрать фотографию'));
    await _pumpTransition(tester);
    await tester.enterText(find.byType(TextField), 'Наш вечер');
    await tester.tap(find.text('Сохранить'));
    await _pumpTransition(tester);

    expect(picker.photoPickCount, 1);
    expect(service.items, hasLength(1));
    expect(service.items.single.caption, 'Наш вечер');
    expect(find.text('Наш вечер'), findsOneWidget);
    expect(service.items.single.type, MemoryMediaType.photo);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a photo shows zoomable full-screen caption viewer', (
    tester,
  ) async {
    final service = MemoryMediaService(
      preferences: await SharedPreferences.getInstance(),
    );
    await service.addAsset(
      assetPath: 'synthetic-missing-photo.jpg',
      type: MemoryMediaType.photo,
      caption: 'Синтетическое воспоминание',
    );

    await tester.pumpWidget(
      localizedTestApp(
        home: MemoriesScreen(service: service, picker: _FakePicker()),
      ),
    );
    await _pumpTransition(tester);
    await tester.tap(find.text('Синтетическое воспоминание'));
    await _pumpTransition(tester);

    expect(find.byType(MemoryMediaViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MemoryMediaViewer),
        matching: find.text('Синтетическое воспоминание'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MemoryMediaViewer), findsNothing);
  });

  testWidgets('gallery can select video and render a saved video tile', (
    tester,
  ) async {
    final picker = _FakePicker();
    final service = _FakeMemoryMediaService(
      initialItems: [
        MemoryMedia(
          id: 'existing-video',
          type: MemoryMediaType.video,
          filePath: 'missing-synthetic-video.mp4',
          caption: 'Первое путешествие',
          timestamp: DateTime(2026, 11, 4),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedTestApp(
        home: MemoriesScreen(service: service, picker: picker),
      ),
    );
    await _pumpTransition(tester);
    await tester.tap(find.text('Добавить\nвоспоминание'));
    await _pumpTransition(tester);
    await tester.tap(find.text('Выбрать видео'));
    await _pumpTransition(tester);

    expect(picker.videoPickCount, 1);
    expect(find.text('Первое путешествие'), findsOneWidget);
    expect(service.items.single.type, MemoryMediaType.video);
    expect(tester.takeException(), isNull);
  });
}

class _FakePicker implements MemoryMediaPicker {
  _FakePicker({this.photo});

  final XFile? photo;

  int photoPickCount = 0;
  int videoPickCount = 0;

  @override
  Future<XFile?> pickPhoto() async {
    photoPickCount++;
    return photo;
  }

  @override
  Future<XFile?> pickVideo() async {
    videoPickCount++;
    return null;
  }
}

class _FakeMemoryMediaService extends MemoryMediaService {
  _FakeMemoryMediaService({List<MemoryMedia> initialItems = const []}) {
    items.addAll(initialItems);
  }

  final List<MemoryMedia> items = [];

  @override
  Future<List<MemoryMedia>> load() async => List.unmodifiable(items);

  @override
  Future<MemoryMedia> addFile({
    required String sourcePath,
    required MemoryMediaType type,
    required String caption,
  }) async {
    final media = MemoryMedia(
      id: 'synthetic-${items.length}',
      type: type,
      filePath: sourcePath,
      caption: caption.trim(),
      timestamp: DateTime(2026, 11, 4),
    );
    items.add(media);
    return media;
  }
}

Future<void> _pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
