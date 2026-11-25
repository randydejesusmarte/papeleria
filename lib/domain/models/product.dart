/// Categories for dual inventory: retail stationery, counter services,
/// customizable blanks, and production supplies.
enum ProductCategory {
  papeleria('papeleria', 'Papelería'),
  servicio('servicio', 'Servicio de Mostrador'),
  blank('blank', 'Objeto Base (Blank)'),
  insumo('insumo', 'Insumo / Material');

  const ProductCategory(this.value, this.label);

  final String value;
  final String label;

  static ProductCategory fromValue(String value) {
    return ProductCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProductCategory.papeleria,
    );
  }
}

/// Represents any sellable item, service, blank, or supply in the store.
class Product {
  const Product({
    this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    required this.costPrice,
    required this.salePrice,
    required this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.stock,
    required this.minStock,
    this.trackStock = true,
    this.isActive = true,
    required this.createdAt,
  });

  final int? id;
  final String sku;
  final String name;
  final ProductCategory category;
  final String unit;
  final double costPrice;
  final double salePrice;
  final double wholesalePrice;
  final int wholesaleMinQty;
  final double stock;
  final double minStock;
  final bool trackStock;
  final bool isActive;
  final DateTime createdAt;

  bool get isLowStock => trackStock && stock <= minStock;

  double effectivePriceForQty(double qty) {
    if (wholesalePrice > 0 && wholesaleMinQty > 0 && qty >= wholesaleMinQty) {
      return wholesalePrice;
    }
    return salePrice;
  }

  Product copyWith({
    int? id,
    String? sku,
    String? name,
    ProductCategory? category,
    String? unit,
    double? costPrice,
    double? salePrice,
    double? wholesalePrice,
    int? wholesaleMinQty,
    double? stock,
    double? minStock,
    bool? trackStock,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQty: wholesaleMinQty ?? this.wholesaleMinQty,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'sku': sku,
      'name': name,
      'category': category.value,
      'unit': unit,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'wholesale_price': wholesalePrice,
      'wholesale_min_qty': wholesaleMinQty,
      'stock': stock,
      'min_stock': minStock,
      'track_stock': trackStock ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      sku: (map['sku'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      category: ProductCategory.fromValue((map['category'] as String?) ?? ''),
      unit: (map['unit'] as String?) ?? 'unidad',
      costPrice: ((map['cost_price'] as num?) ?? 0).toDouble(),
      salePrice: ((map['sale_price'] as num?) ?? 0).toDouble(),
      wholesalePrice: ((map['wholesale_price'] as num?) ?? 0).toDouble(),
      wholesaleMinQty: (map['wholesale_min_qty'] as int?) ?? 12,
      stock: ((map['stock'] as num?) ?? 0).toDouble(),
      minStock: ((map['min_stock'] as num?) ?? 0).toDouble(),
      trackStock: ((map['track_stock'] as int?) ?? 1) == 1,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
