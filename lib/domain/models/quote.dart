/// Saved cost calculation and customer quotation.
class Quote {
  const Quote({
    this.id,
    required this.quoteNumber,
    this.customerId,
    required this.customerName,
    required this.productName,
    required this.technique,
    required this.baseCost,
    required this.suppliesCost,
    required this.laborCost,
    required this.marginPercent,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.notes = '',
    required this.validUntil,
    this.convertedOrderId,
    required this.createdAt,
  });

  final int? id;
  final String quoteNumber;
  final int? customerId;
  final String customerName;
  final String productName;
  final String technique;
  final double baseCost;
  final double suppliesCost;
  final double laborCost;
  final double marginPercent;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String notes;
  final DateTime validUntil;
  final int? convertedOrderId;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'quote_number': quoteNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'product_name': productName,
      'technique': technique,
      'base_cost': baseCost,
      'supplies_cost': suppliesCost,
      'labor_cost': laborCost,
      'margin_percent': marginPercent,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'notes': notes,
      'valid_until': validUntil.toIso8601String(),
      'converted_order_id': convertedOrderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Quote.fromMap(Map<String, Object?> map) {
    return Quote(
      id: map['id'] as int?,
      quoteNumber: (map['quote_number'] as String?) ?? '',
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '',
      productName: (map['product_name'] as String?) ?? '',
      technique: (map['technique'] as String?) ?? 'Sublimación',
      baseCost: ((map['base_cost'] as num?) ?? 0).toDouble(),
      suppliesCost: ((map['supplies_cost'] as num?) ?? 0).toDouble(),
      laborCost: ((map['labor_cost'] as num?) ?? 0).toDouble(),
      marginPercent: ((map['margin_percent'] as num?) ?? 0).toDouble(),
      quantity: (map['quantity'] as int?) ?? 1,
      unitPrice: ((map['unit_price'] as num?) ?? 0).toDouble(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      taxAmount: ((map['tax_amount'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      notes: (map['notes'] as String?) ?? '',
      validUntil: DateTime.tryParse((map['valid_until'] as String?) ?? '') ??
          DateTime.now(),
      convertedOrderId: map['converted_order_id'] as int?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
