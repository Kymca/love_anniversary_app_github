import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/memory_media.dart';
import '../services/memory_media_service.dart';
import '../theme/app_theme.dart';

abstract interface class MemoryMediaPicker {
  Future<XFile?> pickPhoto();
  Future<XFile?> pickVideo();
}

class ImagePickerMemoryMediaPicker implements MemoryMediaPicker {
  ImagePickerMemoryMediaPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickPhoto() => _picker.pickImage(source: ImageSource.gallery);

  @override
  Future<XFile?> pickVideo() => _picker.pickVideo(source: ImageSource.gallery);
}

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key, this.service, this.picker});

  final MemoryMediaService? service;
  final MemoryMediaPicker? picker;

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  late final MemoryMediaService _service =
      widget.service ?? MemoryMediaService();
  late final MemoryMediaPicker _picker =
      widget.picker ?? ImagePickerMemoryMediaPicker();
  late Future<List<MemoryMedia>> _memoriesFuture = _service.load();
  bool _isAdding = false;

  Future<void> _addMemory() async {
    if (_isAdding) return;
    final strings = AppLocalizations.of(context)!;
    final type = await showModalBottomSheet<MemoryMediaType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.addMemory,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.photo_rounded,
                    color: AppColors.rose,
                  ),
                  title: Text(strings.pickPhoto),
                  onTap: () => Navigator.pop(context, MemoryMediaType.photo),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.videocam_rounded,
                    color: AppColors.rose,
                  ),
                  title: Text(strings.pickVideo),
                  onTap: () => Navigator.pop(context, MemoryMediaType.video),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;

    setState(() => _isAdding = true);
    try {
      final file = type == MemoryMediaType.photo
          ? await _picker.pickPhoto()
          : await _picker.pickVideo();
      if (file == null || !mounted) return;
      final caption = await _askCaption();
      if (caption == null || !mounted) return;
      await _service.addFile(
        sourcePath: file.path,
        type: type,
        caption: caption,
      );
      if (!mounted) return;
      setState(() => _memoriesFuture = _service.load());
    } catch (error) {
      if (mounted) {
        _showMessage(
          strings.saveMemoryError(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<String?> _askCaption() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _MemoryCaptionDialog(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.memoriesTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.memoriesSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<MemoryMedia>>(
              future: _memoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(strings.loadMemoriesError),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data!;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  sliver: SliverGrid.builder(
                    itemCount: items.length + 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.84,
                        ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _AddMemoryTile(
                          isLoading: _isAdding,
                          onTap: _addMemory,
                        );
                      }
                      final item = items[index - 1];
                      return _MemoryTile(
                        item: item,
                        onTap: () => _openViewer(item),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openViewer(MemoryMedia item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => MemoryMediaViewer(item: item)),
    );
  }
}

class _MemoryCaptionDialog extends StatefulWidget {
  const _MemoryCaptionDialog();

  @override
  State<_MemoryCaptionDialog> createState() => _MemoryCaptionDialogState();
}

class _MemoryCaptionDialogState extends State<_MemoryCaptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.captionTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: strings.captionHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(strings.skip),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(strings.save),
        ),
      ],
    );
  }
}

class _AddMemoryTile extends StatelessWidget {
  const _AddMemoryTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 24,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: AppColors.rose,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.addMemory.replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.roseDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.item, required this.onTap});

  final MemoryMedia item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final image = item.type == MemoryMediaType.photo
        ? _memoryImage(item.filePath)
        : null;
    return Semantics(
      button: true,
      label: item.caption.isEmpty
          ? item.type == MemoryMediaType.photo
                ? strings.openPhoto
                : strings.openVideo
          : strings.openMemoryCaption(item.caption),
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 24,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image != null)
                        image
                      else
                        Container(
                          color: AppColors.lavender.withValues(alpha: 0.65),
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.rose,
                            size: 48,
                          ),
                        ),
                      if (item.type == MemoryMediaType.video)
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 44,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 10),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                child: Text(
                  item.caption.isEmpty
                      ? strings.memoryCaptionMissing
                      : item.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _memoryImage(String path) {
  final error = Container(
    color: AppColors.peach.withValues(alpha: 0.7),
    child: const Center(
      child: Icon(Icons.image_not_supported_rounded, color: AppColors.mutedInk),
    ),
  );
  if (path.startsWith('asset:')) {
    return Image.asset(
      path.substring('asset:'.length),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => error,
    );
  }
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => error,
  );
}

class MemoryMediaViewer extends StatefulWidget {
  const MemoryMediaViewer({super.key, required this.item});

  final MemoryMedia item;

  @override
  State<MemoryMediaViewer> createState() => _MemoryMediaViewerState();
}

class _MemoryMediaViewerState extends State<MemoryMediaViewer> {
  VideoPlayerController? _videoController;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == MemoryMediaType.video) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final path = widget.item.filePath;
    final controller = path.startsWith('asset:')
        ? VideoPlayerController.asset(path.substring('asset:'.length))
        : VideoPlayerController.file(File(path));
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final item = widget.item;
    return Scaffold(
      backgroundColor: const Color(0xFF17131A),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _viewerContent(item)),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: strings.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (item.caption.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    child: Text(
                      item.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewerContent(MemoryMedia item) {
    final strings = AppLocalizations.of(context)!;
    if (item.type == MemoryMediaType.photo) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: _memoryImage(item.filePath),
        ),
      );
    }
    if (_videoFailed) {
      return Center(
        child: Text(
          strings.videoUnavailable,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
