import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pair_room.dart';
import '../services/pair_repository.dart';
import '../services/participant_profile_repository.dart';
import '../services/supabase_backend.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

class PairsScreen extends StatefulWidget {
  const PairsScreen({
    super.key,
    this.repository,
    this.profileRepository,
    this.profileRevision = 0,
    this.onPairUpdated,
  });

  final PairRepository? repository;
  final ParticipantProfileRepository? profileRepository;
  final int profileRevision;
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
  final _participantNameController = TextEditingController();
  PairRoom? _room;
  String? _participantName;
  bool _hasEditedParticipantName = false;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _participantNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadParticipantName();
    _loadActivePair();
  }

  @override
  void didUpdateWidget(covariant PairsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileRevision != oldWidget.profileRevision) {
      _loadParticipantName();
    }
  }

  Future<void> _loadParticipantName() async {
    final names = await _profileRepository.loadNames();
    if (!mounted) return;
    setState(() {
      _participantName = names['first'];
      if (!_hasEditedParticipantName) {
        _participantNameController.text = names['first'] ?? '';
      }
    });
  }

  Future<void> _loadActivePair() async {
    try {
      final room = await _repository.loadActivePair();
      if (mounted && room != null) setState(() => _room = room);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = _pairErrorMessage(AppLocalizations.of(context)!, error),
        );
      }
    }
  }

  Future<void> _createPair() async {
    final name = _participantNameController.text.trim();
    if (name.isEmpty) {
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
    final name = _hasEditedParticipantName
        ? _participantNameController.text.trim()
        : names['second'] ?? names['first'] ?? _participantName;
    if (name == null || name.trim().isEmpty) {
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
      final participantSide = room.members.length == 1 ? 'first' : 'second';
      await _profileRepository.saveCurrentSide(participantSide);
      await _profileRepository.saveName(
        participantSide,
        room.members[participantSide == 'first' ? 0 : 1].name,
      );
      if (!mounted) return;
      setState(() {
        _room = room;
        _participantName =
            room.members[participantSide == 'first' ? 0 : 1].name;
        _participantNameController.text = _participantName!;
      });
      widget.onPairUpdated?.call();
      if (room.members.length == 1) _showShareCode(room.code);
    } on PairRepositoryException catch (error) {
      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        setState(
          () => _error = switch (error.message) {
            'pair_backend_migration_required' =>
              strings.pairBackendUpdateRequired,
            'not_authenticated' => strings.pairAuthUnavailable,
            'Введите своё имя.' => strings.enterYourName,
            'Имя должно быть короче 40 символов.' => strings.nameTooLong,
            'Введите код пары из четырёх цифр.' => strings.invalidPairCode,
            'Пара с таким кодом не найдена на этом устройстве.' ||
            'Пара с таким кодом не найдена на сервере.' => strings.pairNotFound,
            'В этой паре уже два участника.' => strings.pairFull,
            'already_in_pair' => strings.pairAlreadyInPair,
            _ => error.message,
          },
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = _pairErrorMessage(AppLocalizations.of(context)!, error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deletePair() async {
    final room = _room;
    if (room == null) return;
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.breakPairTitle),
        content: Text(strings.breakPairWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.breakPairConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repository.deletePair(room);
      if (!mounted) return;
      setState(() => _room = null);
      widget.onPairUpdated?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _error = strings.pairDeleteError);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _pairErrorMessage(AppLocalizations strings, Object error) {
    final reason = error is SupabaseUnavailableException ? error.reason : error;
    if (reason is AuthException) {
      return reason is AuthApiException &&
              reason.code == 'anonymous_provider_disabled'
          ? strings.anonymousSignInDisabled
          : strings.pairAuthUnavailable;
    }
    return strings.pairCreateError(error.toString());
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
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('pair-participant-name'),
                    controller: _participantNameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => setState(() {
                      _hasEditedParticipantName = true;
                      _participantName = value.trim().isEmpty
                          ? null
                          : value.trim();
                    }),
                    decoration: InputDecoration(
                      labelText: strings.yourName,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _createPair,
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
                    onPressed: _isBusy ? null : _joinPair,
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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _deletePair,
                      icon: const Icon(Icons.link_off_rounded),
                      label: Text(strings.breakPair),
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
