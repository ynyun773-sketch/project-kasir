import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart'; // <-- IMPORT BARU

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Daftar halaman (tambah ReportsScreen)
  final _pages = const [
    PosScreen(),
    ProductsScreen(),
    ReportsScreen(), // <-- TAB LAPORAN BARU
    SettingsScreen(),
  ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Array judul untuk AppBar
    final titles = ['Kasir', 'Produk', 'Laporan Harian', 'Advanced'];

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Produk'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Laporan'), // <-- ICON LAPORAN
          NavigationDestination(icon: Icon(Icons.settings), label: 'Advanced'),
        ],
      ),
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Keluar'),
        ],
      ),
    );
  }
}