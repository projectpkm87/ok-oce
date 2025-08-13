import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardStaff extends StatefulWidget {
  const DashboardStaff({super.key});

  @override
  State<DashboardStaff> createState() => _DashboardStaffState();
}

class _DashboardStaffState extends State<DashboardStaff> {
  int _selectedIndex = 0;
  String? cabangIdKamu; // akan diisi setelah login
  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Dashboard', 'icon': Icons.dashboard},
    {'label': 'Laporan Gaji', 'icon': Icons.insert_chart},
    {'label': 'Mato Karyawan', 'icon': Icons.pie_chart},
  ];

  String? staffName;
  String? staffEmail;
  String? _namaCabang;

  @override
  void initState() {
    super.initState();
    fetchStaffInfo();
  }

  Future<void> fetchStaffInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1) email dari auth
      final email = user.email;

      // 2) Ambil id_cabang & nama_cabang via join ke tabel cabang
      final row = await Supabase.instance.client
          .from('profiles')
          .select('nama, id_cabang, cabang!inner(nama_cabang)')
          .eq('id', user.id)
          .maybeSingle();

      final String? idCab = row?['id_cabang'];
      final String? namaCab = (row?['cabang']?['nama_cabang']) ?? row?['nama_cabang'];
      staffName = row?['nama'];

      if (mounted) {
        setState(() {
          staffEmail = email;     // untuk ditampilkan di Drawer
          _namaCabang = namaCab;  // untuk ditampilkan di header & Drawer
          cabangIdKamu = idCab;   // dipakai untuk query lain (gaji, mato, penjualan)
        });
      }
    } catch (e) {
      debugPrint('fetchStaffInfo error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, size: 34, color: Colors.black),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Image.asset('assets/logobg.png', height: 85),
                    const SizedBox(width: 10),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'SIMPANG ',
                            style: TextStyle(color: Colors.black, fontSize: 30),
                          ),
                          TextSpan(
                            text: 'RAYA',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'STAFF CABANG',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      (_namaCabang ?? '[nama_cabang]').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD1D1), Colors.white],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Cabang ${(_namaCabang ?? '[nama_cabang]').toUpperCase()}',
                    style: const TextStyle(color: Colors.black, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staffName ?? 'Memuat nama...',
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staffEmail ?? 'Memuat email...',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Beranda'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  Navigator.of(context).pushReplacementNamed('/login');
                });
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFFFFD1D1), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(_navItems.length, (index) {
                    return _buildNavButton(index);
                  }),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildPenghasilanViewer();
      case 1:
        return _buildLaporanGajiViewer();
      case 2:
        return _buildMatoViewer();
      default:
        return const Center(child: Text('Halaman tidak ditemukan'));
    }
  }

  Widget _buildNavButton(int index) {
    bool isSelected = _selectedIndex == index;
    return SizedBox(
      width: 220,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.red.shade100 : Colors.white,
          foregroundColor: Colors.black,
          elevation: isSelected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        onPressed: () => setState(() => _selectedIndex = index),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_navItems[index]['icon'], size: 20),
            const SizedBox(width: 8),
            Text(
              _navItems[index]['label'],
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// ====================== PERUBAHAN ADA DI SINI =========================
  Future<List<Map<String, dynamic>>> fetchPenjualan() async {
    final response = await supabase
        .from('penjualan')
        .select('tanggal,total')
        .eq('id_cabang', cabangIdKamu ?? '')
        .order('tanggal', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Widget _buildPenghasilanViewer() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchPenjualan(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Text("Belum ada data penjualan");
        }

        final spots = <FlSpot>[];
        for (var i = 0; i < data.length; i++) {
          spots.add(
            FlSpot(
              i.toDouble(),
              (data[i]['total'] ?? 0).toDouble(),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penghasilan Hari Ini',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Total Penjualan Hari Ini'),
              trailing: Text(
                NumberFormat.currency(locale: 'id', symbol: 'Rp ')
                    .format(data.last['total'] ?? 0),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Grafik Penjualan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.6,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= data.length) return const SizedBox();
                          final dateStr = data[value.toInt()]['tanggal'] ?? '';
                          final date = DateTime.tryParse(dateStr);
                          return Text(
                            date != null
                                ? DateFormat('dd/MM').format(date)
                                : '',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orange,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchGaji() async {
    final response =
    await supabase.from('gaji').select().eq('id_cabang', cabangIdKamu);
    return List<Map<String, dynamic>>.from(response);
  }

  Widget _buildLaporanGajiViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laporan Gaji Bulan Ini',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchGaji(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!;
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Jabatan')),
                    DataColumn(label: Text('Gaji')),
                  ],
                  rows: data.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['nama'] ?? '-')),
                      DataCell(Text(item['jabatan'] ?? '-')),
                      DataCell(Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ').format(item['gaji']))),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> fetchMato() async {
    final response =
    await supabase.from('mato').select().eq('id_cabang', cabangIdKamu);
    return List<Map<String, dynamic>>.from(response);
  }

  Widget _buildMatoViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi MATO',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchMato(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final matoList = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matoList.length,
              itemBuilder: (context, index) {
                final mato = matoList[index];
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text('${mato['nama_produk']} - ${mato['stok_awal']} Porsi'),
                  subtitle: Text('Terjual: ${mato['terjual']} | Sisa: ${mato['sisa']}'),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
