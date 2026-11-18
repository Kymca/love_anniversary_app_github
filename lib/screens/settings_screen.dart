import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_release.dart';
import '../services/pair_email_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authService,
    this.onAuthChanged,
    this.onCheckForUpdate,
  });

  final PairEmailAuthService? authService;
  final VoidCallback? onAuthChanged;
  final Future<AppRelease?> Function()? onCheckForUpdate;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _isBusy = false;
  bool _isCheckingForUpdate = false;
  String? _error;
  String? _updateCheckMessage;
  String? _requestedEmail;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.authService?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final strings = AppLocalizations.of(context)!;
    final service = widget.authService;
    if (service == null) {
      setState(() => _error = strings.pairEmailAuthUnavailable);
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await service.sendCode(_emailController.text);
      if (mounted) {
        setState(() {
          _requestedEmail = _emailController.text.trim().toLowerCase();
          _codeSent = true;
        });
      }
    } catch (error, stackTrace) {
      _reportPairEmailAuthError(error, stackTrace, 'send OTP');
      if (mounted) {
        setState(
          () => _error = _isEmailSendRateLimited(error)
              ? strings.pairEmailRateLimitError
              : strings.pairEmailSendCodeError(
                  _pairEmailAuthErrorDetail(error),
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyCode() async {
    final strings = AppLocalizations.of(context)!;
    final service = widget.authService;
    if (service == null) {
      setState(() => _error = strings.pairEmailAuthUnavailable);
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await service.verifyCode(_emailController.text, _codeController.text);
      if (!service.isEmailVerified) {
        throw StateError('Email was not confirmed.');
      }
      if (!mounted) return;
      setState(() {
        _codeSent = false;
        _requestedEmail = null;
        _codeController.clear();
      });
      widget.onAuthChanged?.call();
    } catch (error, stackTrace) {
      _reportPairEmailAuthError(error, stackTrace, 'verify OTP');
      if (mounted) {
        setState(
          () => _error = strings.pairEmailVerifyCodeError(
            _pairEmailAuthErrorDetail(error),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _pairEmailAuthErrorDetail(Object error) {
    if (error is AuthException) {
      final details = <String>[];
      final code = error.code;
      if (code != null && code.isNotEmpty) details.add(code);
      final status = error.statusCode;
      if (status != null && status.isNotEmpty) details.add('HTTP $status');
      return details.isEmpty
          ? error.message
          : '${error.message} (${details.join(', ')})';
    }
    if (error is FormatException) return error.message;
    return error.toString();
  }

  bool _isEmailSendRateLimited(Object error) {
    if (error is! AuthApiException) return false;
    if (error.code == 'over_email_send_rate_limit') return true;
    return error.statusCode == '429' &&
        error.message.toLowerCase().contains('email rate limit');
  }

  void _reportPairEmailAuthError(
    Object error,
    StackTrace stackTrace,
    String operation,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Supabase email OTP $operation',
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    final check = widget.onCheckForUpdate;
    if (check == null || _isCheckingForUpdate) return;

    final strings = AppLocalizations.of(context)!;
    setState(() {
      _isCheckingForUpdate = true;
      _updateCheckMessage = strings.appUpdateChecking;
    });
    try {
      final release = await check();
      if (mounted) {
        setState(
          () => _updateCheckMessage = release == null
              ? strings.appUpdateUpToDate
              : strings.appUpdateAvailable(release.versionName),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _updateCheckMessage = strings.appUpdateCheckFailed);
      }
    } finally {
      if (mounted) setState(() => _isCheckingForUpdate = false);
    }
  }

  void _onEmailChanged(String value) {
    final changedEmail = value.trim().toLowerCase() != _requestedEmail;
    if (!_codeSent || !changedEmail) return;
    widget.authService?.clearPendingCode();
    setState(() {
      _codeSent = false;
      _requestedEmail = null;
      _codeController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final service = widget.authService;
    final isVerified = service?.isEmailVerified ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              strings.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(strings.pairEmailAuthDescription),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.appUpdateSettingsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: widget.onCheckForUpdate == null ||
                              _isCheckingForUpdate
                          ? null
                          : _checkForUpdate,
                      icon: _isCheckingForUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt_rounded),
                      label: Text(strings.appUpdateCheckAction),
                    ),
                    if (_updateCheckMessage != null ||
                        widget.onCheckForUpdate == null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _updateCheckMessage ??
                            strings.appUpdateCheckUnavailable,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.pairEmailAuthTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      enabled: !isVerified && !_isBusy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onChanged: _onEmailChanged,
                      decoration: InputDecoration(
                        labelText: strings.pairEmailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(height: 10),
                      Text(strings.pairEmailVerified(service!.email ?? '')),
                    ] else if (_codeSent) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: InputDecoration(
                          labelText: strings.pairEmailCodeLabel,
                          prefixIcon: const Icon(Icons.password_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _isBusy ? null : _verifyCode,
                        child: Text(strings.pairConfirmEmailCode),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _isBusy ? null : _sendCode,
                        child: Text(strings.pairSendEmailCode),
                      ),
                    ],
                    if (!isVerified) ...[
                      const SizedBox(height: 8),
                      Text(strings.pairEmailOptional),
                    ],
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
            ),
          ],
        ),
      ),
    );
  }
}
