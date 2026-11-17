import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/mood_pair_repository.dart';
import '../services/pair_repository.dart';
import '../services/postcard_delivery_gateway.dart';
import '../services/postcard_push_gateway.dart';
import '../theme/app_theme.dart';
import 'postcards_screen.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/cinema_night_widget.dart';
import '../widgets/mood_calendar_widget.dart';
import '../widgets/time_capsule_widget.dart';

class SecretNotesScreen extends StatelessWidget {
  const SecretNotesScreen({
    super.key,
    this.deliveryGateway,
    this.pushGateway,
    this.moodPairRepository,
    this.pairRepository,
    this.isActive = true,
  });

  final PostcardDeliveryGateway? deliveryGateway;
  final PostcardPushGateway? pushGateway;
  final MoodPairRepository? moodPairRepository;
  final PairRepository? pairRepository;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          children: [
            Text(
              strings.secretNotesTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              strings.secretNotesSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const TimeCapsuleWidget(),
            const SizedBox(height: 22),
            const CountdownWidget(),
            const SizedBox(height: 20),
            MoodCalendarWidget(
              repository: moodPairRepository,
              pairRepository: pairRepository,
              isActive: isActive,
            ),
            const SizedBox(height: 20),
            const CinemaNightWidget(),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.postcardsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    strings.postcardsSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => PostcardsScreen(
                          deliveryGateway: deliveryGateway,
                          pushGateway: pushGateway,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.mail_rounded),
                    label: Text(strings.openPostcards),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
