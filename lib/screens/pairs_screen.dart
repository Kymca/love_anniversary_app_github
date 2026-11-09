import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pair_room.dart';
import '../services/pair_repository.dart';
import '../services/participant_profile_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

class PairsScreen extends StatefulWidget {
  const PairsScreen({
    super.key,
    this.repository,
    this.profileRepository,
    this.onPairUpdated,
  });

  final PairRepository? repository;
  final ParticipantProfileRepository? profileRepository;
  final VoidCallback? onPairUpdated;

  @override
  State<PairsScreen> createState() => _PairsScreenState();
}

class _PairsScreenState extends State<PairsScreen> {
  late final PairRepository _repository =
      widget.repository ?? SharedPreferencesPairRepository();
  late final ParticipantProfileRepository _profileRepository =
      widget.profileRepository ?? ParticipantProfileRepository();
  final _codeController = TextEditingController();
  PairRoom? _room;
  String? _participantName;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadParticipantName();
  }

  Future<void> _loadParticipantName() async {
    final names = await _profileRepository.loadNames();
    if (mounted) setState(() => _participantName = names['first']);
  }

  Future<void> _createPair() async {
    final name = _participantName;
    if (name == null) {
      setState(
        () => _error = AppLocalizations.of(context)!.pairNameSetupRequired,
      );
      return;
    }
    await _run(() => _repository.createPair(name));
  }

  Future<void> _joinPair() async {
    final code = _codeController.text.trim();
    final names = await _profileRepository.loadNames();
    final localRoom = await _repository.findPair(code);
    final joiningSide = localRoom != null && localRoom.members.length == 1
        ? 'second'
        : 'first';
    final name = names[joiningSide] ?? _participantName;
    if (name == null) {
      setState(
        () => _error = AppLocalizations.of(context)!.pairNameSetupRequired,
      );
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _error = AppLocalizations.of(context)!.invalidPairCode);
      return;
    }
    await _run(() => _repository.joinPair(name, code));
  }

  Future<void> _run(Future<PairRoom> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final room = await action();
      if (!mounted) return;
      setState(() => _room = room);
      widget.onPairUpdated?.call();
      if (room.members.length == 1) _showShareCode(room.code);
    } on PairRepositoryException catch (error) {
      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        setState(
          () => _error = switch (error.message) {
            'Введите своё имя.' => strings.enterYourName,
            'Имя должно быть короче 40 символов.' => strings.nameTooLong,
            'Введите код пары из четырёх цифр.' => strings.invalidPairCode,
            'Пара с таким кодом не найдена на этом устройстве.' =>
              strings.pairNotFound,
            'В этой паре уже два участника.' => strings.pairFull,
            _ => error.message,
          },
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!
                  .pairCreateError(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showShareCode(String code) => showDialog<void>(
    context: context,
    builder: (context) {
      final strings = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(strings.pairCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.pairCodePrompt),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.roseDeep,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(strings.copy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.done),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final room = _room;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              strings.pairsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              strings.pairSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              strings.pairLocalNotice,
              style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _participantName ?? strings.pairNameSetupRequired,
                    key: const ValueKey('pair-participant-name'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _isBusy || _participantName == null
                        ? null
                        : _createPair,
                    icon: const Icon(Icons.favorite_rounded),
                    label: Text(strings.createPair),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.pairCode,
                      hintText: '1234',
                      prefixIcon: Icon(Icons.dialpad_rounded),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy || _participantName == null
                        ? null
                        : _joinPair,
                    icon: const Icon(Icons.link_rounded),
                    label: Text(strings.joinPair),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (room != null) ...[
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yourPair,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final member in room.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.rose,
                        ),
                        title: Text(member.name),
                      ),
                    if (room.members.length == 1)
                      Text(
                        strings.waitingForPartner,
                        style: TextStyle(color: AppColors.mutedInk),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
