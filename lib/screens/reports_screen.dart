import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadTodayTransactions();
  }

  Future<void> _loadTodayTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'transactions',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'created_at DESC',
    );
    setState(() => _transactions = rows);
  }

  Future<void> _sharePdf() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum ada transaksi hari ini.')));
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final settings = await db.query('settings', where: 'id = 1');
    
    // INI BAGIAN YANG MEMBUAT ERROR SEBELUMNYA. SEKARANG SUDAH DIPERBAIKI.
    final storeName = settings.first['store_name']?.toString() ?? 'Toko';
    final storeAddress = settings.first['store_address']?.toString() ?? '';

    final pdf = pw.Document();
    double totalPendapatan = 0;
    for (var tx in _transactions) {
      totalPendapatan += (tx['total'] as num).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Laporan Harian', style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(storeName, style: const pw.TextStyle(fontSize: 16)),
                  pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 10),
                  pw.Text('Tanggal: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}'),
                  pw.Divider(),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: ['Waktu', 'Kode', 'Kasir', 'Metode', 'Total'],
              data: _transactions.map((tx) {
                final date = DateTime.parse(tx['created_at'].toString());
                return [
                  _dateFmt.format(date),
                  tx['code'].toString(),
                  tx['cashier'].toString(),
                  tx['payment_method'].toString().toUpperCase(),
                  _fmt.format(tx['total']),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Pendapatan: ${_fmt.format(totalPendapatan)}',
                style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/laporan_harian.pdf");
    await file.writeAsBytes(await pdf.save());

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Laporan Harian $storeName',
      text: 'Berikut adalah laporan transaksi tanggal ${DateFormat('dd/MM/yyyy').format(DateTime.now())}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _transactions.isEmpty
          ? const Center(child: Text('Belum ada transaksi hari ini.'))
          : ListView.separated(
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final tx = _transactions[i];
                final date = DateTime.parse(tx['created_at'].toString());
                return ListTile(
                  title: Text(tx['code'].toString()),
                  subtitle: Text('${_dateFmt.format(date)} • Kasir: ${tx['cashier']} • ${tx['payment_method']}'),
                  trailing: Text(
                    _fmt.format(tx['total']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sharePdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Ekspor PDF & Share'),
      ),
    );
  }
}