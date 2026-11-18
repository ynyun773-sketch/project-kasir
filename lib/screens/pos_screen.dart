import 'dart:io'; // Tambahan untuk QRIS
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../printer_helper.dart'; // Tambahan untuk Printer

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Map<String, dynamic>> _products = [];
  final Map<int, int> _cart = {}; // productId -> qty
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('products', orderBy: 'name');
    setState(() {
      _products = rows;
      _cart.removeWhere((id, _) => !rows.any((p) => p['id'] == id));
    });
  }

  double get _total {
    double t = 0;
    _cart.forEach((id, qty) {
      final p = _products.firstWhere((e) => e['id'] == id);
      t += (p['price'] as num).toDouble() * qty;
    });
    return t;
  }

  void _add(Map<String, dynamic> p) {
    final current = _cart[p['id']] ?? 0;
    if (current >= (p['stock'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok habis')));
      return;
    }
    setState(() => _cart[p['id']] = current + 1);
  }

  void _remove(Map<String, dynamic> p) {
    final current = _cart[p['id']] ?? 0;
    if (current <= 1) {
      setState(() => _cart.remove(p['id']));
    } else {
      setState(() => _cart[p['id']] = current - 1);
    }
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    
    // 1. Pilih Metode Pembayaran
    final method = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Metode Pembayaran'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'tunai'),
            child: const ListTile(leading: Icon(Icons.payments), title: Text('Tunai')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'qris'),
            child: const ListTile(leading: Icon(Icons.qr_code), title: Text('QRIS / Non-Tunai')),
          ),
        ],
      ),
    );
    if (method == null) return;

    // 2. Jika QRIS, tampilkan gambar QRIS
    if (method == 'qris') {
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query('settings', where: 'id = 1');
      final qrisPath = settings.isNotEmpty ? (settings.first['qris_path']?.toString() ?? '') : '';

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Scan QRIS'),
          content: qrisPath.isNotEmpty
              ? Image.file(File(qrisPath), height: 300, fit: BoxFit.contain)
              : const Text('Gambar QRIS belum diatur di menu Advanced.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai Bayar'),
            ),
          ],
        ),
      );
    }

    final db = await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();
    final cashier = prefs.getString('current_user') ?? 'admin';
    final now = DateTime.now();
    final code = 'TRX${now.millisecondsSinceEpoch}';
    
    // PENTING: Simpan data keranjang ke variabel sementara agar tidak hilang saat di-clear
    final Map<int, int> currentCart = Map.from(_cart);
    final double currentTotal = _total;

    // 3. Simpan Transaksi ke Database
    final txId = await db.insert('transactions', {
      'code': code,
      'total': currentTotal,
      'payment_method': method,
      'cashier': cashier,
      'created_at': now.toIso8601String(),
    });

    for (final entry in currentCart.entries) {
      final p = _products.firstWhere((e) => e['id'] == entry.key);
      await db.insert('transaction_items', {
        'transaction_id': txId,
        'product_id': p['id'],
        'product_name': p['name'],
        'price': p['price'],
        'qty': entry.value,
        'subtotal': (p['price'] as num) * entry.value,
      });
      
      // Kurangi stok HANYA jika tipenya 'barang'
      if (p['type'] == 'barang') {
        await db.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?',
          [entry.value, p['id']]);
      }
    }

    // Kosongkan keranjang dan refresh tampilan
    setState(() => _cart.clear());
    await _load();
    if (!mounted) return;

    // 4. Dialog Cetak Struk
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transaksi Berhasil'),
        content: Text('Total: ${_fmt.format(currentTotal)}\nKode: $code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak Cetak'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog
              
              // Cek apakah printer sudah diatur
              final prefs = await SharedPreferences.getInstance();
              final printerAddress = prefs.getString('printer_address');
              
              if (printerAddress == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Printer belum diatur di menu Advanced!')));
                return;
              }

              final db = await DatabaseHelper.instance.database;
              final settings = await db.query('settings', where: 'id = 1');
              
              // Siapkan data item untuk dicetak
              List<Map<String, dynamic>> printItems = [];
              for (final entry in currentCart.entries) {
                final p = _products.firstWhere((e) => e['id'] == entry.key);
                printItems.add({
                  'name': p['name'],
                  'price': p['price'],
                  'qty': entry.value,
                  'subtotal': (p['price'] as num) * entry.value,
                });
              }

              // Panggil fungsi cetak dari PrinterHelper
              if (!mounted) return;
              await PrinterHelper().printReceipt(
                storeName: settings.first['store_name']?.toString() ?? 'Toko',
                storeAddress: settings.first['store_address']?.toString() ?? '',
                cashierName: cashier,
                trxCode: code,
                date: DateFormat('dd/MM/yyyy HH:mm').format(now),
                items: printItems,
                total: currentTotal,
                paymentMethod: method,
                deviceAddress: printerAddress,
              );
            },
            child: const Text('Cetak Struk'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty) {
      return const Center(child: Text('Belum ada produk. Tambahkan dulu di tab Produk.'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = _products[i];
              final qty = _cart[p['id']] ?? 0;
              final outOfStock = p['type'] == 'barang' && (p['stock'] as int) <= 0;
              
              return Card(
                child: ListTile(
                  title: Text(p['name']),
                  subtitle: Text('${_fmt.format(p['price'])} • ${p['type'] == 'barang' ? 'Stok: ${p['stock']}' : 'Jasa'}'),
                  trailing: qty == 0
                    ? FilledButton.tonal(
                        onPressed: outOfStock ? null : () => _add(p),
                        child: const Icon(Icons.add),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _remove(p)),
                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add_circle_outline),
                            onPressed: outOfStock ? null : () => _add(p)),
                        ],
                      ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 12)),
                    Text(_fmt.format(_total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _cart.isEmpty ? null : _checkout,
                icon: const Icon(Icons.point_of_sale),
                label: Text('Bayar (${_cart.values.fold(0, (a, b) => a + b)})'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}