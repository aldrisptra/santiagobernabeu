import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/config/supabase_config.dart';

void main() {
  test('requires both project URL and public key', () {
    for (final config in [
      const SupabaseConfig(url: '', publishableKey: ''),
      const SupabaseConfig(
        url: 'https://booking.supabase.co',
        publishableKey: '',
      ),
      const SupabaseConfig(url: '', publishableKey: 'sb_publishable_test'),
    ]) {
      expect(config.validationMessage, contains('belum lengkap'));
    }
  });

  test('accepts a project URL and publishable key', () {
    const config = SupabaseConfig(
      url: 'https://booking.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
    expect(config.validationMessage, isNull);
  });

  test('rejects URLs with credentials or an insecure scheme', () {
    for (final url in [
      'http://booking.supabase.co',
      'https://user:password@booking.supabase.co',
      'https://booking.supabase.co/rest/v1',
    ]) {
      final config = SupabaseConfig(
        url: url,
        publishableKey: 'sb_publishable_test',
      );
      expect(config.validationMessage, contains('Project URL HTTPS'));
    }
  });

  test(
    'rejects elevated modern and legacy keys in the mobile configuration',
    () {
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'role': 'service_role'})),
      );
      for (final key in ['sb_secret_test', 'header.$payload.signature']) {
        final config = SupabaseConfig(
          url: 'https://booking.supabase.co',
          publishableKey: key,
        );
        expect(
          config.validationMessage,
          contains('publishable key atau anon key'),
        );
      }
    },
  );
}
