import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/time_capsule.dart';
import '../services/memory_media_service.dart';
import '../services/time_capsule_repository.dart';
import '../theme/app_theme.dart';

abstract interface class TimeCapsulePhotoPicker {
  Future<XFile?> pickPhoto();
}

class ImagePickerTimeCapsulePhotoPicker implements TimeCapsulePhotoPicker {
  ImagePickerTimeCapsulePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickPhoto() => _picker.pickImage(source: ImageSource.gallery);
}

class TimeCapsuleWidget extends StatefulWidget {
  const TimeCapsuleWidget({
    super.key,
    this.repository,
    this.picker,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final TimeCapsuleRepository? repository;
  final TimeCapsulePhotoPicker? picker;
  final DateTime Function() clock;

  @override
  State<TimeCapsuleWidget> createState() => _TimeCapsuleWidgetState();
}

class _TimeCapsuleWidgetState extends State<TimeCapsuleWidget> {
  late final TimeCapsuleRepository _repository =
      widget.repository ??
      TimeCapsuleRepository(mediaService: MemoryMediaService());
  late final TimeCapsulePhotoPicker _picker =
      widget.picker ?? ImagePickerTimeCapsulePhotoPicker();
  late Future<List<TimeCapsule>> _capsulesFuture = _repository.load();
  late DateTime _now = widget.clock();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = widget.clock());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _addCapsule() async {
    final result = await showDialog<_NewCapsule>(
      context: context,
      builder: (context) =>
          _NewTimeCapsuleDialog(picker: _picker, now: widget.clock()),
    );
    if (result == null || !mounted) return;
    try {
      if (result.photoPath == null) {
        await _repository.createText(
          note: result.note,
          unlockDate: result.unlockDate,
        );
      } else {
        await _repository.createPhoto(
          sourcePath: result.photoPath!,
          unlockDate: result.unlockDate,
          note: result.note,
        );
      }
      if (mounted) setState(() => _capsulesFuture = _repository.load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.createCapsuleError(error.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded, color: AppColors.rose),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.timeCapsuleTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.timeCapsuleSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: strings.createTimeCapsule,
                onPressed: _addCapsule,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TimeCapsule>>(
          future: _capsulesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CapsuleMessage(strings.timeCapsuleLoadError);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return _CapsuleMessage(strings.timeCapsuleEmpty);
            }
            return Column(
              children: [
                for (final capsule in snapshot.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TimeCapsuleTile(
                      capsule: capsule,
                      now: _now,
                      onTap: () => _openCapsule(capsule),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openCapsule(TimeCapsule capsule) async {
    if (!capsule.isUnlockedAt(widget.clock())) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _UnlockedCapsuleDialog(capsule: capsule),
    );
  }
}

class _CapsuleMessage extends StatelessWidget {
  const _CapsuleMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class _TimeCapsuleTile extends StatelessWidget {
  const _TimeCapsuleTile({
    required this.capsule,
    required this.now,
    required this.onTap,
  });

  final TimeCapsule capsule;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final unlocked = capsule.isUnlockedAt(now);
    final date = MaterialLocalizations.of(context).formatMediumDate(
      DateTime(
        capsule.unlockDate.year,
        capsule.unlockDate.month,
        capsule.unlockDate.day,
      ),
    );
    return Semantics(
      button: unlocked,
      label: unlocked
          ? strings.openCapsuleFrom(date)
          : strings.sealedUntil(date),
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: InkWell(
          onTap: unlocked ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  unlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  color: unlocked ? AppColors.teal : AppColors.rose,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unlocked ? strings.capsuleOpened : strings.capsuleSealed,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        unlocked
                            ? strings.timeCapsuleOpen
                            : strings.timeCapsuleOpensOn(date),
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unlocked) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedCapsuleDialog extends StatelessWidget {
  const _UnlockedCapsuleDialog({required this.capsule});

  final TimeCapsule capsule;

  @override
  Widget build(BuildContext context) {
    final photoPath = capsule.photoPath;
    final strings = AppLocalizations.of(context)!;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_open_rounded,
                size: 32,
                color: AppColors.teal,
              ),
              const SizedBox(height: 12),
              if (capsule.note?.isNotEmpty ?? false)
                Text(
                  capsule.note!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (photoPath != null) ...[
                if (capsule.note?.isNotEmpty ?? false)
                  const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(photoPath),
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _UnavailablePhoto(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailablePhoto extends StatelessWidget {
  const _UnavailablePhoto();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(
      child: Text(
        AppLocalizations.of(context)!.photoUnavailable,
        style: const TextStyle(color: AppColors.mutedInk),
      ),
    ),
  );
}

class _NewCapsule {
  const _NewCapsule({
    required this.note,
    required this.unlockDate,
    this.photoPath,
  });

  final String note;
  final DateTime unlockDate;
  final String? photoPath;
}

class _NewTimeCapsuleDialog extends StatefulWidget {
  const _NewTimeCapsuleDialog({required this.picker, required this.now});

  final TimeCapsulePhotoPicker picker;
  final DateTime now;

  @override
  State<_NewTimeCapsuleDialog> createState() => _NewTimeCapsuleDialogState();
}

class _NewTimeCapsuleDialogState extends State<_NewTimeCapsuleDialog> {
  final _noteController = TextEditingController();
  late DateTime _unlockDate = DateTime(
    widget.now.year,
    widget.now.month,
    widget.now.day + 1,
  );
  String? _photoPath;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _unlockDate,
      firstDate: DateTime(
        widget.now.year,
        widget.now.month,
        widget.now.day + 1,
      ),
      lastDate: DateTime(widget.now.year + 100),
    );
    if (date != null) setState(() => _unlockDate = date);
  }

  Future<void> _choosePhoto() async {
    final strings = AppLocalizations.of(context)!;
    try {
      final photo = await widget.picker.pickPhoto();
      if (photo != null && mounted) setState(() => _photoPath = photo.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.choosePhotoError(error.toString()))),
        );
      }
    }
  }

  void _submit() {
    final strings = AppLocalizations.of(context)!;
    final note = _noteController.text.trim();
    if (note.isEmpty && _photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.capsuleNeedsContent)),
      );
      return;
    }
    Navigator.pop(
      context,
      _NewCapsule(note: note, unlockDate: _unlockDate, photoPath: _photoPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(_unlockDate);
    return AlertDialog(
      title: Text(strings.newTimeCapsule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _noteController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: strings.timeCapsuleNoteHint,
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _choosePhoto,
                icon: const Icon(Icons.photo_outlined),
                label: Text(
                  _photoPath == null ? strings.attachPhoto : strings.photoSelected,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(strings.openOnDate(date)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.sealCapsule)),
      ],
    );
  }
}
