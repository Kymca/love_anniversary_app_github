import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/postcard.dart';
import '../services/postcard_delivery_gateway.dart';
import '../services/lan_postcard_config.dart';
import '../services/lan_postcard_gateway.dart';
import '../services/postcard_push_gateway.dart';
import '../services/participant_profile_repository.dart';
import '../services/postcard_repository.dart';
import '../theme/app_theme.dart';

class PostcardsScreen extends StatefulWidget {
  const PostcardsScreen({
    super.key,
    this.repository,
    this.deliveryGateway,
    this.pushGateway,
  });

  final PostcardRepository? repository;
  final PostcardDeliveryGateway? deliveryGateway;
  final PostcardPushGateway? pushGateway;

  @override
  State<PostcardsScreen> createState() => _PostcardsScreenState();
}

class _PostcardsScreenState extends State<PostcardsScreen> {
  late final PostcardRepository _repository =
      widget.repository ?? PostcardRepository();
  late Future<List<Postcard>> _postcards = _repository.load();
  PostcardDeliveryGateway? _gateway;
  LanPostcardConfig? _lanConfig;
  StreamSubscription<String>? _incomingSubscription;
  PostcardDirection? _filter;
  bool _isRefreshing = false;
  bool _hasConfigError = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.deliveryGateway;
    if (_gateway == null) unawaited(_loadLanConfig());
    if (_gateway != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshInbox(showError: false));
      });
    }
    final pushGateway = widget.pushGateway;
    if (_gateway != null && pushGateway != null) {
      _incomingSubscription = pushGateway.receivedPostcardIds.listen(
        (postcardId) => unawaited(_loadReceivedPostcard(postcardId)),
        onError: (Object error, StackTrace stackTrace) {
          _showIncomingError();
        },
      );
    }
  }

  Future<void> _loadLanConfig() async {
    try {
      final config = await LanPostcardConfig.load();
      if (!mounted) return;
      if (config != null) await _applyLanConfig(config, save: false);
    } catch (error) {
      if (mounted) setState(() => _hasConfigError = true);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _applyLanConfig(
    LanPostcardConfig config, {
    required bool save,
  }) async {
    config.validate();
    if (save) await config.save();
    final names = await ParticipantProfileRepository().loadNames();
    final senderName = names[config.side] ?? '';
    if (!mounted) return;
    setState(() {
      _lanConfig = config;
      _hasConfigError = false;
      _gateway = LanPostcardGateway(config: config, senderName: senderName);
    });
    await _refreshInbox(showError: false);
  }

  Future<void> _configureLanServer() async {
    final strings = AppLocalizations.of(context)!;
    final config = await showDialog<LanPostcardConfig>(
      context: context,
      builder: (context) =>
          _LanConnectionDialog(strings: strings, initialConfig: _lanConfig),
    );
    if (config == null || !mounted) return;
    try {
      await _applyLanConfig(config, save: true);
      if (mounted) _showMessage(strings.postcardLanSaved);
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _refreshInbox({bool showError = true}) async {
    final gateway = _gateway;
    if (gateway == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final incoming = await gateway.loadReceivedPostcards();
      for (final postcard in incoming) {
        await _repository.recordReceived(postcard);
      }
      if (!mounted) return;
      setState(() {
        _postcards = _repository.load();
      });
    } catch (error) {
      if (showError && mounted) {
        _showMessage(AppLocalizations.of(context)!.postcardLanRefreshFailed);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadReceivedPostcard(String postcardId) async {
    try {
      final gateway = _gateway;
      if (gateway == null) return;
      final postcard = await gateway.loadReceivedPostcard(postcardId);
      if (postcard == null || postcard.id != postcardId) {
        throw StateError('The backend did not return the signaled postcard.');
      }
      await _repository.recordReceived(postcard);
      if (!mounted) return;
      setState(() {
        _postcards = _repository.load();
      });
    } catch (error) {
      _showIncomingError();
    }
  }

  void _showIncomingError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.postcardLoadError)),
    );
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _compose() async {
    final strings = AppLocalizations.of(context)!;
    final draft = await showDialog<({String recipient, String message})>(
      context: context,
      builder: (context) => _PostcardComposerDialog(strings: strings),
    );
    if (draft == null || !mounted) return;
    if (draft.recipient.isEmpty || draft.message.isEmpty) {
      _showMessage(strings.postcardFieldsRequired);
      return;
    }

    final gateway = _gateway;
    if (gateway == null) {
      _showMessage(strings.postcardPushUnavailable);
      return;
    }
    try {
      final postcard = await gateway.sendPostcard(
        recipientId: draft.recipient,
        message: draft.message,
      );
      await _repository.recordSent(postcard);
      if (mounted) {
        setState(() {
          _postcards = _repository.load();
        });
        _showMessage(strings.postcardSent);
      }
    } catch (error) {
      if (mounted) _showMessage(strings.postcardSendFailed);
    }
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
        child: FutureBuilder<List<Postcard>>(
          future: _postcards,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(strings.postcardLoadError));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snapshot.data!
                .where((card) => _filter == null || card.direction == _filter)
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.postcardsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('postcard-lan-settings'),
                      tooltip: strings.postcardLanSettings,
                      onPressed: widget.deliveryGateway == null
                          ? _configureLanServer
                          : null,
                      icon: const Icon(Icons.settings_ethernet_rounded),
                    ),
                    IconButton(
                      key: const ValueKey('postcard-refresh-inbox'),
                      tooltip: strings.postcardLanUpdate,
                      onPressed: _gateway == null || _isRefreshing
                          ? null
                          : _refreshInbox,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  strings.postcardsSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                _PushUnavailableNotice(
                  text: _gateway == null
                      ? _hasConfigError
                            ? strings.postcardLanRefreshFailed
                            : strings.postcardPushUnavailable
                      : strings.postcardLanConfigured,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('compose-postcard'),
                    onPressed: _compose,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(strings.postcardComposeTitle),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PostcardDirection?>(
                  segments: [
                    ButtonSegment(
                      value: null,
                      label: Text(strings.postcardAll),
                    ),
                    ButtonSegment(
                      value: PostcardDirection.sent,
                      label: Text(strings.postcardSentTab),
                    ),
                    ButtonSegment(
                      value: PostcardDirection.received,
                      label: Text(strings.postcardReceivedTab),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.first),
                ),
                const SizedBox(height: 12),
                if (cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text(strings.postcardsEmpty)),
                  )
                else
                  for (final card in cards) _PostcardTile(card: card),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanConnectionDialog extends StatefulWidget {
  const _LanConnectionDialog({
    required this.strings,
    required this.initialConfig,
  });

  final AppLocalizations strings;
  final LanPostcardConfig? initialConfig;

  @override
  State<_LanConnectionDialog> createState() => _LanConnectionDialogState();
}

class _LanConnectionDialogState extends State<_LanConnectionDialog> {
  late final _urlController = TextEditingController(
    text: widget.initialConfig?.baseUrl ?? '',
  );
  late final _tokenController = TextEditingController(
    text: widget.initialConfig?.token ?? '',
  );
  late String _side = widget.initialConfig?.side ?? 'first';
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final config = LanPostcardConfig(
        baseUrl: _urlController.text.trim(),
        token: _tokenController.text.trim(),
        side: _side,
      );
      config.validate();
      Navigator.pop(context, config);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.strings.postcardLanSetupTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('postcard-lan-url-input'),
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: widget.strings.postcardLanEndpoint,
            ),
          ),
          TextField(
            key: const ValueKey('postcard-lan-token-input'),
            controller: _tokenController,
            obscureText: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: widget.strings.postcardLanToken,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _side,
            decoration: InputDecoration(
              labelText: widget.strings.postcardLanSide,
            ),
            items: [
              DropdownMenuItem(
                value: 'first',
                child: Text(widget.strings.postcardLanFirst),
              ),
              DropdownMenuItem(
                value: 'second',
                child: Text(widget.strings.postcardLanSecond),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _side = value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.strings.postcardLanHttpWarning,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.strings.cancel),
      ),
      FilledButton(
        key: const ValueKey('postcard-lan-save'),
        onPressed: _save,
        child: Text(widget.strings.save),
      ),
    ],
  );
}

class _PostcardComposerDialog extends StatefulWidget {
  const _PostcardComposerDialog({required this.strings});

  final AppLocalizations strings;

  @override
  State<_PostcardComposerDialog> createState() =>
      _PostcardComposerDialogState();
}

class _PostcardComposerDialogState extends State<_PostcardComposerDialog> {
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.strings.postcardComposeTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _recipientController,
            decoration: InputDecoration(
              labelText: widget.strings.postcardRecipient,
            ),
          ),
          TextField(
            controller: _messageController,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: widget.strings.postcardMessage,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.strings.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          recipient: _recipientController.text.trim(),
          message: _messageController.text.trim(),
        )),
        child: Text(widget.strings.postcardSend),
      ),
    ],
  );
}

class _PushUnavailableNotice extends StatelessWidget {
  const _PushUnavailableNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.roseDeep),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _PostcardTile extends StatelessWidget {
  const _PostcardTile({required this.card});

  final Postcard card;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final sent = card.direction == PostcardDirection.sent;
    final date = card.createdAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sent ? Icons.send_rounded : Icons.mail_rounded,
                  color: AppColors.rose,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sent
                        ? strings.postcardSentTo(card.peerName)
                        : strings.postcardReceivedFrom(card.peerName),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(dateLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(card.message),
          ],
        ),
      ),
    );
  }
}
