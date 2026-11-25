import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Manages the local SQLite database lifecycle, schema, and initial seed data.
class LocalDatabaseService {
  LocalDatabaseService({
    this.customPath,
    this.seedSampleData = true,
  });

  final String? customPath;
  final bool seedSampleData;

  static bool _ffiInitialized = false;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if ((Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
        !_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final String dbPath;
    if (customPath != null) {
      dbPath = customPath!;
    } else {
      final supportDir = await getApplicationSupportDirectory();
      await supportDir.create(recursive: true);
      dbPath = p.join(supportDir.path, 'papeleria_local.db');
    }

    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE app_settings ADD COLUMN dark_mode INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          "ALTER TABLE app_settings ADD COLUMN ncf_prefix TEXT NOT NULL DEFAULT 'B01'");
      await db.execute(
          'ALTER TABLE app_settings ADD COLUMN ncf_next_sequence INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          "ALTER TABLE app_settings ADD COLUMN ncf_valid_until TEXT NOT NULL DEFAULT '31/12/2026'");
      await db.execute(
          "ALTER TABLE sales ADD COLUMN customer_rnc TEXT NOT NULL DEFAULT ''");
      await db.execute(
          'ALTER TABLE sales ADD COLUMN is_fiscal INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          "ALTER TABLE sales ADD COLUMN ncf TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE sales ADD COLUMN ncf_type TEXT NOT NULL DEFAULT ''");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL,
        rnc TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        currency_symbol TEXT NOT NULL DEFAULT 'RD\$',
        tax_enabled INTEGER NOT NULL DEFAULT 1,
        tax_rate REAL NOT NULL DEFAULT 18.0,
        dark_mode INTEGER NOT NULL DEFAULT 0,
        ncf_prefix TEXT NOT NULL DEFAULT 'B01',
        ncf_next_sequence INTEGER NOT NULL DEFAULT 1,
        ncf_valid_until TEXT NOT NULL DEFAULT '31/12/2026'
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'unidad',
        cost_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        wholesale_min_qty INTEGER NOT NULL DEFAULT 12,
        stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        track_stock INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        rnc_or_id TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE design_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        technique TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_path TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL DEFAULT '',
        base_product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        product_name TEXT NOT NULL,
        technique TEXT NOT NULL,
        color_size TEXT NOT NULL DEFAULT '',
        custom_text TEXT NOT NULL DEFAULT '',
        design_notes TEXT NOT NULL DEFAULT '',
        design_image_path TEXT NOT NULL DEFAULT '',
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        deposit_paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'cotizado',
        due_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_order_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES custom_orders(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        product_name TEXT NOT NULL,
        quantity_used REAL NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
        customer_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        technique TEXT NOT NULL,
        base_cost REAL NOT NULL DEFAULT 0,
        supplies_cost REAL NOT NULL DEFAULT 0,
        labor_cost REAL NOT NULL DEFAULT 0,
        margin_percent REAL NOT NULL DEFAULT 40,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        valid_until TEXT NOT NULL,
        converted_order_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_amount REAL NOT NULL DEFAULT 0,
        closing_amount_expected REAL NOT NULL DEFAULT 0,
        closing_amount_counted REAL NOT NULL DEFAULT 0,
        difference REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'abierta',
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES cash_sessions(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
        customer_name TEXT NOT NULL DEFAULT 'Cliente general',
        customer_rnc TEXT NOT NULL DEFAULT '',
        is_fiscal INTEGER NOT NULL DEFAULT 0,
        ncf TEXT NOT NULL DEFAULT '',
        ncf_type TEXT NOT NULL DEFAULT '',
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'efectivo',
        amount_paid REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        cash_session_id INTEGER REFERENCES cash_sessions(id) ON DELETE SET NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'papeleria',
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.insert('app_settings', {
      'id': 1,
      'business_name': 'Papelería & Personalizados',
      'rnc': '',
      'phone': '809-555-0100',
      'address': 'Santo Domingo, RD',
      'currency_symbol': 'RD\$',
      'tax_enabled': 1,
      'tax_rate': 18.0,
    });

    if (seedSampleData) {
      await _seedInitialData(db);
    }
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final sampleProducts = [
      {
        'sku': 'PAP-001',
        'name': 'Cuaderno Cosido 100 Hojas',
        'category': 'papeleria',
        'unit': 'unidad',
        'cost_price': 65.0,
        'sale_price': 120.0,
        'wholesale_price': 95.0,
        'wholesale_min_qty': 12,
        'stock': 45.0,
        'min_stock': 10.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'PAP-002',
        'name': 'Lapicero Gel Negro 0.5mm',
        'category': 'papeleria',
        'unit': 'unidad',
        'cost_price': 15.0,
        'sale_price': 35.0,
        'wholesale_price': 25.0,
        'wholesale_min_qty': 12,
        'stock': 120.0,
        'min_stock': 20.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'PAP-003',
        'name': 'Resma Papel Bond 8.5x11',
        'category': 'papeleria',
        'unit': 'paquete',
        'cost_price': 240.0,
        'sale_price': 350.0,
        'wholesale_price': 310.0,
        'wholesale_min_qty': 5,
        'stock': 18.0,
        'min_stock': 5.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'PAP-004',
        'name': 'Cartulina Bristol Colores',
        'category': 'papeleria',
        'unit': 'pliego',
        'cost_price': 12.0,
        'sale_price': 25.0,
        'wholesale_price': 18.0,
        'wholesale_min_qty': 20,
        'stock': 8.0,
        'min_stock': 15.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'SRV-001',
        'name': 'Copia B/N Carta',
        'category': 'servicio',
        'unit': 'hoja',
        'cost_price': 1.5,
        'sale_price': 5.0,
        'wholesale_price': 3.5,
        'wholesale_min_qty': 50,
        'stock': 0.0,
        'min_stock': 0.0,
        'track_stock': 0,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'SRV-002',
        'name': 'Impresión Color Carta',
        'category': 'servicio',
        'unit': 'hoja',
        'cost_price': 8.0,
        'sale_price': 25.0,
        'wholesale_price': 18.0,
        'wholesale_min_qty': 25,
        'stock': 0.0,
        'min_stock': 0.0,
        'track_stock': 0,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'SRV-003',
        'name': 'Engargolado Espiral (hasta 100h)',
        'category': 'servicio',
        'unit': 'unidad',
        'cost_price': 25.0,
        'sale_price': 90.0,
        'wholesale_price': 75.0,
        'wholesale_min_qty': 10,
        'stock': 0.0,
        'min_stock': 0.0,
        'track_stock': 0,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'SRV-004',
        'name': 'Enmicado / Plastificado Carta',
        'category': 'servicio',
        'unit': 'hoja',
        'cost_price': 15.0,
        'sale_price': 60.0,
        'wholesale_price': 45.0,
        'wholesale_min_qty': 10,
        'stock': 0.0,
        'min_stock': 0.0,
        'track_stock': 0,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'BLK-001',
        'name': 'Taza Blanca 11 oz Sublimable',
        'category': 'blank',
        'unit': 'unidad',
        'cost_price': 95.0,
        'sale_price': 350.0,
        'wholesale_price': 280.0,
        'wholesale_min_qty': 12,
        'stock': 36.0,
        'min_stock': 12.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'BLK-002',
        'name': 'Termo Acero 20 oz Blanco',
        'category': 'blank',
        'unit': 'unidad',
        'cost_price': 320.0,
        'sale_price': 850.0,
        'wholesale_price': 720.0,
        'wholesale_min_qty': 6,
        'stock': 14.0,
        'min_stock': 5.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'BLK-003',
        'name': 'T-Shirt Poliéster/Algodón Blanco',
        'category': 'blank',
        'unit': 'unidad',
        'cost_price': 190.0,
        'sale_price': 550.0,
        'wholesale_price': 450.0,
        'wholesale_min_qty': 12,
        'stock': 22.0,
        'min_stock': 8.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'INS-001',
        'name': 'Papel de Sublimación A4',
        'category': 'insumo',
        'unit': 'hoja',
        'cost_price': 8.0,
        'sale_price': 20.0,
        'wholesale_price': 15.0,
        'wholesale_min_qty': 50,
        'stock': 180.0,
        'min_stock': 40.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
      {
        'sku': 'INS-002',
        'name': 'Vinil Textil Adhesivo (metro)',
        'category': 'insumo',
        'unit': 'metro',
        'cost_price': 140.0,
        'sale_price': 250.0,
        'wholesale_price': 210.0,
        'wholesale_min_qty': 5,
        'stock': 12.0,
        'min_stock': 4.0,
        'track_stock': 1,
        'is_active': 1,
        'created_at': now,
      },
    ];

    for (final pItem in sampleProducts) {
      await db.insert('products', pItem);
    }

    final customerId = await db.insert('customers', {
      'name': 'María Rodríguez',
      'phone': '809-555-0142',
      'email': 'maria.r@ejemplo.com',
      'rnc_or_id': '001-1234567-8',
      'notes': 'Cliente frecuente de eventos escolares',
      'created_at': now,
    });

    await db.insert('customers', {
      'name': 'Colegio Nuevo Horizonte',
      'phone': '809-555-0199',
      'email': 'compras@nuevohorizonte.edu.do',
      'rnc_or_id': '1-30-99881-2',
      'notes': 'Pedidos por volumen de tazas y libretas',
      'created_at': now,
    });

    await db.insert('design_templates', {
      'name': 'Graduación Dorado Minimal',
      'category': 'Escolar',
      'technique': 'Sublimación',
      'notes': 'Fuente serif + año + nombre del estudiante',
      'image_path': '',
      'created_at': now,
    });

    await db.insert('design_templates', {
      'name': 'Cumpleaños Floral Acuarela',
      'category': 'Cumpleaños',
      'technique': 'Sublimación',
      'notes': 'Ideal para tazas 11oz y termos',
      'image_path': '',
      'created_at': now,
    });

    final due = DateTime.now().add(const Duration(days: 2)).toIso8601String();
    await db.insert('custom_orders', {
      'order_number': 'PED-0001',
      'customer_id': customerId,
      'customer_name': 'María Rodríguez',
      'customer_phone': '809-555-0142',
      'base_product_id': 9,
      'product_name': 'Taza Blanca 11 oz Sublimable',
      'technique': 'Sublimación',
      'color_size': 'Blanca 11 oz',
      'custom_text': 'Feliz Día Profe Laura',
      'design_notes': 'Fondo floral pastel, letra cursiva dorada',
      'design_image_path': '',
      'quantity': 6,
      'unit_price': 350.0,
      'subtotal': 2100.0,
      'tax_amount': 378.0,
      'total': 2478.0,
      'deposit_paid': 1200.0,
      'status': 'en_produccion',
      'due_date': due,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
