enum BookingStatus { pending, confirmed, cancelled }

class FieldBooking {
  FieldBooking({
    required this.id,
    required this.date,
    required this.hours,
    this.customerName = 'Pemain',
    this.customerPhone = '',
    this.dayPrice = 250000,
    this.nightPrice = 350000,
    this.paymentPath,
    this.paymentStatus = 'unpaid',
    this.paymentNote = '',
    this.customerId,
  });

  factory FieldBooking.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'date': final String dateText,
      'hours': final List<dynamic> hours,
      'customer_name': final String customerName,
      'customer_phone': final String customerPhone,
      'day_price': final int dayPrice,
      'night_price': final int nightPrice,
      'status': final String statusText,
    }) {
      final date = DateTime.tryParse(dateText);
      final status = switch (statusText) {
        'pending' => BookingStatus.pending,
        'confirmed' => BookingStatus.confirmed,
        'cancelled' => BookingStatus.cancelled,
        _ => null,
      };
      final validHours =
          hours.isNotEmpty &&
          hours.every(
            (hour) =>
                hour is String &&
                RegExp(r'^([01][0-9]|2[0-3]):00$').hasMatch(hour),
          ) &&
          hours.toSet().length == hours.length;
      if (id.isNotEmpty &&
          date != null &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText) &&
          date.toIso8601String().substring(0, 10) == dateText &&
          status != null &&
          validHours &&
          dayPrice >= 0 &&
          nightPrice >= 0) {
        return FieldBooking(
          id: id,
          date: date,
          hours: List<String>.unmodifiable(hours.cast<String>()),
          customerName: customerName,
          customerPhone: customerPhone,
          dayPrice: dayPrice,
          nightPrice: nightPrice,
          paymentPath: (json as Map)['payment_path'] as String?,
          paymentStatus: json['payment_status'] as String? ?? 'unpaid',
          paymentNote: json['payment_note'] as String? ?? '',
          customerId: json['customer_id'] as String?,
        )..status = status;
      }
    }
    throw const FormatException('Data booking dari server tidak valid.');
  }
  final String customerName;
  final String? customerId;
  final String customerPhone;
  final int dayPrice;
  final int nightPrice;
  final String id;
  final DateTime date;
  final List<String> hours;
  BookingStatus status = BookingStatus.pending;
  String? paymentPath;
  String paymentStatus;
  String paymentNote;
  String get paymentLabel => switch (paymentStatus) {
    'submitted' => 'Menunggu verifikasi admin',
    'approved' => 'Pembayaran disetujui',
    'rejected' => 'Bukti ditolak: $paymentNote',
    _ => 'Belum mengirim bukti',
  };
  int get total {
    int price = 0;
    for (final hour in hours) {
      price += int.parse(hour.substring(0, 2)) >= 17 ? nightPrice : dayPrice;
    }
    return price;
  }

  String get statusLabel {
    if (status == BookingStatus.pending) return 'Menunggu pembayaran';
    if (status == BookingStatus.confirmed) return 'Terkonfirmasi';
    return 'Dibatalkan';
  }

  bool get isHistory =>
      status == BookingStatus.cancelled ||
      date.isBefore(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      );
}
