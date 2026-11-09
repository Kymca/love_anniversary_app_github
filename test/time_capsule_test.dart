import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:love_anniversary_app/models/time_capsule.dart';
import 'package:love_anniversary_app/services/memory_media_service.dart';
import 'package:love_anniversary_app/services/time_capsule_repository.dart';
import 'package:love_anniversary_app/widgets/time_capsule_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'text capsule persists and rejects dates that are not in the future',
    () async {
      final now = DateTime(2026, 11, 6, 15, 30);
      final preferences = await SharedPreferences.getInstance();
      final repository = TimeCapsuleRepository(
        preferences: preferences,
        mediaService: MemoryMediaService(preferences: preferences),
        clock: () => now,
      );

      final saved = await repository.createText(
        note: '  Прочитать в отпуске  ',
        unlockDate: DateTime(2026, 12, 31, 23, 59),
      );
      final restored = await TimeCapsuleRepository(
        preferences: preferences,
        mediaService: MemoryMediaService(preferences: preferences),
        clock: () => now,
      ).load();

      expect(restored, hasLength(1));
      expect(restored.single.id, saved.id);
      expect(restored.single.note, 'Прочитать в отпуске');
      expect(restored.single.unlockDate, DateTime(2026, 12, 31));
      await expectLater(
        repository.createText(
          note: 'Too soon',
          unlockDate: DateTime(2026, 11, 6),
        ),
        throwsArgumentError,
      );
    },
  );

  test('photo capsule is copied to app storage and restored', () async {
    final root = await Directory.systemTemp.createTemp('time-capsule-test');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}${Platform.pathSeparator}synthetic.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final preferences = await SharedPreferences.getInstance();
    final mediaService = MemoryMediaService(
      preferences: preferences,
      directoryProvider: () async => root,
      clock: () => DateTime(2026, 11, 6),
    );
    final repository = TimeCapsuleRepository(
      preferences: preferences,
      mediaService: mediaService,
      clock: () => DateTime(2026, 11, 6),
    );

    final saved = await repository.createPhoto(
      sourcePath: source.path,
      unlockDate: DateTime(2027, 1, 1),
      note: 'С новым годом',
    );
    final restored = await repository.load();

    expect(restored, hasLength(1));
    expect(restored.single.photoPath, saved.photoPath);
    expect(saved.photoPath, contains('time_capsules'));
    expect(saved.hasContent, isTrue);
    expect(await File(saved.photoPath!).readAsBytes(), [1, 2, 3, 4]);
  });

  test(
    'capsule stays locked before date and unlocks on that calendar date',
    () {
      final capsule = TimeCapsule(
        id: 'synthetic',
        note: 'Private synthetic note',
        unlockDate: DateTime(2026, 11, 7),
        createdAt: DateTime(2026, 11, 6),
      );

      expect(capsule.isUnlockedAt(DateTime(2026, 11, 6, 23, 59)), isFalse);
      expect(capsule.isUnlockedAt(DateTime(2026, 11, 7)), isTrue);
      expect(capsule.isUnlockedAt(DateTime(2026, 11, 7, 0, 1)), isTrue);
    },
  );

  testWidgets('locked note is hidden and shown at unlock date', (tester) async {
    final now = ValueNotifier(DateTime(2026, 11, 6, 10));
    addTearDown(now.dispose);
    final preferences = await SharedPreferences.getInstance();
    final repository = TimeCapsuleRepository(
      preferences: preferences,
      mediaService: MemoryMediaService(preferences: preferences),
      clock: () => now.value,
    );
    await repository.createText(
      note: 'Future synthetic message',
      unlockDate: DateTime(2026, 11, 7),
    );

    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: TimeCapsuleWidget(
            repository: repository,
            picker: _UnusedPhotoPicker(),
            clock: () => now.value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Капсула запечатана'), findsOneWidget);
    expect(find.text('Future synthetic message'), findsNothing);

    now.value = DateTime(2026, 11, 7);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Капсула открыта'), findsOneWidget);
    await tester.tap(find.text('Капсула открыта'));
    await tester.pumpAndSettle();
    expect(find.text('Future synthetic message'), findsOneWidget);
  });
}

class _UnusedPhotoPicker implements TimeCapsulePhotoPicker {
  @override
  Future<XFile?> pickPhoto() async => null;
}
