// Import library yang diperlukan:
// - async & convert: untuk operasi asinkron dan decoding JSON
// - material.dart: komponen UI Material Design Flutter
// - http: untuk request HTTP ke API jadwal sholat dan kalender Hijriyah
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Fungsi utama untuk menjalankan aplikasi
void main() {
  runApp(const MyApp());
}

// APP WRAPPER:
// Widget utama aplikasi yang mengatur tema, judul, dan halaman awal aplikasi
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadwal Sholat Yogyakarta', // Judul aplikasi
      theme: ThemeData(
        // Tema aplikasi dengan warna utama teal dan font Roboto
        colorScheme: ColorScheme.light(
          primary: Colors.teal,
          secondary: Colors.grey,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false, // Hilangkan banner debug
      home: const BottomNavWrapper(), // Halaman awal aplikasi
    );
  }
}

// BOTTOM NAV WRAPPER:
// Widget dengan bottom navigation bar untuk navigasi antar halaman (Sholat, Doa, Hijriyah)
class BottomNavWrapper extends StatefulWidget {
  const BottomNavWrapper({super.key});

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  int _selectedIndex = 0; // Menyimpan index tab yang aktif

  // Daftar halaman yang dihubungkan dengan bottom nav
  final List<Widget> _pages = [
    JadwalSholatPage(),   // Halaman jadwal sholat
    const DoaPage(),      // Halaman doa
    const HijriyahPage(), // Halaman kalender Hijriyah
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tampilkan halaman sesuai tab yang aktif
      body: _pages[_selectedIndex],
      // BottomNavigationBar untuk berpindah antar halaman
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // Update tab aktif
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Sholat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Doa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Hijriyah',
          ),
        ],
      ),
    );
  }
}

// JADWAL SHOLAT PAGE:
// Halaman yang menampilkan jadwal sholat untuk Yogyakarta
// Mengambil data dari API Aladhan dan menampilkan countdown menuju waktu sholat berikutnya
class JadwalSholatPage extends StatefulWidget {
  JadwalSholatPage({super.key});

  @override
  State<JadwalSholatPage> createState() => _JadwalSholatPageState();
}

class _JadwalSholatPageState extends State<JadwalSholatPage> {
  // Menyimpan data waktu sholat (nama -> waktu HH:mm)
  Map<String, String> prayerTimes = {};
  // Menyimpan nama sholat berikutnya
  String? nextPrayer;
  // Menyimpan durasi countdown ke sholat berikutnya
  Duration? countdown;
  // Timer untuk update countdown setiap detik
  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchPrayerTimes(); // Ambil jadwal sholat saat pertama kali halaman dimuat
  }

  @override
  void dispose() {
    timer?.cancel(); // Hentikan timer saat halaman dihancurkan
    super.dispose();
  }

  // Ambil data jadwal sholat dari API berdasarkan tanggal hari ini
  Future<void> fetchPrayerTimes() async {
    final now = DateTime.now();
    final url = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity/${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}?city=Yogyakarta&country=Indonesia&method=2');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = Map<String, String>.from(data['data']['timings']);
        setState(() {
          // Atur data waktu sholat ke dalam map prayerTimes
          prayerTimes = {
            'Imsak': timings['Imsak']!,
            'Subuh': timings['Fajr']!,
            'Terbit': timings['Sunrise']!,
            'Dhuha': timings['Dhuha'] ?? timings['Sunrise']!,
            'Dzuhur': timings['Dhuhr']!,
            'Ashar': timings['Asr']!,
            'Maghrib': timings['Maghrib']!,
            'Isya': timings['Isha']!,
          };
        });
        startCountdown(); // Mulai hitung mundur ke sholat berikutnya
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Hitung mundur ke sholat berikutnya, update setiap detik
  void startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      DateTime? nextTime;
      String? nextName;

      // Cari waktu sholat berikutnya
      for (var entry in prayerTimes.entries) {
        final parts = entry.value.split(':');
        final time = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        if (time.isAfter(now)) {
          nextTime = time;
          nextName = entry.key;
          break;
        }
      }

      // Kalau semua sudah lewat, set next ke Subuh esok hari
      if (nextTime == null) {
        final parts = prayerTimes['Subuh']!.split(':');
        nextTime = DateTime(now.year, now.month, now.day + 1,
            int.parse(parts[0]), int.parse(parts[1]));
        nextName = 'Subuh';
      }

      // Update UI dengan sholat berikutnya dan countdown
      setState(() {
        nextPrayer = nextName;
        countdown = nextTime!.difference(now);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      // Kalau data belum ada, tampilkan loading
      body: prayerTimes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          // Kalau data ada, tampilkan jadwal dan countdown
          : Column(
              children: [
                // Header dengan countdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.tealAccent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Yogyakarta, Indonesia',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$nextPrayer ${prayerTimes[nextPrayer] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        countdown != null
                            ? '${countdown!.inHours.toString().padLeft(2, '0')}:${(countdown!.inMinutes % 60).toString().padLeft(2, '0')}:${(countdown!.inSeconds % 60).toString().padLeft(2, '0')}'
                            : '--:--:--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // List jadwal sholat
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: prayerTimes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = prayerTimes.entries.elementAt(index);
                      final isNext = entry.key == nextPrayer;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: isNext
                              ? Border.all(color: primary, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  getIcon(entry.key),
                                  color: isNext ? primary : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // Mengembalikan icon sesuai nama sholat
  IconData getIcon(String prayerName) {
    switch (prayerName) {
      case 'Imsak':
        return Icons.access_time;
      case 'Subuh':
        return Icons.nightlight_round;
      case 'Terbit':
        return Icons.wb_sunny;
      case 'Dhuha':
        return Icons.wb_twilight;
      case 'Dzuhur':
        return Icons.wb_sunny_outlined;
      case 'Ashar':
        return Icons.cloud;
      case 'Maghrib':
        return Icons.brightness_6;
      case 'Isya':
        return Icons.nightlight;
      default:
        return Icons.access_time;
    }
  }
}

// DOA PAGE
class DoaPage extends StatelessWidget {
  const DoaPage({super.key});

  final List<Map<String, String>> doaList = const [
    {
      'arab': 'رَبِّ زِدْنِي عِلْمًا',
      'latin': 'Rabbi zidni ilma',
      'arti': 'Ya Tuhanku, tambahkanlah kepadaku ilmu.'
    },
    {
      'arab': 'اللّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ',
      'latin': 'Allahumma aj-‘alni minat-tawwabin',
      'arti': 'Ya Allah, jadikanlah aku termasuk orang-orang yang bertaubat.'
    },
    {
      'arab': 'اللّهُمَّ اغْفِرْلِي',
      'latin': 'Allahummaghfirli',
      'arti': 'Ya Allah, ampunilah aku.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: const Text(
              'Doa Harian',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    MediaQuery.of(context).size.width > 600 ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: doaList.length,
              itemBuilder: (context, index) {
                final doa = doaList[index];
                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              doa['arab']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              doa['latin']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              doa['arti']!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              doa['arab']!,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          doa['latin']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doa['arti']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// HIJRIYAH PAGE:
// Halaman yang menampilkan kalender Hijriyah hari ini dalam bentuk grid
// Mengambil data dari API Aladhan untuk konversi tanggal Masehi ke Hijriyah
// Menampilkan highlight untuk hari ini, Jumat, dan akhir pekan
class HijriyahPage extends StatefulWidget {
  const HijriyahPage({super.key});

  @override
  State<HijriyahPage> createState() => _HijriyahPageState();
}

class _HijriyahPageState extends State<HijriyahPage>
    with SingleTickerProviderStateMixin {
  
  // Fungsi untuk mengambil data tanggal Hijriyah dari API
  Future<Map<String, dynamic>> fetchHijriyahData() async {
    final now = DateTime.now();
    final url = Uri.parse(
        'https://api.aladhan.com/v1/gToH?date=${now.day}-${now.month}-${now.year}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['hijri'];
    } else {
      throw Exception('Gagal memuat tanggal Hijriyah');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      // FutureBuilder digunakan untuk menangani data asinkron dari API
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchHijriyahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Tampilkan loading saat data belum tersedia
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Tampilkan pesan error jika gagal ambil data
            return const Center(child: Text('Gagal memuat kalender'));
          } else {
            // Data berhasil didapat, tampilkan kalender
            final hijri = snapshot.data!;
            final now = DateTime.now();
            final todayHijriDay = hijri['day'];

            return Column(
              children: [
                // HEADER KALENDER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.tealAccent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tanggal Hijriyah
                      Text(
                        '${hijri['weekday']['en']}, ${hijri['day']} ${hijri['month']['en']} ${hijri['year']} H',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tanggal Masehi
                      Text(
                        '${_monthName(now.month)} ${now.day}, ${now.year}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildDayHeader(), // Header nama hari (Sun, Mon, dst)
                Expanded(
                  // GRID KALENDER: 7 kolom, 30 hari
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isToday = day.toString() == todayHijriDay;
                      final dayName = _dayName(index % 7);
                      final isFriday = dayName == 'Fri';
                      final isWeekend = dayName == 'Sat' || dayName == 'Sun';

                      return GestureDetector(
                        // Saat ditekan, tampilkan detail hari di bottom sheet
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (_) => _buildDetailSheet(day, dayName),
                          );
                        },
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 100),
                          scale: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday ? primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: isFriday
                                    ? Colors.orangeAccent
                                    : Colors.grey.shade300,
                                width: isToday ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Tampilkan angka hari
                                FittedBox(
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isToday
                                          ? Colors.white
                                          : isFriday
                                              ? Colors.orange
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Tampilkan nama hari
                                FittedBox(
                                  child: Text(
                                    dayName,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isToday
                                          ? Colors.white70
                                          : isWeekend
                                              ? Colors.blueAccent
                                              : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                // Tampilkan pasaran Jawa
                                FittedBox(
                                  child: Text(
                                    _pasaran(day),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isToday
                                          ? Colors.white60
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // BOTTOM SHEET DETAIL HARI
  Widget _buildDetailSheet(int day, String dayName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hari ke-$day',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hari: $dayName',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Pasaran: ${_pasaran(day)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // HEADER HARI (Sun, Mon, dst)
  static Widget _buildDayHeader() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: days.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Fungsi utilitas untuk nama bulan Masehi
  static String _monthName(int month) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return months[month];
  }

  // Fungsi utilitas untuk pasaran Jawa
  static String _pasaran(int day) {
    const pasaran = ['Legi', 'Pahing', 'Pon', 'Wage', 'Kliwon'];
    return pasaran[day % 5];
  }

  // Fungsi utilitas untuk nama hari (Sun, Mon, dst)
  static String _dayName(int index) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[index % 7];
  }
}