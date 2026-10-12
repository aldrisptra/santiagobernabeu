enum BookingStatus { pending, confirmed, cancelled }

class FieldBooking {
  FieldBooking({required this.id, required this.date, required this.hours});
  final String id;
  final DateTime date;
  final List<String> hours;
  BookingStatus status = BookingStatus.pending;
  int get total {
    int price = 0;
    for (final hour in hours) {
      price += int.parse(hour.substring(0, 2)) >= 17 ? 350000 : 250000;
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
