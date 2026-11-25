import 'package:flutter/foundation.dart';

import '../../data/repositories/store_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/cash_register.dart';
import '../../domain/models/custom_order.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/sale.dart';

/// Central application state coordinator backed by SQLite [StoreRepository].
class AppController extends ChangeNotifier {
  AppController({required this._repository});

  final StoreRepository _repository;

  StoreRepository get repository => _repository;

  bool isLoading = true;
  AppSettings settings = AppSettings.defaults;
  List<Product> products = const [];
  List<Customer> customers = const [];
  List<DesignTemplate> templates = const [];
  List<CustomOrder> orders = const [];
  List<Quote> quotes = const [];
  List<Sale> recentSales = const [];
  CashSession? openCashSession;

  String get currency => settings.currencySymbol;

  int get lowStockCount => products.where((p) => p.isLowStock).length;

  int get activeOrdersCount => orders
      .where(
        (o) =>
            o.status != OrderStatus.entregado &&
            o.status != OrderStatus.cancelado,
      )
      .length;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    await refreshAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final results = await Future.wait([
      _repository.getSettings(),
      _repository.getProducts(),
      _repository.getCustomers(),
      _repository.getDesignTemplates(),
      _repository.getCustomOrders(),
      _repository.getQuotes(),
      _repository.getRecentSales(limit: 40),
      _repository.getOpenCashSession(),
    ]);

    settings = results[0] as AppSettings;
    products = results[1] as List<Product>;
    customers = results[2] as List<Customer>;
    templates = results[3] as List<DesignTemplate>;
    orders = results[4] as List<CustomOrder>;
    quotes = results[5] as List<Quote>;
    recentSales = results[6] as List<Sale>;
    openCashSession = results[7] as CashSession?;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings updated) async {
    await _repository.saveSettings(updated);
    settings = updated;
    notifyListeners();
  }
}
