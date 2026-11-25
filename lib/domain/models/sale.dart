/// Payment methods supported at the POS counter.
enum PaymentMethod {
  efectivo('efectivo', 'Efectivo'),
  tarjeta('tarjeta', 'Tarjeta'),
  transferencia('transferencia', 'Transferencia');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod fromValue(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.efectivo,
    );
  }
}

/// Line item inside a POS sale receipt.
class SaleItem {
  const SaleItem({
    this.id,
    this.saleId,
    this.productId,
    required this.description,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
  });

  final int? id;
  final int? saleId;
  final int? productId;
  final String description;
  final String category;
  final double quantity;
  final double unitPrice;
  final double costPrice;

  double get total => quantity * unitPrice;

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    String? description,
    String? category,
    double? quantity,
    double? unitPrice,
    double? costPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
    );
  }

  Map<String, Object?> toMap(int parentSaleId) {
    return {
      if (id != null) 'id': id,
      'sale_id': parentSaleId,
      'product_id': productId,
      'description': description,
      'category': category,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'total': total,
    };
  }

  factory SaleItem.fromMap(Map<String, Object?> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int?,
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'papeleria',
      quantity: ((map['quantity'] as num?) ?? 1).toDouble(),
      unitPrice: ((map['unit_price'] as num?) ?? 0).toDouble(),
      costPrice: ((map['cost_price'] as num?) ?? 0).toDouble(),
    );
  }
}

/// Completed POS sale receipt.
class Sale {
  const Sale({
    this.id,
    required this.receiptNumber,
    this.customerId,
    this.customerName = 'Cliente general',
    this.customerRnc = '',
    this.isFiscal = false,
    this.ncf = '',
    this.ncfType = '',
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    this.cashSessionId,
    this.notes = '',
    required this.createdAt,
    this.items = const [],
  });

  final int? id;
  final String receiptNumber;
  final int? customerId;
  final String customerName;
  final String customerRnc;
  final bool isFiscal;
  final String ncf;
  final String ncfType;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final PaymentMethod paymentMethod;
  final double amountPaid;
  final double changeAmount;
  final int? cashSessionId;
  final String notes;
  final DateTime createdAt;
  final List<SaleItem> items;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'receipt_number': receiptNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_rnc': customerRnc,
      'is_fiscal': isFiscal ? 1 : 0,
      'ncf': ncf,
      'ncf_type': ncfType,
      'subtotal': subtotal,
      'discount': discount,
      'tax_amount': taxAmount,
      'total': total,
      'payment_method': paymentMethod.value,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'cash_session_id': cashSessionId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, Object?> map, [List<SaleItem> items = const []]) {
    return Sale(
      id: map['id'] as int?,
      receiptNumber: (map['receipt_number'] as String?) ?? '',
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? 'Cliente general',
      customerRnc: (map['customer_rnc'] as String?) ?? '',
      isFiscal: ((map['is_fiscal'] as int?) ?? 0) == 1,
      ncf: (map['ncf'] as String?) ?? '',
      ncfType: (map['ncf_type'] as String?) ?? '',
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      discount: ((map['discount'] as num?) ?? 0).toDouble(),
      taxAmount: ((map['tax_amount'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      paymentMethod: PaymentMethod.fromValue((map['payment_method'] as String?) ?? ''),
      amountPaid: ((map['amount_paid'] as num?) ?? 0).toDouble(),
      changeAmount: ((map['change_amount'] as num?) ?? 0).toDouble(),
      cashSessionId: map['cash_session_id'] as int?,
      notes: (map['notes'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      items: items,
    );
  }
}
