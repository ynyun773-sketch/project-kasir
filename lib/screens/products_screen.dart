import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _items = [];
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('products', orderBy: 'name');
    setState(() => _items = rows);
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final priceCtrl = TextEditingController(text: (item?['price'] ?? '').toString());
    final stockCtrl = TextEditingController(text: (item?['stock'] ?? '').toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Tambah Produk' : 'Edit Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga')),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stok')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (result != true) return;
    final db = await DatabaseHelper.instance.database;
    final data = {
      'name': nameCtrl.text.trim(),
      'price': double.tryParse(priceCtrl.text) ?? 0,
      'stock': int.tryParse(stockCtrl.text) ?? 0,
      'type': 'barang',
    };
    if (item == null) {
      await db.insert('products', data);
    } else {
      await db.update('products', data, where: 'id = ?', whereArgs: [item['id']]);
    }
    _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _items.isEmpty
        ? const Center(child: Text('Belum ada produk. Tambahkan dengan tombol +'))
        : ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = _items[i];
              return ListTile(
                title: Text(p['name']),
                subtitle: Text('${_fmt.format(p['price'])} • Stok: ${p['stock']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(p)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(p['id'])),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}