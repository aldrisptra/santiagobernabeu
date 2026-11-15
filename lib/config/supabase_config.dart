import 'dart:convert';

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final String url;
  final String publishableKey;

  String? get validationMessage {
    if (url.isEmpty || publishableKey.isEmpty) {
      return 'Konfigurasi Supabase belum lengkap. Isi SUPABASE_URL dan '
          'SUPABASE_PUBLISHABLE_KEY sesuai panduan README.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'SUPABASE_URL harus berupa Project URL HTTPS dari Supabase.';
    }
    if (publishableKey.startsWith('sb_secret_') || _isServiceRoleKey()) {
      return 'Gunakan publishable key atau anon key untuk aplikasi mobile.';
    }
    if (url.contains('PROJECT-REF') || publishableKey.contains('GANTI-')) {
      return 'Ganti contoh konfigurasi dengan Project URL dan publishable key milikmu.';
    }
    return null;
  }

  bool _isServiceRoleKey() {
    final parts = publishableKey.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
