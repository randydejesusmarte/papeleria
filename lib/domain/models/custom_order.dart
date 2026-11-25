/// Workflow status for custom personalization orders.
enum OrderStatus {
  cotizado('cotizado', 'Cotizado'),
  conAnticipo('con_anticipo', 'Con anticipo'),
  enDiseno('en_diseno', 'En diseño'),
  enProduccion('en_produccion', 'En producción'),
  listo('listo', 'Listo para entrega'),
  entregado('entregado', 'Entregado'),
  cancelado('cancelado', 'Cancelado');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus fromValue(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderStatus.cotizado,
    );
  }
}

/// Material or blank consumed by a custom order.
class CustomOrderMaterial {
  const CustomOrderMaterial({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantityUsed,
  });

  final int? id;
  final int orderId;
  final int productId;
  final String productName;
  final double quantityUsed;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity_used': quantityUsed,
    };
  }

  factory CustomOrderMaterial.fromMap(Map<String, Object?> map) {
    return CustomOrderMaterial(
      id: map['id'] as int?,
      orderId: (map['order_id'] as int?) ?? 0,
      productId: (map['product_id'] as int?) ?? 0,
      productName: (map['product_name'] as String?) ?? '',
      quantityUsed: ((map['quantity_used'] as num?) ?? 0).toDouble(),
    );
  }
}

/// Custom personalization job (work order).
class CustomOrder {
  const CustomOrder({
    this.id,
    required this.orderNumber,
    this.customerId,
    required this.customerName,
    this.customerPhone = '',
    this.baseProductId,
    required this.productName,
    required this.technique,
    this.colorSize = '',
    this.customText = '',
    this.designNotes = '',
    this.designImagePath = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.depositPaid,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String orderNumber;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final int? baseProductId;
  final String productName;
  final String technique;
  final String colorSize;
  final String customText;
  final String designNotes;
  final String designImagePath;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double depositPaid;
  final OrderStatus status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get balanceDue => (total - depositPaid).clamp(0.0, double.infinity);

  bool get isOverdue =>
      status != OrderStatus.entregado &&
      status != OrderStatus.cancelado &&
      dueDate.isBefore(DateTime.now());

  CustomOrder copyWith({
    int? id,
    String? orderNumber,
    int? customerId,
    String? customerName,
    String? customerPhone,
    int? baseProductId,
    String? productName,
    String? technique,
    String? colorSize,
    String? customText,
    String? designNotes,
    String? designImagePath,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    double? taxAmount,
    double? total,
    double? depositPaid,
    OrderStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      baseProductId: baseProductId ?? this.baseProductId,
      productName: productName ?? this.productName,
      technique: technique ?? this.technique,
      colorSize: colorSize ?? this.colorSize,
      customText: customText ?? this.customText,
      designNotes: designNotes ?? this.designNotes,
      designImagePath: designImagePath ?? this.designImagePath,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      depositPaid: depositPaid ?? this.depositPaid,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'base_product_id': baseProductId,
      'product_name': productName,
      'technique': technique,
      'color_size': colorSize,
      'custom_text': customText,
      'design_notes': designNotes,
      'design_image_path': designImagePath,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'deposit_paid': depositPaid,
      'status': status.value,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomOrder.fromMap(Map<String, Object?> map) {
    return CustomOrder(
      id: map['id'] as int?,
      orderNumber: (map['order_number'] as String?) ?? '',
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '',
      customerPhone: (map['customer_phone'] as String?) ?? '',
      baseProductId: map['base_product_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
      technique: (map['technique'] as String?) ?? 'Sublimación',
      colorSize: (map['color_size'] as String?) ?? '',
      customText: (map['custom_text'] as String?) ?? '',
      designNotes: (map['design_notes'] as String?) ?? '',
      designImagePath: (map['design_image_path'] as String?) ?? '',
      quantity: (map['quantity'] as int?) ?? 1,
      unitPrice: ((map['unit_price'] as num?) ?? 0).toDouble(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      taxAmount: ((map['tax_amount'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      depositPaid: ((map['deposit_paid'] as num?) ?? 0).toDouble(),
      status: OrderStatus.fromValue((map['status'] as String?) ?? ''),
      dueDate:
          DateTime.tryParse((map['due_date'] as String?) ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
