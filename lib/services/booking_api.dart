import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';

class BookingApiException implements Exception {
  const BookingApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Uses the application's Supabase client; its owner manages disposal.
class BookingApi {
  BookingApi({
    this._client,
    this.configurationError,
    this.timeout = const Duration(seconds: 10),
  });

  final SupabaseClient? _client;
  final Duration timeout;
  final String? configurationError;

  bool get isConfigured => _client != null;
  String? get userId => _client?.auth.currentUser?.id;
  Future<bool> isAdmin() => _request(
    () async => await _configuredClient.rpc('is_booking_admin') == true,
  );
  Future<void> resendConfirmation(String email) => _request(() async {
    await _configuredClient.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  });

  Future<void> signInCustomer(String email, String password) =>
      _request(() async {
        await _configuredClient.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      });

  Future<bool> registerCustomer(
    String email,
    String password,
    String name,
    String phone,
  ) => _request(() async {
    final response = await _configuredClient.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'phone': phone.trim()},
    );
    return response.session != null;
  });

  Future<void> verifyEmail(
    String email,
    String token, {
    bool recovery = false,
  }) => _request(() async {
    await _configuredClient.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: recovery ? OtpType.recovery : OtpType.email,
    );
  });

  Future<void> resetPassword(String email) => _request(
    () => _configuredClient.auth.resetPasswordForEmail(email.trim()),
  );
  Future<void> setPassword(String password) => _request(() async {
    await _configuredClient.auth.updateUser(UserAttributes(password: password));
  });

  Future<Map<String, dynamic>> loadProfile() => _request(() async {
    final client = _configuredClient;
    final user = client.auth.currentUser;
    if (user == null) throw const BookingApiException('Silakan login kembali.');
    var profile = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) {
      final metadata = user.userMetadata ?? {};
      await saveProfile(
        metadata['name'] as String? ?? '',
        metadata['phone'] as String? ?? '',
      );
      profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
    }
    return profile;
  });

  Future<void> saveProfile(String name, String phone) => _request(() async {
    final client = _configuredClient;
    final id = client.auth.currentUser?.id;
    if (id == null) throw const BookingApiException('Silakan login kembali.');
    final values = {'id': id, 'name': name.trim(), 'phone': phone.trim()};
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    if (existing == null) {
      await client.from('profiles').insert(values);
    } else {
      await client
          .from('profiles')
          .update({'name': name.trim(), 'phone': phone.trim()})
          .eq('id', id);
    }
  });

  Future<Map<String, dynamic>> fetchSettings() => _request(
    () async => _configuredClient
        .from('venue_settings')
        .select()
        .eq('id', true)
        .single(),
  );
  Future<void> saveSettings(Map<String, dynamic> values) => _request(() async {
    await _configuredClient
        .from('venue_settings')
        .update(values)
        .eq('id', true)
        .select()
        .single();
  });
  Future<List<Map<String, dynamic>>> availability(DateTime date) =>
      _request(() async {
        final result = await _configuredClient.rpc(
          'get_availability',
          params: {'p_date': _date(date)},
        );
        return List<Map<String, dynamic>>.from(result as List);
      });
  Future<void> setSlotClosed(DateTime date, String hour, bool closed) =>
      _request(() async {
        await _configuredClient.rpc(
          'set_slot_closed',
          params: {'p_date': _date(date), 'p_hour': hour, 'p_closed': closed},
        );
      });
  Future<FieldBooking> createCustomerBooking(
    DateTime date,
    List<String> hours,
    String requestId,
  ) => _request(() async {
    final result = await _configuredClient
        .rpc(
          'create_booking',
          params: {
            'p_date': _date(date),
            'p_hours': hours,
            'p_request_id': requestId,
          },
        )
        .single();
    return _parseBooking(result);
  });
  Future<FieldBooking> cancelCustomerBooking(String id) => _request(
    () async => _parseBooking(
      await _configuredClient
          .rpc('cancel_customer_booking', params: {'p_booking_id': id})
          .single(),
    ),
  );

  Future<FieldBooking> uploadPayment(
    String id,
    Uint8List bytes,
    String extension,
  ) => _request(() async {
    if (bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        !['jpg', 'png'].contains(extension)) {
      throw const BookingApiException('Pilih gambar JPG/PNG maksimal 5 MB.');
    }
    final client = _configuredClient;
    final path =
        '${client.auth.currentUser!.id}/$id/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('payment-proofs')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return _parseBooking(
      await client
          .rpc('submit_payment', params: {'p_booking_id': id, 'p_path': path})
          .single(),
    );
  });
  Future<String> paymentUrl(String path) => _request(
    () => _configuredClient.storage
        .from('payment-proofs')
        .createSignedUrl(path, 120),
  );
  Future<FieldBooking> reviewPayment(String id, bool approve, String note) =>
      _request(
        () async => _parseBooking(
          await _configuredClient
              .rpc(
                'review_payment',
                params: {
                  'p_booking_id': id,
                  'p_approve': approve,
                  'p_note': note,
                },
              )
              .single(),
        ),
      );
  Future<void> requestAccountDeletion() => _request(() async {
    await _configuredClient.rpc('request_account_deletion');
  });
  String _date(DateTime date) => date.toIso8601String().substring(0, 10);

  SupabaseClient get _configuredClient =>
      _client ??
      (throw BookingApiException(
        configurationError ??
            'Konfigurasi Supabase belum diisi. Ikuti panduan pada README.',
      ));

  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    final client = _configuredClient;
    await _request(() async {
      final result = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      try {
        if (result.session == null ||
            await client.rpc('is_booking_admin').timeout(timeout) != true) {
          throw const BookingApiException(
            'Akun ini tidak memiliki akses admin booking.',
          );
        }
      } catch (_) {
        // GoTrue clears the local session before contacting the logout server.
        // Keep the role-check error if that server is unreachable.
        try {
          await client.auth.signOut().timeout(timeout);
        } catch (_) {}
        rethrow;
      }
    });
  }

  Future<void> signOutAdmin() async {
    final client = _client;
    if (client == null) return;
    await _request(() => client.auth.signOut());
  }

  Future<List<FieldBooking>> fetchBookings() => _fetchBookings();
  Future<List<FieldBooking>> fetchMyBookings() => _fetchBookings(ownOnly: true);

  Future<List<FieldBooking>> _fetchBookings({bool ownOnly = false}) async {
    final client = _configuredClient;
    final id = client.auth.currentUser?.id;
    if (ownOnly && id == null) {
      throw const BookingApiException('Silakan login kembali.');
    }
    const pageSize = 500;
    final bookings = <FieldBooking>[];
    // Explicit ranges also load records beyond Supabase's default 1,000 rows.
    for (var offset = 0; ; offset += pageSize) {
      final items = await _request(() async {
        var query = client
            .from('bookings')
            .select(
              'id,date,hours,customer_name,customer_phone,'
              'day_price,night_price,status,payment_path,payment_status,payment_note,customer_id',
            );
        if (ownOnly) query = query.eq('customer_id', id!);
        return query
            .order('date', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
      });
      bookings.addAll(items.map(_parseBooking));
      if (items.length < pageSize) break;
    }
    if (bookings.map((booking) => booking.id).toSet().length !=
        bookings.length) {
      throw const BookingApiException('Kode booking dari server duplikat.');
    }
    return bookings;
  }

  Future<FieldBooking> updateStatus(String id, BookingStatus status) async {
    final client = _configuredClient;
    final json = await _request(
      () async => client
          .rpc(
            'set_booking_status',
            params: {'p_booking_id': id, 'p_status': status.name},
          )
          .single(),
    );
    final booking = _parseBooking(json);
    if (booking.id == id && booking.status == status) return booking;
    throw const BookingApiException('Format perubahan booking tidak valid.');
  }

  FieldBooking _parseBooking(Object? json) {
    try {
      return FieldBooking.fromJson(json);
    } on FormatException catch (error) {
      throw BookingApiException(error.message);
    }
  }

  Future<T> _request<T>(Future<T> Function() send) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const BookingApiException(
        'Server terlalu lama merespons. Silakan coba lagi.',
      );
    } on http.ClientException {
      throw const BookingApiException(
        'Tidak dapat terhubung ke server booking. Periksa koneksi lalu coba lagi.',
      );
    } on AuthRetryableFetchException {
      throw const BookingApiException(
        'Tidak dapat terhubung ke Supabase. Periksa koneksi lalu coba lagi.',
      );
    } on AuthException catch (error) {
      if (error.code == 'over_email_send_rate_limit' ||
          error.message.toLowerCase().contains('email rate limit exceeded')) {
        throw const BookingApiException(
          'Batas pengiriman email sementara tercapai. Coba lagi nanti atau '
          'hubungi pengelola.',
        );
      }
      if (error.code == 'over_request_rate_limit') {
        throw const BookingApiException(
          'Terlalu banyak permintaan. Tunggu beberapa menit sebelum mencoba lagi.',
        );
      }
      if (error.code == 'email_address_not_authorized') {
        throw const BookingApiException(
          'Email verifikasi belum dapat dikirim ke alamat ini. Hubungi pengelola.',
        );
      }
      if (error.code == 'invalid_credentials' ||
          error.message.toLowerCase().contains('invalid login credentials')) {
        throw const BookingApiException('Email atau password tidak sesuai.');
      }
      throw BookingApiException(error.message);
    } on StorageException catch (error) {
      throw BookingApiException(
        'Bukti pembayaran gagal diproses: ${error.message}',
      );
    } on PostgrestException catch (error) {
      if (error.code == '200' || error.code == '201') {
        throw const BookingApiException(
          'Respons server bukan JSON yang valid.',
        );
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const BookingApiException(
          'Akses booking ditolak. Silakan masuk dengan akun admin.',
        );
      }
      throw BookingApiException(error.message);
    } on FormatException {
      throw const BookingApiException('Respons server bukan JSON yang valid.');
    } on TypeError {
      throw const BookingApiException('Format daftar booking tidak valid.');
    }
  }

  /// Supabase.instance owns this client and its shared authentication session.
  void close() {}
}
