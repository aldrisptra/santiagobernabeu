import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/config/load_supabase_config.dart';
import 'package:santiago_bernabeu/config/supabase_config.dart';

const _emptyEnvironment = SupabaseConfig(url: '', publishableKey: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'plain startup loads a valid bundled public project configuration',
    () async {
      final config = await loadSupabaseConfig(environment: _emptyEnvironment);
      expect(config.validationMessage, isNull);
      expect(config.publishableKey, startsWith('sb_publishable_'));

      final values = jsonDecode(
        await rootBundle.loadString('config/supabase.public.json'),
      ) as Map<String, dynamic>;
      expect(
        values.keys,
        unorderedEquals(['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY']),
      );
    },
  );

  test(
    'a complete environment override does not read the bundled project',
    () async {
      const override = SupabaseConfig(
        url: 'https://alternate.supabase.co',
        publishableKey: 'sb_publishable_override',
      );
      final bundle = _ConfigBundle(null);
      final config = await loadSupabaseConfig(
        environment: override,
        bundle: bundle,
      );
      expect(config, same(override));
      expect(bundle.loadCount, 0);
    },
  );

  test(
    'a partial override never mixes projects with the bundled configuration',
    () async {
      for (final override in [
        const SupabaseConfig(
          url: 'https://alternate.supabase.co',
          publishableKey: '',
        ),
        const SupabaseConfig(
          url: '',
          publishableKey: 'sb_publishable_override',
        ),
      ]) {
        final bundle = _ConfigBundle(null);
        await expectLater(
          loadSupabaseConfig(environment: override, bundle: bundle),
          throwsA(isA<SupabaseConfigurationException>()),
        );
        expect(bundle.loadCount, 0);
      }
    },
  );

  test(
    'missing or malformed bundled configuration gives a readable error',
    () async {
      for (final source in [null, '{invalid', '[]', '{"SUPABASE_URL":7}']) {
        await expectLater(
          loadSupabaseConfig(
            environment: _emptyEnvironment,
            bundle: _ConfigBundle(source),
          ),
          throwsA(
            isA<SupabaseConfigurationException>().having(
              (error) => error.message.toLowerCase(),
              'message',
              contains('konfigurasi'),
            ),
          ),
        );
      }
    },
  );

  test(
    'bundled secret and service-role keys cannot initialize the client',
    () async {
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'role': 'service_role'})),
      );
      for (final key in ['sb_secret_test', 'header.$payload.signature']) {
        await expectLater(
          loadSupabaseConfig(
            environment: _emptyEnvironment,
            bundle: _ConfigBundle(
              jsonEncode({
                'SUPABASE_URL': 'https://booking.supabase.co',
                'SUPABASE_PUBLISHABLE_KEY': key,
              }),
            ),
          ),
          throwsA(
            isA<SupabaseConfigurationException>().having(
              (error) => error.message,
              'message',
              contains('publishable key atau anon key'),
            ),
          ),
        );
      }
    },
  );
}

class _ConfigBundle extends CachingAssetBundle {
  _ConfigBundle(this.source);

  final String? source;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    if (source == null) throw FlutterError('Missing test asset');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source!)));
  }
}
