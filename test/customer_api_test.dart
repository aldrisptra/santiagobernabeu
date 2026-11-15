import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/models/booking.dart';
import 'package:santiago_bernabeu/services/booking_api.dart';

import 'booking_api_test.dart' show apiFor, apiError, jsonResponse, authSession;
import 'support/booking_fixtures.dart';

void main() {
  test(
    'email limits are explained for signup, recovery and resend without retry',
    () async {
      for (final operation in ['signup', 'recover', 'resend']) {
        var requests = 0;
        final api = apiFor((request) async {
          requests++;
          expect(request.url.path, '/auth/v1/$operation');
          return jsonResponse(
            {
              'code': 'over_email_send_rate_limit',
              'msg': 'Email sending quota exhausted',
            },
            status: 429,
            headers: {'x-supabase-api-version': '2024-01-01'},
          );
        });
        final Future<void> result;
        if (operation == 'signup') {
          result = api.registerCustomer(
            'player@example.com',
            'test-password',
            'Player',
            '081234567890',
          );
        } else if (operation == 'recover') {
          result = api.resetPassword('player@example.com');
        } else {
          result = api.resendConfirmation('player@example.com');
        }
        await expectLater(
          result,
          throwsA(
            apiError(
              'Batas pengiriman email sementara tercapai. Coba lagi nanti atau '
              'hubungi pengelola.',
            ),
          ),
        );
        expect(requests, 1);
      }
    },
  );
  test('legacy email limits without an error code remain readable', () async {
    final api = apiFor(
      (_) async =>
          jsonResponse({'msg': 'email rate limit exceeded'}, status: 429),
    );
    await expectLater(
      api.resetPassword('player@example.com'),
      throwsA(
        apiError(
          'Batas pengiriman email sementara tercapai. Coba lagi nanti atau '
          'hubungi pengelola.',
        ),
      ),
    );
  });
  test(
    'request limits and restricted email recipients have distinct messages',
    () async {
      for (final entry in {
        'over_request_rate_limit': 'Terlalu banyak permintaan. Tunggu beberapa menit sebelum mencoba lagi.',
        'email_address_not_authorized': 'Email verifikasi belum dapat dikirim ke alamat ini. Hubungi pengelola.',
      }.entries) {
        final api = apiFor(
          (_) async => jsonResponse(
            {'code': entry.key, 'msg': 'Auth request rejected'},
            status: entry.key == 'over_request_rate_limit' ? 429 : 403,
            headers: {'x-supabase-api-version': '2024-01-01'},
          ),
        );
        await expectLater(
          api.resetPassword('player@example.com'),
          throwsA(apiError(entry.value)),
        );
      }
    },
  );
  test(
    'Customer login uses password authentication and own booking query',
    () async {
      final api = apiFor((request) async {
        if (request.url.path == '/auth/v1/token') {
          expect(jsonDecode(request.body)['email'], 'player@example.com');
          expect(jsonDecode(request.body)['password'], 'correct-password');
          return jsonResponse(authSession());
        }
        expect(request.url.path, '/rest/v1/bookings');
        expect(
          request.url.queryParameters['customer_id'],
          'eq.00000000-0000-0000-0000-000000000001',
        );
        return jsonResponse(bookingFixtures());
      });
      await api.signInCustomer(' player@example.com ', 'correct-password');
      expect(await api.fetchMyBookings(), hasLength(3));
    },
  );
  test('Unauthenticated own bookings never query a shared listing', () async {
    final api = apiFor((_) async => throw StateError('Must not send request'));
    await expectLater(
      api.fetchMyBookings(),
      throwsA(isA<BookingApiException>()),
    );
  });
  test(
    'Create booking sends date, hours and idempotency key, never client prices',
    () async {
      final record = bookingFixtures().first;
      final api = apiFor((request) async {
        expect(request.url.path, '/rest/v1/rpc/create_booking');
        expect(jsonDecode(request.body), {
          'p_date': '2030-01-02',
          'p_hours': ['08:00'],
          'p_request_id': 'request-uuid',
        });
        return jsonResponse(record);
      });
      final b = await api.createCustomerBooking(DateTime(2030, 1, 2), [
        '08:00',
      ], 'request-uuid');
      expect(b.total, 250000);
    },
  );
  test('Upload uses private user/booking path then submits for review without confirming', () async {
    final record = {...bookingFixtures().first, 'payment_status': 'submitted'};
    String? path;
    final api = apiFor((request) async {
      if (request.url.path == '/auth/v1/token') {
        return jsonResponse(authSession());
      }
      if (request.url.path.startsWith('/storage/v1/object/payment-proofs/')) {
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data;'),
        );
        expect(
          latin1.decode(request.bodyBytes).toLowerCase(),
          contains('content-type: image/jpeg'),
        );
        path = request.url.path.substring(
          '/storage/v1/object/payment-proofs/'.length,
        );
        expect(
          path,
          startsWith('00000000-0000-0000-0000-000000000001/API-001/'),
        );
        return jsonResponse({'Key': 'payment-proofs/$path'});
      }
      expect(request.url.path, '/rest/v1/rpc/submit_payment');
      expect(jsonDecode(request.body), {
        'p_booking_id': 'API-001',
        'p_path': path,
      });
      return jsonResponse({...record, 'payment_path': path});
    });
    await api.signInCustomer('player@example.com', 'password');
    final booking = await api.uploadPayment(
      'API-001',
      Uint8List.fromList([255, 216, 255, 1]),
      'jpg',
    );
    expect(booking.status, BookingStatus.pending);
    expect(booking.paymentStatus, 'submitted');
    expect(booking.paymentPath, path);
  });
  test(
    'Oversized or invalid proof is rejected before any network request',
    () async {
      final api = apiFor(
        (_) async => throw StateError('Must not send request'),
      );
      await expectLater(
        api.uploadPayment('id', Uint8List(5 * 1024 * 1024 + 1), 'png'),
        throwsA(isA<BookingApiException>()),
      );
      await expectLater(
        api.uploadPayment('id', Uint8List(4), 'exe'),
        throwsA(isA<BookingApiException>()),
      );
    },
  );
  test(
    'Admin approval sends review RPC and preserves server payment result',
    () async {
      final api = apiFor((request) async {
        expect(request.url.path, '/rest/v1/rpc/review_payment');
        expect(jsonDecode(request.body), {
          'p_booking_id': 'API-001',
          'p_approve': true,
          'p_note': '',
        });
        return jsonResponse({
          ...bookingFixtures().first,
          'status': 'confirmed',
          'payment_status': 'approved',
        });
      });
      final b = await api.reviewPayment('API-001', true, '');
      expect(b.status, BookingStatus.confirmed);
      expect(b.paymentStatus, 'approved');
    },
  );
}
