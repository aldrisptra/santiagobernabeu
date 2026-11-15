import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:santiago_bernabeu/models/booking.dart';
import 'package:santiago_bernabeu/services/booking_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<Map<String, dynamic>> bookingFixtures() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Map<String, dynamic> booking(
    String id,
    DateTime date,
    String hour,
    String name,
    String phone,
    String status,
  ) => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'hours': [hour],
    'customer_name': name,
    'customer_phone': phone,
    'day_price': 250000,
    'night_price': 350000,
    'status': status,
  };

  return [
    booking('API-001', today, '08:00', 'Budi', '081234567801', 'pending'),
    booking(
      'API-002',
      today.add(const Duration(days: 1)),
      '19:00',
      'Sinta',
      '081234567802',
      'confirmed',
    ),
    booking(
      'API-003',
      today.subtract(const Duration(days: 1)),
      '09:00',
      'Budi',
      '081234567801',
      'confirmed',
    ),
  ];
}

/// The test owns disposal; BookingApi shares its production Supabase client.
SupabaseClient mockSupabaseClient(MockClient client) {
  final supabase = SupabaseClient(
    'https://booking.test',
    'sb_publishable_test',
    httpClient: _ResponseRequestClient(client),
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _MemoryAuthStorage(),
    ),
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
  );
  addTearDown(() async {
    await supabase.dispose();
    client.close();
  });
  return supabase;
}

class _MemoryAuthStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

// PostgREST inspects the response's original request, as real HTTP clients do.
// MockClient only includes it when the fixture supplies it explicitly.
class _ResponseRequestClient extends http.BaseClient {
  _ResponseRequestClient(this.inner);

  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    return http.StreamedResponse(
      response.stream,
      response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
      request: response.request ?? request,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

BookingApi fakeBookingApi({void Function(http.Request request)? onRequest}) =>
    _FakeBookingApi(onRequest);

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this.onRequest);

  final void Function(http.Request request)? onRequest;
  final records = bookingFixtures();

  @override
  bool get isConfigured => true;

  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    if (email.trim() != 'admin@example.com' || password != 'admin123') {
      throw const BookingApiException(
        'Email atau password admin tidak sesuai.',
      );
    }
  }

  @override
  Future<void> signOutAdmin() async {}

  @override
  Future<List<FieldBooking>> fetchBookings() async {
    onRequest?.call(
      http.Request('GET', Uri.parse('https://booking.test/rest/v1/bookings')),
    );
    return records.map(FieldBooking.fromJson).toList();
  }

  @override
  Future<FieldBooking> updateStatus(String id, BookingStatus status) async {
    onRequest?.call(
      http.Request(
        'POST',
        Uri.parse('https://booking.test/rest/v1/rpc/set_booking_status'),
      )..body = jsonEncode({'p_booking_id': id, 'p_status': status.name}),
    );
    final record = records.firstWhere((record) => record['id'] == id);
    record['status'] = status.name;
    return FieldBooking.fromJson(record);
  }
}
