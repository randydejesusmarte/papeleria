import 'package:flutter_test/flutter_test.dart';
import 'package:papeleria/data/repositories/store_repository.dart';
import 'package:papeleria/data/services/local_database_service.dart';
import 'package:papeleria/domain/models/app_settings.dart';
import 'package:papeleria/domain/models/cash_register.dart';
import 'package:papeleria/domain/models/custom_order.dart';
import 'package:papeleria/domain/models/product.dart';
import 'package:papeleria/domain/models/quote.dart';
import 'package:papeleria/domain/models/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabaseService dbService;
  late StoreRepository repo;

  setUp(() async {
    dbService = LocalDatabaseService(
      customPath: inMemoryDatabasePath,
      seedSampleData: true,
    );
    repo = StoreRepository(dbService: dbService);
    await dbService.database;
  });

  tearDown(() async {
    await dbService.close();
  });

  test('loads default DOP settings and updates configurable ITBIS', () async {
    final initial = await repo.getSettings();
    expect(initial.currencySymbol, 'RD\$');
    expect(initial.taxEnabled, isTrue);
    expect(initial.taxRate, 18.0);

    await repo.saveSettings(
      const AppSettings(
        businessName: 'Mi Papelería RD',
        rnc: '130123456',
        phone: '809-555-1234',
        address: 'Santiago',
        currencySymbol: 'RD\$',
        taxEnabled: false,
        taxRate: 16.0,
      ),
    );

    final updated = await repo.getSettings();
    expect(updated.businessName, 'Mi Papelería RD');
    expect(updated.taxEnabled, isFalse);
    expect(updated.taxRate, 16.0);
  });

  test('completes POS sale and deducts tracked stock atomically', () async {
    final products = await repo.getProducts();
    final notebook =
        products.firstWhere((p) => p.sku == 'PAP-001');
    final initialStock = notebook.stock;

    final sale = Sale(
      receiptNumber: await repo.generateNextReceiptNumber(),
      subtotal: 240,
      discount: 0,
      taxAmount: 43.2,
      total: 283.2,
      paymentMethod: PaymentMethod.efectivo,
      amountPaid: 300,
      changeAmount: 16.8,
      createdAt: DateTime.now(),
      items: [
        SaleItem(
          productId: notebook.id,
          description: notebook.name,
          category: ProductCategory.papeleria.value,
          quantity: 2,
          unitPrice: 120,
          costPrice: notebook.costPrice,
        ),
      ],
    );

    final saved = await repo.completeSale(sale);
    expect(saved.id, isNotNull);

    final afterProducts = await repo.getProducts();
    final updatedNotebook =
        afterProducts.firstWhere((p) => p.id == notebook.id);
    expect(updatedNotebook.stock, initialStock - 2);
  });

  test('converts quote to custom order and records deposit payment', () async {
    final now = DateTime.now();
    final quoteId = await repo.saveQuote(
      Quote(
        quoteNumber: await repo.generateNextQuoteNumber(),
        customerName: 'Carlos Pérez',
        productName: 'Termo 20 oz',
        technique: 'Sublimación',
        baseCost: 320,
        suppliesCost: 40,
        laborCost: 60,
        marginPercent: 50,
        quantity: 2,
        unitPrice: 630,
        subtotal: 1260,
        taxAmount: 226.8,
        total: 1486.8,
        validUntil: now.add(const Duration(days: 15)),
        createdAt: now,
      ),
    );

    final quotes = await repo.getQuotes();
    final savedQuote = quotes.firstWhere((q) => q.id == quoteId);

    final orderId = await repo.convertQuoteToOrder(savedQuote);
    final orders = await repo.getCustomOrders();
    final order = orders.firstWhere((o) => o.id == orderId);
    expect(order.status, OrderStatus.cotizado);
    expect(order.balanceDue, closeTo(1486.8, 0.01));

    await repo.recordOrderPayment(
      order: order,
      paymentAmount: 700,
      paymentMethod: PaymentMethod.transferencia,
    );

    final updatedOrders = await repo.getCustomOrders();
    final paidOrder = updatedOrders.firstWhere((o) => o.id == orderId);
    expect(paidOrder.depositPaid, closeTo(700, 0.01));
    expect(paidOrder.balanceDue, closeTo(786.8, 0.01));
    expect(paidOrder.status, OrderStatus.conAnticipo);
  });

  test('opens cash session, tracks movement, and closes with difference', () async {
    final session = await repo.openCashSession(2000);
    expect(session.isOpen, isTrue);

    await repo.addCashMovement(
      CashMovement(
        sessionId: session.id!,
        type: 'gasto',
        amount: 250,
        description: 'Compra de cinta adhesiva',
        createdAt: DateTime.now(),
      ),
    );

    final expected = await repo.computeExpectedCashInSession(session);
    expect(expected, 1750);

    await repo.closeCashSession(
      session: session,
      countedAmount: 1750,
      notes: 'Cuadre exacto',
    );

    final openAfter = await repo.getOpenCashSession();
    expect(openAfter, isNull);
  });

  test('assigns sequential NCF on fiscal sale and persists dark mode', () async {
    final sale = Sale(
      receiptNumber: await repo.generateNextReceiptNumber(),
      customerName: 'Empresa ABC',
      customerRnc: '1-30-55555-1',
      isFiscal: true,
      ncfType: 'B01',
      subtotal: 1000,
      discount: 0,
      taxAmount: 180,
      total: 1180,
      paymentMethod: PaymentMethod.transferencia,
      amountPaid: 1180,
      changeAmount: 0,
      createdAt: DateTime.now(),
      items: const [
        SaleItem(
          description: 'Tazas personalizadas',
          category: 'blank',
          quantity: 4,
          unitPrice: 250,
          costPrice: 95,
        ),
      ],
    );

    final saved = await repo.completeSale(sale);
    expect(saved.ncf, 'B0100000001');
    expect(saved.customerRnc, '1-30-55555-1');

    final settingsAfter = await repo.getSettings();
    expect(settingsAfter.ncfNextSequence, 2);

    await repo.saveSettings(settingsAfter.copyWith(darkMode: true));
    final darkSettings = await repo.getSettings();
    expect(darkSettings.darkMode, isTrue);
  });

  test('deletes product from active inventory', () async {
    final before = await repo.getProducts();
    final target = before.first;
    await repo.deleteProduct(target.id!);

    final after = await repo.getProducts();
    expect(after.any((p) => p.id == target.id), isFalse);
  });

  test('clearDatabase wipes operational tables while preserving settings',
      () async {
    await repo.clearDatabase(keepSettings: true);

    expect(await repo.getProducts(), isEmpty);
    expect(await repo.getCustomers(), isEmpty);
    expect(await repo.getCustomOrders(), isEmpty);
    expect(await repo.getQuotes(), isEmpty);
    expect(await repo.getRecentSales(), isEmpty);

    final settings = await repo.getSettings();
    expect(settings.ncfNextSequence, 1);
  });
}
