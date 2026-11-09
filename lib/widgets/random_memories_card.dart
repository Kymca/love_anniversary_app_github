import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/telegram_chat_service.dart';
import '../theme/app_theme.dart';

class RandomMemoriesCard extends StatefulWidget {
  const RandomMemoriesCard({super.key, this.service, this.contextCount = 3});

  final TelegramChatService? service;
  final int contextCount;

  @override
  State<RandomMemoriesCard> createState() => _RandomMemoriesCardState();
}

class _RandomMemoriesCardState extends State<RandomMemoriesCard> {
  late final TelegramChatService _service =
      widget.service ?? TelegramChatService();
  ChatSnippet? _snippet;
  bool _isFavorite = false;
  bool _isLoading = true;
  bool _isUpdatingFavorite = false;
  bool _hasStartedLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedLoading) return;
    _hasStartedLoading = true;
    _loadSnippet();
  }

  Future<void> _loadSnippet() async {
    final strings = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final snippet = await _service.getRandomSnippet(
        contextCount: widget.contextCount,
      );
      final isFavorite = await _service.isFavorite(snippet);
      if (!mounted) return;
      setState(() {
        _snippet = snippet;
        _isFavorite = isFavorite;
        _isLoading = false;
      });
    } on NoEligibleMemoryException {
      if (!mounted) return;
      setState(() {
        _errorMessage = strings.noEligibleMemoryError;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = strings.randomMemoryLoadError;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final snippet = _snippet;
    if (snippet == null || _isUpdatingFavorite) return;
    setState(() {
      _isUpdatingFavorite = true;
      _errorMessage = null;
    });
    try {
      final isFavorite = await _service.toggleFavorite(snippet);
      if (!mounted) return;
      setState(() {
        _isFavorite = isFavorite;
        _isUpdatingFavorite = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.favoriteUpdateError;
        _isUpdatingFavorite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.rose,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.dailyQuoteTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_snippet != null)
                IconButton(
                  tooltip: _isFavorite
                      ? strings.removeFavorite
                      : strings.addFavorite,
                  onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
                  icon: _isUpdatingFavorite
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.rose,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildContent(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              key: const ValueKey('memory-error'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.roseDeep),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _loadSnippet,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.casino_rounded),
              label: Text(strings.showAnotherMoment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final strings = AppLocalizations.of(context)!;
    if (_isLoading && _snippet == null) {
      return const Padding(
        key: ValueKey('memory-loading'),
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final snippet = _snippet;
    if (snippet == null) {
      return Padding(
        key: ValueKey('memory-empty'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(strings.noSuitableMemory),
      );
    }
    return ConstrainedBox(
      key: ValueKey(snippet.id),
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var index = 0; index < snippet.messages.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _SnippetMessageTile(
                message: snippet.messages[index],
                index: index,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnippetMessageTile extends StatelessWidget {
  const _SnippetMessageTile({required this.message, required this.index});

  final SnippetMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFF9E6EC),
      const Color(0xFFEDE7F7),
      const Color(0xFFFFEEE2),
      const Color(0xFFE5F0ED),
      const Color(0xFFF7E9DE),
    ];
    final background = colors[index % colors.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            child: Text(
              _initials(message.author),
              style: const TextStyle(
                color: AppColors.roseDeep,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.roseDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (message.timestamp != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(message.timestamp!),
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String author) {
    final parts = author.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
