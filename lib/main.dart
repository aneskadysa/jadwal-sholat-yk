import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// APP WRAPPER
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadwal Sholat Yogyakarta',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.teal,
          secondary: Colors.grey,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const BottomNavWrapper(),
    );
  }
}

// BOTTOM NAV WRAPPER
class BottomNavWrapper extends StatefulWidget {
  const BottomNavWrapper({super.key});

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    JadwalSholatPage(),
    const DoaPage(),
    const HijriyahPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Sholat'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Doa'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Hijriyah'),
        ],
      ),
    );
  }
}

// JADWAL SHOLAT PAGE
class JadwalSholatPage extends StatefulWidget {
  JadwalSholatPage({super.key});

  @override
  State<JadwalSholatPage> createState() => _JadwalSholatPageState();
}

class _JadwalSholatPageState extends State<JadwalSholatPage> {
  Map<String, String> prayerTimes = {};
  String? nextPrayer;
  Duration? countdown;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchPrayerTimes();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

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
        startCountdown();
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      DateTime? nextTime;
      String? nextName;

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

      if (nextTime == null) {
        final parts = prayerTimes['Subuh']!.split(':');
        nextTime = DateTime(now.year, now.month, now.day + 1,
            int.parse(parts[0]), int.parse(parts[1]));
        nextName = 'Subuh';
      }

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
      body: prayerTimes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
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

// HIJRIYAH PAGE
class HijriyahPage extends StatefulWidget {
  const HijriyahPage({super.key});

  @override
  State<HijriyahPage> createState() => _HijriyahPageState();
}

class _HijriyahPageState extends State<HijriyahPage>
    with SingleTickerProviderStateMixin {
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchHijriyahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Gagal memuat kalender'));
          } else {
            final hijri = snapshot.data!;
            final now = DateTime.now();
            final todayHijriDay = hijri['day'];

            return Column(
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
                  child: Column(
                    children: [
                      Text(
                        '${hijri['weekday']['en']}, ${hijri['day']} ${hijri['month']['en']} ${hijri['year']} H',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                _buildDayHeader(),
                Expanded(
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

  static String _pasaran(int day) {
    const pasaran = ['Legi', 'Pahing', 'Pon', 'Wage', 'Kliwon'];
    return pasaran[day % 5];
  }

  static String _dayName(int index) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[index % 7];
  }
}
