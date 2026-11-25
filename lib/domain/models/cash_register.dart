/// Cash register shift (apertura y cierre de caja).
class CashSession {
  const CashSession({
    this.id,
    required this.openedAt,
    this.closedAt,
    required this.openingAmount,
    this.closingAmountExpected = 0,
    this.closingAmountCounted = 0,
    this.difference = 0,
    required this.status,
    this.notes = '',
  });

  final int? id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingAmount;
  final double closingAmountExpected;
  final double closingAmountCounted;
  final double difference;
  final String status; // 'abierta' | 'cerrada'
  final String notes;

  bool get isOpen => status == 'abierta';

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_amount': openingAmount,
      'closing_amount_expected': closingAmountExpected,
      'closing_amount_counted': closingAmountCounted,
      'difference': difference,
      'status': status,
      'notes': notes,
    };
  }

  factory CashSession.fromMap(Map<String, Object?> map) {
    return CashSession(
      id: map['id'] as int?,
      openedAt: DateTime.tryParse((map['opened_at'] as String?) ?? '') ??
          DateTime.now(),
      closedAt: map['closed_at'] != null
          ? DateTime.tryParse(map['closed_at'] as String)
          : null,
      openingAmount: ((map['opening_amount'] as num?) ?? 0).toDouble(),
      closingAmountExpected:
          ((map['closing_amount_expected'] as num?) ?? 0).toDouble(),
      closingAmountCounted:
          ((map['closing_amount_counted'] as num?) ?? 0).toDouble(),
      difference: ((map['difference'] as num?) ?? 0).toDouble(),
      status: (map['status'] as String?) ?? 'abierta',
      notes: (map['notes'] as String?) ?? '',
    );
  }
}

/// Cash drawer movement (ingreso manual, retiro o gasto de caja chica).
class CashMovement {
  const CashMovement({
    this.id,
    required this.sessionId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  final int? id;
  final int sessionId;
  final String type; // 'ingreso' | 'retiro' | 'gasto'
  final double amount;
  final String description;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'type': type,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CashMovement.fromMap(Map<String, Object?> map) {
    return CashMovement(
      id: map['id'] as int?,
      sessionId: (map['session_id'] as int?) ?? 0,
      type: (map['type'] as String?) ?? 'gasto',
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
