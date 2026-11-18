import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cashierCtrl = TextEditingController();
  String _qrisPath = '';
  
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDevices();
  }

  Future<void> _loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('settings', where: 'id = 1');
    if (rows.isNotEmpty) {
      setState(() {
        _nameCtrl.text = rows.first['store_name']?.toString() ?? '';
        _addressCtrl.text = rows.first['store_address']?.toString() ?? '';
        _cashierCtrl.text = rows.first['cashier_name']?.toString() ?? '';
        _qrisPath = rows.first['qris_path']?.toString() ?? '';
      });
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _loadingDevices = true);
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() => _devices = devices);
      
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('printer_address');
      if (savedAddress != null) {
        for (var dev in devices) {
          if (dev.address == savedAddress) {
            setState(() => _selectedDevice = dev);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat printer: $e"); // Menggunakan debugPrint, bukan print
    } finally {
      setState(() => _loadingDevices = false);
    }
  }

  Future<void> _pickQris() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final newPath = '${dir.path}/qris.jpg';
    final file = File(picked.path);
    await file.copy(newPath);
    
    setState(() => _qrisPath = newPath);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final db = await DatabaseHelper.instance.database;
    await db.update('settings', {
      'store_name': _nameCtrl.text.trim(),
      'store_address': _addressCtrl.text.trim(),
      'cashier_name': _cashierCtrl.text.trim(),
      'qris_path': _qrisPath,
    }, where: 'id = 1');
    
    if (_selectedDevice != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_address', _selectedDevice!.address!);
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan disimpan!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced / Pengaturan'), 
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings)
        ]
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Kop Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nama Toko', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Alamat Toko', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _cashierCtrl, decoration: const InputDecoration(labelText: 'Nama Kasir', border: OutlineInputBorder())),
          
          const SizedBox(height: 24),
          const Text('Pengaturan Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_loadingDevices)
            const Center(child: CircularProgressIndicator())
          else if (_devices.isEmpty)
            const Text('Tidak ada printer ditemukan. Pastikan Bluetooth menyala dan printer sudah di-pairing di pengaturan HP.')
          else
            DropdownButtonFormField<BluetoothDevice>(
              initialValue: _selectedDevice,
              decoration: const InputDecoration(labelText: 'Pilih Printer', border: OutlineInputBorder()),
              items: _devices.map((dev) {
                return DropdownMenuItem(
                  value: dev,
                  child: Text(dev.name ?? 'Unknown Device'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedDevice = val),
            ),
          
          const SizedBox(height: 24),
          const Text('QR Code Pembayaran (QRIS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_qrisPath.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                image: DecorationImage(image: FileImage(File(_qrisPath)), fit: BoxFit.contain),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _pickQris,
            icon: const Icon(Icons.photo),
            label: const Text('Pilih Foto QRIS dari Galeri'),
          ),
        ],
      ),
    );
  }
}