import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'kasir.db');
    return openDatabase(
      path,
      version: 2, // Naikkan versi
      onCreate: _onCreate,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('''
            CREATE TABLE settings(
              id INTEGER PRIMARY KEY,
              store_name TEXT,
              store_address TEXT,
              cashier_name TEXT,
              qris_path TEXT
            )
          ''');
          await db.insert('settings', {
            'id': 1,
            'store_name': 'Nama Toko Anda',
            'store_address': 'Alamat Toko',
            'cashier_name': 'Admin',
            'qris_path': '',
          });
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'barang'
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cashier TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        qty INTEGER NOT NULL,
        subtotal REAL NOT NULL
      )
    ''');
    // Tabel settings baru
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY,
        store_name TEXT,
        store_address TEXT,
        cashier_name TEXT,
        qris_path TEXT
      )
    ''');
    await db.insert('users', {'username': 'admin', 'password': 'admin', 'role': 'admin'});
    await db.insert('settings', {
      'id': 1,
      'store_name': 'Nama Toko Anda',
      'store_address': 'Alamat Toko',
      'cashier_name': 'Admin',
      'qris_path': '',
    });
  }
}