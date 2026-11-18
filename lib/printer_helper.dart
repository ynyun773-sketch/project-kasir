import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';

class PrinterHelper {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Cetak Struk
  Future<void> printReceipt({
    required String storeName,
    required String storeAddress,
    required String cashierName,
    required String trxCode,
    required String date,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    required String deviceAddress, // MAC Address printer
  }) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected != true) {
        // Jika belum terhubung, coba hubungkan
        BluetoothDevice device = BluetoothDevice(deviceAddress, 'Printer');
        await bluetooth.connect(device);
      }

      // Mulai Cetak
      bluetooth.printCustom(storeName, 2, 1); // 2 = Ukuran besar, 1 = Rata tengah
      bluetooth.printCustom(storeAddress, 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('--------------------------------', 1, 1);
      
      bluetooth.printLeftRight('Kasir: $cashierName', trxCode, 1);
      bluetooth.printCustom('Waktu: $date', 1, 0);
      bluetooth.printCustom('--------------------------------', 1, 1);

      // Cetak Item
      for (var item in items) {
        bluetooth.printLeftRight(item['name'], _fmt.format(item['price']), 1);
        bluetooth.printLeftRight('  ${item['qty']} x', _fmt.format(item['subtotal']), 1);
      }
      
      bluetooth.printCustom('--------------------------------', 1, 1);
      bluetooth.printLeftRight('TOTAL', _fmt.format(total), 1);
      bluetooth.printLeftRight('BAYAR', paymentMethod.toUpperCase(), 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('Terima Kasih Atas Kunjungan Anda', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      
    } catch (e) {
      // ignore: avoid_print
      print("Error print: $e");
    }
  }
}