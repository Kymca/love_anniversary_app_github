import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xbbybirzhmhlsnvmyvxa.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_RucfRH_JuqPwnt33Oo1uRQ_WOW4o6NS',
);

Future<SupabaseClient> initializeSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final client = Supabase.instance.client;
  return client;
}

class SupabaseUnavailableException implements Exception {
  const SupabaseUnavailableException(this.reason);

  final Object reason;

  @override
  String toString() => reason is AuthException
      ? 'Supabase authentication is unavailable.'
      : reason.toString();
}
