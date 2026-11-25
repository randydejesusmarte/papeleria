/// Store customer for tracking custom orders, quotes, and billing info.
class Customer {
  const Customer({
    this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.rncOrId = '',
    this.notes = '',
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String phone;
  final String email;
  final String rncOrId;
  final String notes;
  final DateTime createdAt;

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? rncOrId,
    String? notes,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rncOrId: rncOrId ?? this.rncOrId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'rnc_or_id': rncOrId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      rncOrId: (map['rnc_or_id'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Reusable internal design template for customization jobs.
class DesignTemplate {
  const DesignTemplate({
    this.id,
    required this.name,
    required this.category,
    required this.technique,
    this.notes = '',
    this.imagePath = '',
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String category;
  final String technique;
  final String notes;
  final String imagePath;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'technique': technique,
      'notes': notes,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DesignTemplate.fromMap(Map<String, Object?> map) {
    return DesignTemplate(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'General',
      technique: (map['technique'] as String?) ?? 'Sublimación',
      notes: (map['notes'] as String?) ?? '',
      imagePath: (map['image_path'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
