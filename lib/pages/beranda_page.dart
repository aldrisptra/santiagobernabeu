import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'notifications_page.dart';
import 'booking_detail_page.dart';
import '../services/booking_api.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key, required this.data, required this.onChanged});
  final DemoData data;
  final VoidCallback onChanged;

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  static const _namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _namaBulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  // Data dummy, nanti diganti dengan data dari backend.
  static const _jamOperasional = DemoData.hours;

  late final List<DateTime> _tanggal;
  int _tanggalDipilih = 0;
  // User bisa memilih lebih dari satu jam (tap lagi untuk membatalkan).
  final Set<String> _jamDipilih = {};
  bool _loading = true, _saving = false;
  String? _error;
  int _loadRevision = 0;

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.data.loadSettings();
      await widget.data.loadAvailability(_tanggal[_tanggalDipilih]);
    } on BookingApiException catch (e) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final hariIni = DateTime.now().toUtc().add(const Duration(hours: 8));
    _tanggal = List.generate(
      7,
      (i) => DateTime(hariIni.year, hariIni.month, hariIni.day + i),
    );
    _load();
  }

  int _hargaPerJam(String jam) {
    return widget.data.pricePerHour(jam);
  }

  String _formatRupiah(int nilai) {
    final s = nilai.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return 'Rp $buffer';
  }

  // Jam yang dipilih, diurutkan sesuai urutan jadwal.
  List<String> get _jamDipilihUrut =>
      _jamOperasional.where(_jamDipilih.contains).toList();

  int get _totalHarga =>
      _jamDipilih.fold(0, (total, jam) => total + _hargaPerJam(jam));

  void _toggleJam(String jam) {
    setState(() {
      if (!_jamDipilih.remove(jam)) _jamDipilih.add(jam);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildBanner(),
          const SizedBox(height: 24),
          _buildInfoLapangan(),
          const SizedBox(height: 24),
          const Text(
            'Pilih Tanggal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPilihTanggal(),
          const SizedBox(height: 24),
          const Text(
            'Jadwal Tersedia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
          _buildJadwal(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _jamDipilih.isEmpty || _loading || _saving || _error != null
                  ? null
                  : _konfirmasiBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _jamDipilih.isEmpty
                    ? 'Pilih jam terlebih dahulu'
                    : 'BOOKING ${_jamDipilih.length} JAM • ${_formatRupiah(_totalHarga)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Image.asset(
          'assets/images/icon_logo.png',
          height: 44,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.sports_soccer,
              size: 44,
              color: Colors.blue,
            );
          },
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                'Santiago Bernabéu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsPage(data: widget.data),
            ),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Main Bareng Tim Kamu!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Booking lapangan mini soccer kapan saja.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Image.asset('assets/images/icon_logo.png', height: 64),
        ],
      ),
    );
  }

  Widget _buildInfoLapangan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoItem(Icons.access_time, 'Buka', '08.00 - 23.00'),
          _infoItem(
            Icons.wb_sunny_outlined,
            'Siang',
            _formatRupiah(widget.data.dayPrice),
          ),
          _infoItem(
            Icons.nightlight_outlined,
            'Malam',
            _formatRupiah(widget.data.nightPrice),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPilihTanggal() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tanggal.length, (index) {
          final tgl = _tanggal[index];
          final dipilih = index == _tanggalDipilih;
          return GestureDetector(
            onTap: () {
              setState(() {
                _tanggalDipilih = index;
                _jamDipilih.clear();
              });
              _load();
            },
            child: Container(
              width: 60,
              height: 80,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: dipilih ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _namaHari[tgl.weekday - 1],
                    style: TextStyle(
                      color: dipilih ? Colors.white : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${tgl.day}',
                    style: TextStyle(
                      color: dipilih ? Colors.white : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _namaBulan[tgl.month - 1],
                    style: TextStyle(
                      color: dipilih ? Colors.white : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Jadwal disusun 3 kolom per baris menggunakan Column + Row.
  Widget _buildJadwal() {
    const kolom = 3;
    final baris = <Widget>[];
    for (var i = 0; i < _jamOperasional.length; i += kolom) {
      final isiBaris = <Widget>[];
      for (var j = i; j < i + kolom; j++) {
        if (j > i) isiBaris.add(const SizedBox(width: 10));
        isiBaris.add(
          Expanded(
            child: j < _jamOperasional.length
                ? _buildSlotJam(_jamOperasional[j])
                : const SizedBox(),
          ),
        );
      }
      if (i > 0) baris.add(const SizedBox(height: 10));
      baris.add(Row(children: isiBaris));
    }
    return Column(children: baris);
  }

  Widget _buildSlotJam(String jam) {
    final date = _tanggal[_tanggalDipilih];
    final past = DateTime.utc(
      date.year,
      date.month,
      date.day,
      int.parse(jam.substring(0, 2)),
    ).subtract(const Duration(hours: 8)).isBefore(DateTime.now().toUtc());
    // Contoh: hanya hari ini yang punya slot terisi.
    final terisi =
        past ||
        widget.data.blocked(_tanggal[_tanggalDipilih], jam) ||
        widget.data.occupied(_tanggal[_tanggalDipilih], jam);
    final dipilih = _jamDipilih.contains(jam);

    Color bg = Colors.white;
    Color fg = Colors.black;
    if (terisi) {
      bg = Colors.grey.shade300;
      fg = Colors.grey;
    } else if (dipilih) {
      bg = Colors.blue;
      fg = Colors.white;
    }

    return GestureDetector(
      onTap: terisi || _loading || _saving || _error != null
          ? null
          : () => _toggleJam(jam),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dipilih ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              jam,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              past
                  ? 'Sudah lewat'
                  : terisi
                  ? 'Terisi'
                  : 'Tersedia',
              style: TextStyle(color: fg, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _konfirmasiBooking() {
    final tgl = _tanggal[_tanggalDipilih];
    final jam = _jamDipilihUrut;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Booking'),
        content: Text(
          'Tanggal: ${_namaHari[tgl.weekday - 1]}, ${tgl.day} ${_namaBulan[tgl.month - 1]} ${tgl.year}\n'
          'Jam: ${jam.join(', ')}\n'
          'Durasi: ${jam.length} jam\n'
          'Total: ${_formatRupiah(_totalHarga)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_saving) return;
              setState(() => _saving = true);
              try {
                final booking = await widget.data.createBooking(tgl, jam);
                if (!mounted) return;
                setState(() => _jamDipilih.clear());
                await Navigator.push(
                  this.context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailPage(data: widget.data, booking: booking),
                  ),
                );
                if (mounted) widget.onChanged();
              } on BookingApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              } finally {
                if (mounted) {
                  setState(() => _saving = false);
                  _load();
                }
              }
            },
            child: const Text('Booking'),
          ),
        ],
      ),
    );
  }
}
