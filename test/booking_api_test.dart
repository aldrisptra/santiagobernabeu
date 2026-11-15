import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:santiago_bernabeu/data/demo_data.dart';
import 'package:santiago_bernabeu/models/booking.dart';
import 'package:santiago_bernabeu/services/booking_api.dart';

import 'support/booking_fixtures.dart';

Matcher apiError(String message) => isA<BookingApiException>().having(
  (error) => error.message,
  'message',
  message,
);

BookingApi apiFor(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 10),
}) => BookingApi(
  client: mockSupabaseClient(MockClient(handler)),
  timeout: timeout,
);

http.Response jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

BookingApi respondingWith(Object? body, {int status = 200}) =>
    apiFor((_) async => jsonResponse(body, status: status));

Map<String, dynamic> authSession() {
  String encode(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final expires = DateTime.now().add(const Duration(hours: 1));
  final token = [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({
      'sub': '00000000-0000-0000-0000-000000000001',
      'exp': expires.millisecondsSinceEpoch ~/ 1000,
      'role': 'authenticated',
    }),
    'signature',
  ].join('.');
  return {
    'access_token': token,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': '00000000-0000-0000-0000-000000000001',
      'email': 'admin@example.com',
      'aud': 'authenticated',
      'role': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

void main() {
  group('BookingApi Supabase', () {
    test(
      'missing configuration fails without attempting a local server',
      () async {
        final api = BookingApi();
        expect(api.isConfigured, isFalse);
        await expectLater(
          api.fetchBookings(),
          throwsA(
            apiError(
              'Konfigurasi Supabase belum diisi. Ikuti panduan pada README.',
            ),
          ),
        );
        await expectLater(
          BookingApi(configurationError: 'Konfigurasi tidak valid.')
              .signInAdmin(email: 'admin@example.com', password: 'test'),
          throwsA(apiError('Konfigurasi tidak valid.')),
        );
      },
    );

    test(
      'GET uses Supabase REST query and parses all booking fields',
      () async {
        final records = bookingFixtures();
        records.first['hours'] = ['08:00', '19:00'];
        records.first['day_price'] = 275000;
        records.first['night_price'] = 375000;
        records.last['status'] = 'cancelled';
        final api = apiFor((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/bookings');
          expect(
            request.url.queryParameters['select'],
            'id,date,hours,customer_name,customer_phone,day_price,night_price,status,payment_path,payment_status,payment_note,customer_id',
          );
          expect(
            request.url.queryParameters['order'],
            'date.desc.nullslast,id.asc.nullslast',
          );
          expect(request.url.queryParameters['offset'], '0');
          expect(request.url.queryParameters['limit'], '500');
          expect(request.headers['apikey'], 'sb_publishable_test');
          return jsonResponse(records);
        });
        expect(api.isConfigured, isTrue);

        final bookings = await api.fetchBookings();
        expect(bookings.map((booking) => booking.id), [
          'API-001',
          'API-002',
          'API-003',
        ]);
        final first = bookings.first;
        expect(
          first.date.toIso8601String().substring(0, 10),
          records.first['date'],
        );
        expect(first.customerName, 'Budi');
        expect(first.customerPhone, '081234567801');
        expect(first.hours, ['08:00', '19:00']);
        expect(first.dayPrice, 275000);
        expect(first.nightPrice, 375000);
        expect(first.total, 650000);
        expect(bookings[1].total, 350000);
        expect(bookings.map((booking) => booking.status), [
          BookingStatus.pending,
          BookingStatus.confirmed,
          BookingStatus.cancelled,
        ]);
      },
    );

    test(
      'loads beyond Supabase default response limit with stable pagination',
      () async {
        final records = List.generate(
          1001,
          (index) => {...bookingFixtures().first, 'id': 'API-$index'},
        );
        final offsets = <int>[];
        final api = apiFor((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          offsets.add(offset);
          return jsonResponse(records.skip(offset).take(500).toList());
        });
        expect(await api.fetchBookings(), hasLength(1001));
        expect(offsets, [0, 500, 1000]);
      },
    );

    test('accepts an empty server list', () async {
      expect(await respondingWith([]).fetchBookings(), isEmpty);
    });

    test('rejects malformed JSON and invalid response structure', () async {
      final api = apiFor((_) async => http.Response('<html>bad</html>', 200));
      await expectLater(
        api.fetchBookings(),
        throwsA(isA<BookingApiException>()),
      );
      await expectLater(
        respondingWith({'data': []}).fetchBookings(),
        throwsA(isA<BookingApiException>()),
      );
    });

    test(
      'rejects invalid booking schema, dates, status, prices and hours',
      () async {
        final invalidRecords = <Map<String, dynamic>>[
          {...bookingFixtures().first}..remove('customer_name'),
          {...bookingFixtures().first, 'date': '2026-02-30'},
          {...bookingFixtures().first, 'date': '2026-11-02T08:00:00'},
          {...bookingFixtures().first, 'status': 'paid'},
          {...bookingFixtures().first, 'hours': <String>[]},
          {
            ...bookingFixtures().first,
            'hours': ['24:00'],
          },
          {
            ...bookingFixtures().first,
            'hours': ['08:30'],
          },
          {
            ...bookingFixtures().first,
            'hours': ['08:00', '08:00'],
          },
          {...bookingFixtures().first, 'day_price': -1},
        ];
        for (final record in invalidRecords) {
          await expectLater(
            respondingWith([record]).fetchBookings(),
            throwsA(apiError('Data booking dari server tidak valid.')),
            reason: 'Invalid record must not enter the app: $record',
          );
        }
      },
    );

    test('rejects duplicate IDs before they overwrite the cache', () async {
      final record = bookingFixtures().first;
      await expectLater(
        respondingWith([record, record]).fetchBookings(),
        throwsA(apiError('Kode booking dari server duplikat.')),
      );
    });

    test('preserves business errors and maps denied database access', () async {
      for (final code in ['PT400', 'PT403', 'PT404', 'PT409']) {
        final api = respondingWith({
          'code': code,
          'message': 'Booking ditolak oleh server.',
          'details': null,
          'hint': null,
        }, status: int.parse(code.substring(2)));
        await expectLater(
          api.updateStatus('API-001', BookingStatus.confirmed),
          throwsA(apiError('Booking ditolak oleh server.')),
        );
      }
      await expectLater(
        respondingWith({
          'code': '42501',
          'message': 'permission denied',
        }, status: 403).fetchBookings(),
        throwsA(
          apiError('Akses booking ditolak. Silakan masuk dengan akun admin.'),
        ),
      );
    });

    test('maps connection failures and timeouts into useful errors', () async {
      final offline = apiFor(
        (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        offline.fetchBookings(),
        throwsA(
          apiError(
            'Tidak dapat terhubung ke server booking. Periksa koneksi lalu coba lagi.',
          ),
        ),
      );
      final slow = apiFor(
        (_) => Completer<http.Response>().future,
        timeout: Duration.zero,
      );
      await expectLater(
        slow.fetchBookings(),
        throwsA(apiError('Server terlalu lama merespons. Silakan coba lagi.')),
      );
    });

    test('RPC sends the ID and status and requests one record', () async {
      const id = 'API/001 with space';
      final api = apiFor((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/set_booking_status');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['accept'], 'application/vnd.pgrst.object+json');
        expect(jsonDecode(request.body), {
          'p_booking_id': id,
          'p_status': 'confirmed',
        });
        return jsonResponse({
          ...bookingFixtures().first,
          'id': id,
          'status': 'confirmed',
        });
      });
      final updated = await api.updateStatus(id, BookingStatus.confirmed);
      expect(updated.id, id);
      expect(updated.status, BookingStatus.confirmed);
    });

    test('rejects RPC responses for a different booking or status', () async {
      for (final record in [
        {...bookingFixtures().first, 'id': 'other', 'status': 'confirmed'},
        bookingFixtures().first,
      ]) {
        await expectLater(
          respondingWith(record)
              .updateStatus('API-001', BookingStatus.confirmed),
          throwsA(apiError('Format perubahan booking tidak valid.')),
        );
      }
    });

    test(
      'invalid Supabase credentials produce an Indonesian login error',
      () async {
        final api = apiFor((request) async {
          expect(request.url.path, '/auth/v1/token');
          expect(request.url.queryParameters['grant_type'], 'password');
          expect(jsonDecode(request.body)['email'], 'admin@example.com');
          return jsonResponse({
            'code': 'invalid_credentials',
            'msg': 'Invalid login credentials',
          }, status: 400);
        });
        await expectLater(
          api.signInAdmin(email: ' admin@example.com ', password: 'wrong'),
          throwsA(apiError('Email atau password tidak sesuai.')),
        );
      },
    );

    test('login verifies server role and clears a non-admin session', () async {
      for (final allowed in [true, false]) {
        final paths = <String>[];
        final client = mockSupabaseClient(
          MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path == '/auth/v1/token') {
              return jsonResponse(authSession());
            }
            if (request.url.path == '/rest/v1/rpc/is_booking_admin') {
              expect(request.method, 'POST');
              expect(request.headers['authorization'], startsWith('Bearer '));
              return jsonResponse(allowed);
            }
            if (request.url.path == '/auth/v1/logout') {
              return http.Response('', 204);
            }
            fail('Unexpected request: ${request.url}');
          }),
        );
        final api = BookingApi(client: client);
        if (allowed) {
          await api.signInAdmin(
            email: 'admin@example.com',
            password: 'admin123',
          );
          expect(client.auth.currentSession, isNotNull);
          await api.signOutAdmin();
          expect(client.auth.currentSession, isNull);
        } else {
          await expectLater(
            api.signInAdmin(email: 'admin@example.com', password: 'admin123'),
            throwsA(apiError('Akun ini tidak memiliki akses admin booking.')),
          );
          expect(client.auth.currentSession, isNull);
        }
        expect(paths, contains('/rest/v1/rpc/is_booking_admin'));
        expect(paths, contains('/auth/v1/logout'));
      }
    });
  });

  group('Admin booking state', () {
    test(
      'replaces an empty remote cache without creating local bookings',
      () async {
        var records = bookingFixtures();
        final data = DemoData(
          bookingApi: apiFor((_) async => jsonResponse(records)),
        );
        addTearDown(data.dispose);
        await data.loadAdminBookings();
        expect(data.hasLoadedApiBookings, isTrue);
        expect(data.apiBookingCount, 3);
        expect(data.adminBookings, hasLength(3));
        expect(data.bookings, isEmpty);
        records = [];
        await data.loadAdminBookings();
        expect(data.apiBookingCount, 0);
        expect(data.adminBookings, isEmpty);
        expect(data.bookings, isEmpty);
      },
    );

    test(
      'persists remote status while preserving local bookings and prices',
      () async {
        final requests = <http.Request>[];
        final data = DemoData(
          bookingApi: fakeBookingApi(onRequest: requests.add),
        );
        addTearDown(data.dispose);
        data.dayPrice = 300000;
        await data.loadAdminBookings();
        final remote = data.adminBookings.singleWhere((b) => b.id == 'API-001');
        await data.changeAdminBookingStatus(remote, BookingStatus.confirmed);
        expect(remote.status, BookingStatus.confirmed);
        expect(data.dayPrice, 300000);
        expect(data.bookings, isEmpty);
        expect(
          requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        await data.loadAdminBookings();
        expect(
          data.adminBookings.singleWhere((b) => b.id == remote.id).status,
          BookingStatus.confirmed,
        );
      },
    );

    test('failed status update preserves visible booking and cache', () async {
      final data = DemoData(
        bookingApi: apiFor(
          (request) async => request.method == 'GET'
              ? jsonResponse(bookingFixtures())
              : jsonResponse({
                  'code': 'PT409',
                  'message': 'Gagal menyimpan booking.',
                }, status: 409),
        ),
      );
      addTearDown(data.dispose);
      await data.loadAdminBookings();
      final booking = data.adminBookings.first;
      await expectLater(
        data.changeAdminBookingStatus(booking, BookingStatus.confirmed),
        throwsA(apiError('Gagal menyimpan booking.')),
      );
      expect(booking.status, BookingStatus.pending);
      expect(data.adminBookings.first, same(booking));
      expect(data.apiBookingCount, 3);
    });

    test('failed reload preserves last successful server data', () async {
      var unavailable = false;
      final data = DemoData(
        bookingApi: apiFor(
          (_) async => unavailable
              ? jsonResponse({
                  'code': 'PT503',
                  'message': 'Server sibuk.',
                }, status: 503)
              : jsonResponse(bookingFixtures()),
        ),
      );
      addTearDown(data.dispose);
      await data.loadAdminBookings();
      final cached = data.adminBookings.first;
      unavailable = true;
      await expectLater(
        data.loadAdminBookings(),
        throwsA(apiError('Server sibuk.')),
      );
      expect(data.adminBookings.first, same(cached));
      expect(data.apiBookingCount, 3);
      expect(data.hasLoadedApiBookings, isTrue);
    });

    test('late GET cannot overwrite a successful status change', () async {
      final delayedGet = Completer<http.Response>();
      final getStarted = Completer<void>();
      var gets = 0;
      final data = DemoData(
        bookingApi: apiFor((request) async {
          if (request.method == 'POST') {
            return jsonResponse({
              ...bookingFixtures().first,
              'status': 'confirmed',
            });
          }
          if (++gets == 1) return jsonResponse(bookingFixtures());
          getStarted.complete();
          return delayedGet.future;
        }),
      );
      addTearDown(data.dispose);
      await data.loadAdminBookings();
      final booking = data.adminBookings.first;
      final staleLoad = data.loadAdminBookings();
      await getStarted.future;
      await data.changeAdminBookingStatus(booking, BookingStatus.confirmed);
      delayedGet.complete(jsonResponse(bookingFixtures()));
      await staleLoad;
      expect(booking.status, BookingStatus.confirmed);
      expect(data.adminBookings.first.status, BookingStatus.confirmed);
      expect(data.apiBookingCount, 3);
    });

    test(
      'fetch completing after logout cannot restore booking cache',
      () async {
        final delayedGet = Completer<http.Response>();
        final getStarted = Completer<void>();
        final data = DemoData(
          bookingApi: apiFor((_) async {
            getStarted.complete();
            return delayedGet.future;
          }),
        );
        addTearDown(data.dispose);
        final pendingLoad = data.loadAdminBookings();
        await getStarted.future;
        await data.signOutAdmin();
        delayedGet.complete(jsonResponse(bookingFixtures()));
        await pendingLoad;
        expect(data.signedIn, isFalse);
        expect(data.hasLoadedApiBookings, isFalse);
        expect(data.apiBookingCount, 0);
        expect(data.adminBookings, isEmpty);
        expect(data.bookings, isEmpty);
      },
    );

    test(
      'status update completing after logout cannot restore booking cache',
      () async {
        final delayedUpdate = Completer<http.Response>();
        final updateStarted = Completer<void>();
        final data = DemoData(
          bookingApi: apiFor((request) async {
            if (request.url.path == '/auth/v1/logout') {
              return http.Response('', 204);
            }
            if (request.method == 'GET') return jsonResponse(bookingFixtures());
            updateStarted.complete();
            return delayedUpdate.future;
          }),
        );
        addTearDown(data.dispose);
        await data.loadAdminBookings();
        final booking = data.adminBookings.first;
        final pendingUpdate = data.changeAdminBookingStatus(
          booking,
          BookingStatus.confirmed,
        );
        await updateStarted.future;
        await data.signOutAdmin();
        delayedUpdate.complete(
          jsonResponse({...bookingFixtures().first, 'status': 'confirmed'}),
        );
        await pendingUpdate;
        expect(data.hasLoadedApiBookings, isFalse);
        expect(data.apiBookingCount, 0);
        expect(data.adminBookings, isEmpty);
      },
    );
  });
}
