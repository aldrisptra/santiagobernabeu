import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'supabase_config.dart';

class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException(this.message);

  final String message;
}

/// Uses a complete command-line override, or the bundled public configuration.
/// A partial override must fail instead of mixing credentials from two projects.
Future<SupabaseConfig> loadSupabaseConfig({
  SupabaseConfig environment = const SupabaseConfig.fromEnvironment(),
  AssetBundle? bundle,
}) async {
  if (environment.url.isNotEmpty || environment.publishableKey.isNotEmpty) {
    return _validated(environment);
  }

  final String source;
  try {
    source = await (bundle ?? rootBundle).loadString(
      'config/supabase.public.json',
    );
  } on FlutterError {
    throw const SupabaseConfigurationException(
      'Konfigurasi koneksi aplikasi tidak tersedia. Hentikan aplikasi lalu '
      'jalankan ulang dengan flutter run.',
    );
  }

  final dynamic values;
  try {
    values = jsonDecode(source);
  } on FormatException {
    throw const SupabaseConfigurationException(
      'Format konfigurasi koneksi aplikasi tidak valid.',
    );
  }
  if (values is! Map<String, dynamic> ||
      values['SUPABASE_URL'] is! String ||
      values['SUPABASE_PUBLISHABLE_KEY'] is! String) {
    throw const SupabaseConfigurationException(
      'Konfigurasi koneksi aplikasi harus berisi URL dan publishable key.',
    );
  }

  return _validated(
    SupabaseConfig(
      url: (values['SUPABASE_URL'] as String).trim(),
      publishableKey: (values['SUPABASE_PUBLISHABLE_KEY'] as String).trim(),
    ),
  );
}

SupabaseConfig _validated(SupabaseConfig config) {
  final message = config.validationMessage;
  if (message != null) throw SupabaseConfigurationException(message);
  return config;
}
