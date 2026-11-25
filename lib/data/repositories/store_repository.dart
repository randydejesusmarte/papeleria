import '../../domain/models/app_settings.dart';
import '../../domain/models/cash_register.dart';
import '../../domain/models/custom_order.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/sale.dart';
import '../services/local_database_service.dart';

/// Aggregated financial and operational metrics for the Reports dashboard.
class StoreReportSummary {
  const StoreReportSummary({
    required this.totalSales,
    required this.stationerySales,
    required this.serviceSales,
    required this.customOrderSales,
    required this.estimatedProfit,
    required this.totalExpenses,
    required this.accountsReceivable,
    required this.pendingOrdersCount,
    required this.lowStockCount,
    required this.topProducts,
  });

  final double totalSales;
  final double stationerySales;
  final double serviceSales;
  final double customOrderSales;
  final double estimatedProfit;
  final double totalExpenses;
  final double accountsReceivable;
  final int pendingOrdersCount;
  final int lowStockCount;
  final List<TopProductRow> topProducts;
}

class TopProductRow {
  const TopProductRow({
    required this.name,
    required this.quantitySold,
    required this.revenue,
  });

  final String name;
  final double quantitySold;
  final double revenue;
}

/// Single source of truth for all SQLite queries and business transactions.
class StoreRepository {
  StoreRepository({required this._dbService});

  final LocalDatabaseService _dbService;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  Future<AppSettings> getSettings() async {
    final db = await _dbService.database;
    final rows = await db.query('app_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return AppSettings.defaults;
    return AppSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await _dbService.database;
    await db.update(
      'app_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  // ---------------------------------------------------------------------------
  // Products & Dual Inventory
  // ---------------------------------------------------------------------------
  Future<List<Product>> getProducts({bool activeOnly = true}) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> saveProduct(Product product) async {
    final db = await _dbService.database;
    if (product.id == null) {
      return db.insert('products', product.toMap());
    }
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    return product.id!;
  }

  Future<void> adjustStock(int productId, double delta) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      'UPDATE products SET stock = MAX(0, stock + ?) WHERE id = ? AND track_stock = 1',
      [delta, productId],
    );
  }

  Future<void> deleteProduct(int productId) async {
    final db = await _dbService.database;
    await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ---------------------------------------------------------------------------
  // Customers & Design Templates
  // ---------------------------------------------------------------------------
  Future<List<Customer>> getCustomers() async {
    final db = await _dbService.database;
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> saveCustomer(Customer customer) async {
    final db = await _dbService.database;
    if (customer.id == null) {
      return db.insert('customers', customer.toMap());
    }
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    return customer.id!;
  }

  Future<void> deleteCustomer(int id) async {
    final db = await _dbService.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DesignTemplate>> getDesignTemplates() async {
    final db = await _dbService.database;
    final rows = await db.query('design_templates', orderBy: 'created_at DESC');
    return rows.map(DesignTemplate.fromMap).toList();
  }

  Future<int> saveDesignTemplate(DesignTemplate template) async {
    final db = await _dbService.database;
    if (template.id == null) {
      return db.insert('design_templates', template.toMap());
    }
    await db.update(
      'design_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
    return template.id!;
  }

  Future<void> deleteDesignTemplate(int id) async {
    final db = await _dbService.database;
    await db.delete('design_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Custom Orders
  // ---------------------------------------------------------------------------
  Future<List<CustomOrder>> getCustomOrders() async {
    final db = await _dbService.database;
    final rows = await db.query(
      'custom_orders',
      orderBy: 'due_date ASC, id DESC',
    );
    return rows.map(CustomOrder.fromMap).toList();
  }

  Future<String> generateNextOrderNumber() async {
    final db = await _dbService.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM custom_orders');
    final count = (rows.first['cnt'] as int?) ?? 0;
    return 'PED-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<int> saveCustomOrder(
    CustomOrder order, {
    bool deductBaseProductStock = false,
  }) async {
    final db = await _dbService.database;
    return db.transaction((txn) async {
      int orderId;
      if (order.id == null) {
        orderId = await txn.insert('custom_orders', order.toMap());
        if (deductBaseProductStock && order.baseProductId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock = MAX(0, stock - ?) WHERE id = ? AND track_stock = 1',
            [order.quantity.toDouble(), order.baseProductId],
          );
        }
      } else {
        orderId = order.id!;
        await txn.update(
          'custom_orders',
          order.toMap(),
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }
      return orderId;
    });
  }

  Future<void> updateOrderStatus(int orderId, OrderStatus status) async {
    final db = await _dbService.database;
    await db.update(
      'custom_orders',
      {
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> recordOrderPayment({
    required CustomOrder order,
    required double paymentAmount,
    required PaymentMethod paymentMethod,
    int? cashSessionId,
  }) async {
    if (paymentAmount <= 0) return;
    final db = await _dbService.database;
    final now = DateTime.now();
    final receiptNumber = await generateNextReceiptNumber();

    await db.transaction((txn) async {
      final newDeposit = order.depositPaid + paymentAmount;
      final isFullyPaid = newDeposit >= order.total - 0.01;
      final nextStatus = order.status == OrderStatus.cotizado
          ? OrderStatus.conAnticipo
          : order.status;

      await txn.update(
        'custom_orders',
        {
          'deposit_paid': newDeposit,
          'status': isFullyPaid && order.status == OrderStatus.listo
              ? OrderStatus.entregado.value
              : nextStatus.value,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      final saleId = await txn.insert('sales', {
        'receipt_number': receiptNumber,
        'customer_id': order.customerId,
        'customer_name': order.customerName,
        'subtotal': paymentAmount,
        'discount': 0.0,
        'tax_amount': 0.0,
        'total': paymentAmount,
        'payment_method': paymentMethod.value,
        'amount_paid': paymentAmount,
        'change_amount': 0.0,
        'cash_session_id': cashSessionId,
        'notes': 'Abono pedido ${order.orderNumber}',
        'created_at': now.toIso8601String(),
      });

      await txn.insert('sale_items', {
        'sale_id': saleId,
        'product_id': order.baseProductId,
        'description': 'Abono ${order.orderNumber}: ${order.productName}',
        'category': 'personalizado',
        'quantity': 1.0,
        'unit_price': paymentAmount,
        'cost_price': 0.0,
        'total': paymentAmount,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Quotes
  // ---------------------------------------------------------------------------
  Future<List<Quote>> getQuotes() async {
    final db = await _dbService.database;
    final rows = await db.query('quotes', orderBy: 'created_at DESC');
    return rows.map(Quote.fromMap).toList();
  }

  Future<String> generateNextQuoteNumber() async {
    final db = await _dbService.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM quotes');
    final count = (rows.first['cnt'] as int?) ?? 0;
    return 'COT-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<int> saveQuote(Quote quote) async {
    final db = await _dbService.database;
    if (quote.id == null) {
      return db.insert('quotes', quote.toMap());
    }
    await db.update(
      'quotes',
      quote.toMap(),
      where: 'id = ?',
      whereArgs: [quote.id],
    );
    return quote.id!;
  }

  Future<int> convertQuoteToOrder(Quote quote) async {
    final orderNumber = await generateNextOrderNumber();
    final now = DateTime.now();
    final order = CustomOrder(
      orderNumber: orderNumber,
      customerId: quote.customerId,
      customerName: quote.customerName,
      productName: quote.productName,
      technique: quote.technique,
      designNotes: quote.notes,
      quantity: quote.quantity,
      unitPrice: quote.unitPrice,
      subtotal: quote.subtotal,
      taxAmount: quote.taxAmount,
      total: quote.total,
      depositPaid: 0,
      status: OrderStatus.cotizado,
      dueDate: now.add(const Duration(days: 3)),
      createdAt: now,
      updatedAt: now,
    );
    final orderId = await saveCustomOrder(order);
    if (quote.id != null) {
      final db = await _dbService.database;
      await db.update(
        'quotes',
        {'converted_order_id': orderId},
        where: 'id = ?',
        whereArgs: [quote.id],
      );
    }
    return orderId;
  }

  // ---------------------------------------------------------------------------
  // POS Sales
  // ---------------------------------------------------------------------------
  Future<String> generateNextReceiptNumber() async {
    final db = await _dbService.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM sales');
    final count = (rows.first['cnt'] as int?) ?? 0;
    return 'FAC-${(count + 1).toString().padLeft(5, '0')}';
  }

  Future<Sale> completeSale(Sale sale) async {
    final db = await _dbService.database;
    String assignedNcf = sale.ncf;

    final saleId = await db.transaction((txn) async {
      if (sale.isFiscal && assignedNcf.isEmpty) {
        final settingsRows =
            await txn.query('app_settings', where: 'id = 1', limit: 1);
        final prefix = sale.ncfType.isNotEmpty
            ? sale.ncfType
            : ((settingsRows.firstOrNull?['ncf_prefix'] as String?) ?? 'B01');
        final seq =
            (settingsRows.firstOrNull?['ncf_next_sequence'] as int?) ?? 1;
        assignedNcf = '$prefix${seq.toString().padLeft(8, '0')}';

        await txn.update(
          'app_settings',
          {'ncf_next_sequence': seq + 1},
          where: 'id = 1',
        );
      }

      final saleToInsert = Sale(
        receiptNumber: sale.receiptNumber,
        customerId: sale.customerId,
        customerName: sale.customerName,
        customerRnc: sale.customerRnc,
        isFiscal: sale.isFiscal,
        ncf: assignedNcf,
        ncfType: sale.ncfType,
        subtotal: sale.subtotal,
        discount: sale.discount,
        taxAmount: sale.taxAmount,
        total: sale.total,
        paymentMethod: sale.paymentMethod,
        amountPaid: sale.amountPaid,
        changeAmount: sale.changeAmount,
        cashSessionId: sale.cashSessionId,
        notes: sale.notes,
        createdAt: sale.createdAt,
        items: sale.items,
      );

      final insertedId = await txn.insert('sales', saleToInsert.toMap());
      for (final item in sale.items) {
        await txn.insert('sale_items', item.toMap(insertedId));
        if (item.productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock = MAX(0, stock - ?) WHERE id = ? AND track_stock = 1',
            [item.quantity, item.productId],
          );
        }
      }
      return insertedId;
    });

    return Sale(
      id: saleId,
      receiptNumber: sale.receiptNumber,
      customerId: sale.customerId,
      customerName: sale.customerName,
      customerRnc: sale.customerRnc,
      isFiscal: sale.isFiscal,
      ncf: assignedNcf,
      ncfType: sale.ncfType,
      subtotal: sale.subtotal,
      discount: sale.discount,
      taxAmount: sale.taxAmount,
      total: sale.total,
      paymentMethod: sale.paymentMethod,
      amountPaid: sale.amountPaid,
      changeAmount: sale.changeAmount,
      cashSessionId: sale.cashSessionId,
      notes: sale.notes,
      createdAt: sale.createdAt,
      items: sale.items,
    );
  }

  Future<List<Sale>> getRecentSales({int limit = 50}) async {
    final db = await _dbService.database;
    final saleRows = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final results = <Sale>[];
    for (final row in saleRows) {
      final id = row['id'] as int;
      final itemRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [id],
      );
      results.add(
        Sale.fromMap(row, itemRows.map(SaleItem.fromMap).toList()),
      );
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Cash Register (Caja)
  // ---------------------------------------------------------------------------
  Future<CashSession?> getOpenCashSession() async {
    final db = await _dbService.database;
    final rows = await db.query(
      'cash_sessions',
      where: "status = 'abierta'",
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashSession.fromMap(rows.first);
  }

  Future<List<CashSession>> getCashSessions({int limit = 20}) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'cash_sessions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(CashSession.fromMap).toList();
  }

  Future<CashSession> openCashSession(double openingAmount) async {
    final db = await _dbService.database;
    final session = CashSession(
      openedAt: DateTime.now(),
      openingAmount: openingAmount,
      status: 'abierta',
    );
    final id = await db.insert('cash_sessions', session.toMap());
    return CashSession(
      id: id,
      openedAt: session.openedAt,
      openingAmount: openingAmount,
      status: 'abierta',
    );
  }

  Future<List<CashMovement>> getMovementsForSession(int sessionId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'cash_movements',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CashMovement.fromMap).toList();
  }

  Future<void> addCashMovement(CashMovement movement) async {
    final db = await _dbService.database;
    await db.insert('cash_movements', movement.toMap());
  }

  Future<double> computeExpectedCashInSession(CashSession session) async {
    final db = await _dbService.database;
    final cashSalesRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales WHERE cash_session_id = ? AND payment_method = 'efectivo'",
      [session.id],
    );
    final cashSales = ((cashSalesRows.first['total'] as num?) ?? 0).toDouble();

    final movRows = await db.query(
      'cash_movements',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );

    double delta = 0;
    for (final m in movRows) {
      final type = m['type'] as String? ?? 'gasto';
      final amount = ((m['amount'] as num?) ?? 0).toDouble();
      if (type == 'ingreso') {
        delta += amount;
      } else {
        delta -= amount;
      }
    }

    return session.openingAmount + cashSales + delta;
  }

  Future<void> closeCashSession({
    required CashSession session,
    required double countedAmount,
    String notes = '',
  }) async {
    final db = await _dbService.database;
    final expected = await computeExpectedCashInSession(session);
    final diff = countedAmount - expected;
    await db.update(
      'cash_sessions',
      {
        'closed_at': DateTime.now().toIso8601String(),
        'closing_amount_expected': expected,
        'closing_amount_counted': countedAmount,
        'difference': diff,
        'status': 'cerrada',
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------
  Future<StoreReportSummary> getReportSummary({int days = 30}) async {
    final db = await _dbService.database;
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final salesTotals = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM sales WHERE created_at >= ?',
      [since],
    );
    final totalSales = ((salesTotals.first['total'] as num?) ?? 0).toDouble();

    final catRows = await db.rawQuery('''
      SELECT si.category, COALESCE(SUM(si.total), 0) AS rev,
             COALESCE(SUM(si.total - (si.cost_price * si.quantity)), 0) AS profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ?
      GROUP BY si.category
    ''', [since]);

    double stationery = 0;
    double services = 0;
    double custom = 0;
    double profit = 0;

    for (final row in catRows) {
      final cat = (row['category'] as String?) ?? 'papeleria';
      final rev = ((row['rev'] as num?) ?? 0).toDouble();
      final p = ((row['profit'] as num?) ?? 0).toDouble();
      profit += p;
      if (cat == 'servicio') {
        services += rev;
      } else if (cat == 'personalizado') {
        custom += rev;
      } else {
        stationery += rev;
      }
    }

    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM cash_movements WHERE type IN ('gasto', 'retiro') AND created_at >= ?",
      [since],
    );
    final totalExpenses =
        ((expenseRows.first['total'] as num?) ?? 0).toDouble();

    final receivableRows = await db.rawQuery('''
      SELECT COALESCE(SUM(MAX(0, total - deposit_paid)), 0) AS pending,
             COUNT(*) AS cnt
      FROM custom_orders
      WHERE status NOT IN ('entregado', 'cancelado')
    ''');
    final accountsReceivable =
        ((receivableRows.first['pending'] as num?) ?? 0).toDouble();
    final pendingOrdersCount = (receivableRows.first['cnt'] as int?) ?? 0;

    final lowStockRows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM products WHERE is_active = 1 AND track_stock = 1 AND stock <= min_stock',
    );
    final lowStockCount = (lowStockRows.first['cnt'] as int?) ?? 0;

    final topRows = await db.rawQuery('''
      SELECT si.description AS name,
             COALESCE(SUM(si.quantity), 0) AS qty,
             COALESCE(SUM(si.total), 0) AS rev
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ?
      GROUP BY si.description
      ORDER BY rev DESC
      LIMIT 8
    ''', [since]);

    final topProducts = topRows
        .map(
          (r) => TopProductRow(
            name: (r['name'] as String?) ?? '',
            quantitySold: ((r['qty'] as num?) ?? 0).toDouble(),
            revenue: ((r['rev'] as num?) ?? 0).toDouble(),
          ),
        )
        .toList();

    return StoreReportSummary(
      totalSales: totalSales,
      stationerySales: stationery,
      serviceSales: services,
      customOrderSales: custom,
      estimatedProfit: profit,
      totalExpenses: totalExpenses,
      accountsReceivable: accountsReceivable,
      pendingOrdersCount: pendingOrdersCount,
      lowStockCount: lowStockCount,
      topProducts: topProducts,
    );
  }

  // ---------------------------------------------------------------------------
  // Maintenance / Reset
  // ---------------------------------------------------------------------------
  /// Clears all operational data from the local SQLite database.
  /// When [keepSettings] is true, business info and tax settings are preserved
  /// while the NCF sequence resets to 1.
  Future<void> clearDatabase({bool keepSettings = true}) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('cash_movements');
      await txn.delete('cash_sessions');
      await txn.delete('custom_order_materials');
      await txn.delete('custom_orders');
      await txn.delete('quotes');
      await txn.delete('design_templates');
      await txn.delete('customers');
      await txn.delete('products');
      await txn.rawDelete('DELETE FROM sqlite_sequence');

      if (keepSettings) {
        await txn.update(
          'app_settings',
          {'ncf_next_sequence': 1},
          where: 'id = 1',
        );
      } else {
        await txn.update(
          'app_settings',
          AppSettings.defaults.toMap(),
          where: 'id = 1',
        );
      }
    });
  }
}
