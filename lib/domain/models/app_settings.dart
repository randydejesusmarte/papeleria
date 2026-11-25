/// Global store, tax, fiscal (NCF), and theme configuration stored locally in SQLite.
class AppSettings {
  const AppSettings({
    this.id = 1,
    required this.businessName,
    required this.rnc,
    required this.phone,
    required this.address,
    required this.currencySymbol,
    required this.taxEnabled,
    required this.taxRate,
    this.darkMode = false,
    this.ncfPrefix = 'B01',
    this.ncfNextSequence = 1,
    this.ncfValidUntil = '31/12/2026',
  });

  final int id;
  final String businessName;
  final String rnc;
  final String phone;
  final String address;
  final String currencySymbol;
  final bool taxEnabled;
  final double taxRate;
  final bool darkMode;
  final String ncfPrefix;
  final int ncfNextSequence;
  final String ncfValidUntil;

  static const AppSettings defaults = AppSettings(
    id: 1,
    businessName: 'Papelería & Personalizados',
    rnc: '',
    phone: '',
    address: '',
    currencySymbol: 'RD\$',
    taxEnabled: true,
    taxRate: 18.0,
    darkMode: false,
    ncfPrefix: 'B01',
    ncfNextSequence: 1,
    ncfValidUntil: '31/12/2026',
  );

  String previewNextNcf([String? prefixOverride]) {
    final prefix = prefixOverride ?? ncfPrefix;
    return '$prefix${ncfNextSequence.toString().padLeft(8, '0')}';
  }

  AppSettings copyWith({
    String? businessName,
    String? rnc,
    String? phone,
    String? address,
    String? currencySymbol,
    bool? taxEnabled,
    double? taxRate,
    bool? darkMode,
    String? ncfPrefix,
    int? ncfNextSequence,
    String? ncfValidUntil,
  }) {
    return AppSettings(
      id: id,
      businessName: businessName ?? this.businessName,
      rnc: rnc ?? this.rnc,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      darkMode: darkMode ?? this.darkMode,
      ncfPrefix: ncfPrefix ?? this.ncfPrefix,
      ncfNextSequence: ncfNextSequence ?? this.ncfNextSequence,
      ncfValidUntil: ncfValidUntil ?? this.ncfValidUntil,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'rnc': rnc,
      'phone': phone,
      'address': address,
      'currency_symbol': currencySymbol,
      'tax_enabled': taxEnabled ? 1 : 0,
      'tax_rate': taxRate,
      'dark_mode': darkMode ? 1 : 0,
      'ncf_prefix': ncfPrefix,
      'ncf_next_sequence': ncfNextSequence,
      'ncf_valid_until': ncfValidUntil,
    };
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      id: (map['id'] as int?) ?? 1,
      businessName: (map['business_name'] as String?) ?? defaults.businessName,
      rnc: (map['rnc'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      currencySymbol: (map['currency_symbol'] as String?) ?? 'RD\$',
      taxEnabled: ((map['tax_enabled'] as int?) ?? 1) == 1,
      taxRate: ((map['tax_rate'] as num?) ?? 18.0).toDouble(),
      darkMode: ((map['dark_mode'] as int?) ?? 0) == 1,
      ncfPrefix: (map['ncf_prefix'] as String?) ?? 'B01',
      ncfNextSequence: (map['ncf_next_sequence'] as int?) ?? 1,
      ncfValidUntil: (map['ncf_valid_until'] as String?) ?? '31/12/2026',
    );
  }
}
