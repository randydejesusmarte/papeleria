import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/print_service.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/sale.dart';
import '../../core/app_controller.dart';
import '../../core/customer_autocomplete_field.dart';
import '../../core/formatters.dart';

/// Fast Point of Sale screen for stationery, counter services, and blanks.
class PosView extends StatefulWidget {
  const PosView({super.key, required this.controller});

  final AppController controller;

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerRncCtrl = TextEditingController();

  ProductCategory? _selectedCategory;
  final List<SaleItem> _cart = [];
  Customer? _selectedCustomer;
  PaymentMethod _paymentMethod = PaymentMethod.efectivo;
  bool? _applyTaxOverride;
  bool _isFiscal = false;
  String? _ncfTypeOverride;
  bool _isProcessing = false;

  bool get _applyTax =>
      _applyTaxOverride ?? widget.controller.settings.taxEnabled;
  String get _ncfType => _ncfTypeOverride ?? widget.controller.settings.ncfPrefix;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerRncCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.total);

  double get _discount =>
      (double.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0, _subtotal);

  double get _taxableBase => (_subtotal - _discount).clamp(0, double.infinity);

  double get _taxAmount {
    if (!_applyTax) return 0;
    return _taxableBase * (widget.controller.settings.taxRate / 100.0);
  }

  double get _total => _taxableBase + _taxAmount;

  void _addProductToCart(Product product) {
    final index = _cart.indexWhere((i) => i.productId == product.id);
    setState(() {
      if (index >= 0) {
        final existing = _cart[index];
        final nextQty = existing.quantity + 1;
        _cart[index] = existing.copyWith(
          quantity: nextQty,
          unitPrice: product.effectivePriceForQty(nextQty),
        );
      } else {
        _cart.add(
          SaleItem(
            productId: product.id,
            description: product.name,
            category: product.category.value,
            quantity: 1,
            unitPrice: product.effectivePriceForQty(1),
            costPrice: product.costPrice,
          ),
        );
      }
      _syncPaidField();
    });
  }

  void _updateCartQty(int index, double delta) {
    final item = _cart[index];
    final nextQty = item.quantity + delta;
    setState(() {
      if (nextQty <= 0) {
        _cart.removeAt(index);
      } else {
        Product? product;
        if (item.productId != null) {
          for (final p in widget.controller.products) {
            if (p.id == item.productId) {
              product = p;
              break;
            }
          }
        }
        final unitPrice = product != null
            ? product.effectivePriceForQty(nextQty)
            : item.unitPrice;
        _cart[index] = item.copyWith(quantity: nextQty, unitPrice: unitPrice);
      }
      _syncPaidField();
    });
  }

  void _syncPaidField() {
    if (_paymentMethod != PaymentMethod.efectivo) {
      _paidCtrl.text = _total.toStringAsFixed(2);
    }
  }

  Future<void> _addCustomQuickItem() async {
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String category = 'servicio';

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Agregar servicio o ítem rápido'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (ej. Impresión especial)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Precio (${widget.controller.currency})',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(
                      value: 'servicio',
                      child: Text('Servicio'),
                    ),
                    DropdownMenuItem(
                      value: 'papeleria',
                      child: Text('Papelería'),
                    ),
                    DropdownMenuItem(
                      value: 'personalizado',
                      child: Text('Personalizado'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => category = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    if (added == true && descCtrl.text.trim().isNotEmpty) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
      if (qty > 0 && price >= 0) {
        setState(() {
          _cart.add(
            SaleItem(
              description: descCtrl.text.trim(),
              category: category,
              quantity: qty,
              unitPrice: price,
              costPrice: 0,
            ),
          );
          _syncPaidField();
        });
      }
    }
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _isProcessing) return;

    final paid = double.tryParse(_paidCtrl.text.trim()) ?? _total;
    if (_paymentMethod == PaymentMethod.efectivo && paid < _total - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto recibido es menor al total a pagar.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = widget.controller.repository;
      final receiptNumber = await repo.generateNextReceiptNumber();
      final change = _paymentMethod == PaymentMethod.efectivo
          ? (paid - _total).clamp(0.0, double.infinity)
          : 0.0;

      final typedCustomerName = _customerNameCtrl.text.trim();
      final sale = Sale(
        receiptNumber: receiptNumber,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ??
            (typedCustomerName.isEmpty ? 'Cliente general' : typedCustomerName),
        customerRnc: _customerRncCtrl.text.trim(),
        isFiscal: _isFiscal,
        ncfType: _isFiscal ? _ncfType : '',
        subtotal: _subtotal,
        discount: _discount,
        taxAmount: _taxAmount,
        total: _total,
        paymentMethod: _paymentMethod,
        amountPaid: paid,
        changeAmount: change,
        cashSessionId: widget.controller.openCashSession?.id,
        createdAt: DateTime.now(),
        items: List<SaleItem>.from(_cart),
      );

      final savedSale = await repo.completeSale(sale);
      await widget.controller.refreshAll();

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _discountCtrl.text = '0';
        _paidCtrl.clear();
        _customerNameCtrl.clear();
        _customerRncCtrl.clear();
        _selectedCustomer = null;
        _isFiscal = false;
      });

      await _showReceiptDialog(savedSale);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showReceiptDialog(Sale sale) async {
    final c = widget.controller.currency;
    final settings = widget.controller.settings;
    final lines = StringBuffer()
      ..writeln(settings.businessName)
      ..writeln(settings.rnc.isNotEmpty ? 'RNC: ${settings.rnc}' : '')
      ..writeln(sale.isFiscal && sale.ncf.isNotEmpty ? 'NCF: ${sale.ncf}' : '')
      ..writeln('Recibo: ${sale.receiptNumber}')
      ..writeln('Fecha: ${AppFormatters.dateTime(sale.createdAt)}')
      ..writeln('Cliente: ${sale.customerName}')
      ..writeln(sale.customerRnc.isNotEmpty ? 'RNC/Cédula: ${sale.customerRnc}' : '')
      ..writeln('--------------------------------')
      ..writeAll(
        sale.items.map(
          (i) =>
              '${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 1)}x ${i.description}  ${AppFormatters.money(i.total, symbol: c)}\n',
        ),
      )
      ..writeln('--------------------------------')
      ..writeln('Subtotal: ${AppFormatters.money(sale.subtotal, symbol: c)}')
      ..writeln(
        sale.discount > 0
            ? 'Descuento: -${AppFormatters.money(sale.discount, symbol: c)}'
            : '',
      )
      ..writeln('ITBIS: ${AppFormatters.money(sale.taxAmount, symbol: c)}')
      ..writeln('TOTAL: ${AppFormatters.money(sale.total, symbol: c)}')
      ..writeln('Método: ${sale.paymentMethod.label}')
      ..writeln('Cambio: ${AppFormatters.money(sale.changeAmount, symbol: c)}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Venta ${sale.receiptNumber}'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              lines.toString().replaceAll('\n\n', '\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: lines.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          OutlinedButton.icon(
            onPressed: () => PrintService.printSale(
              sale: sale,
              settings: settings,
              format: PrintPaperFormat.ticket80mm,
            ),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Imprimir Ticket'),
          ),
          OutlinedButton.icon(
            onPressed: () => PrintService.printSale(
              sale: sale,
              settings: settings,
              format: PrintPaperFormat.sheet6x8,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Imprimir Hoja 6x8"'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredProducts = widget.controller.products.where((p) {
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query);
    }).toList();

    final currency = widget.controller.currency;

    return Row(
      children: [
        // Left: Product catalog & search
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por nombre o SKU / código...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _addCustomQuickItem,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Ítem / Servicio rápido'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                    for (final cat in ProductCategory.values)
                      FilterChip(
                        label: Text(cat.label),
                        selected: _selectedCategory == cat,
                        onSelected: (_) => setState(
                          () => _selectedCategory = _selectedCategory == cat
                              ? null
                              : cat,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Text('No hay productos que coincidan.'),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 230,
                                mainAxisExtent: 140,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _addProductToCart(p),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.sku,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Colors.grey.shade600,
                                                  ),
                                            ),
                                          ),
                                          if (p.trackStock) ...[
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: p.isLowStock
                                                      ? Colors.red.shade50
                                                      : Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${p.stock.toStringAsFixed(0)} ${p.unit}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: p.isLowStock
                                                        ? Colors.red.shade700
                                                        : Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              AppFormatters.money(
                                                p.salePrice,
                                                symbol: currency,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          if (p.wholesalePrice > 0) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              'May: ${p.wholesaleMinQty}+',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        // Right: Cart & Checkout
        Container(
          width: 390,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              left: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ticket Actual',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_cart.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _cart.clear()),
                      child: const Text('Limpiar'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              CustomerAutocompleteField(
                customers: widget.controller.customers,
                controller: _customerNameCtrl,
                onCustomerChanged: (v) {
                  setState(() {
                    _selectedCustomer = v;
                    if (v != null && v.rncOrId.isNotEmpty) {
                      _customerRncCtrl.text = v.rncOrId;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customerRncCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RNC / Cédula (opcional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      _isFiscal ? 'NCF $_ncfType' : 'Valor Fiscal',
                    ),
                    selected: _isFiscal,
                    onSelected: (v) => setState(() => _isFiscal = v),
                  ),
                ],
              ),
              if (_isFiscal) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _ncfType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Comprobante (NCF)',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'B01', child: Text('B01 - Crédito Fiscal')),
                    DropdownMenuItem(
                        value: 'B02', child: Text('B02 - Consumo')),
                    DropdownMenuItem(
                        value: 'B14', child: Text('B14 - Regímenes Especiales')),
                    DropdownMenuItem(
                        value: 'B15', child: Text('B15 - Gubernamental')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _ncfTypeOverride = v);
                  },
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _cart.isEmpty
                    ? Center(
                        child: Text(
                          'Haz clic en los productos para agregarlos al ticket.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _cart.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${AppFormatters.money(item.unitPrice, symbol: currency)} c/u',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => _updateCartQty(index, -1),
                                ),
                                Text(
                                  item.quantity.toStringAsFixed(
                                    item.quantity % 1 == 0 ? 0 : 1,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => _updateCartQty(index, 1),
                                ),
                                SizedBox(
                                  width: 78,
                                  child: Text(
                                    AppFormatters.money(
                                      item.total,
                                      symbol: currency,
                                    ),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _syncPaidField()),
                      decoration: InputDecoration(
                        labelText: 'Descuento ($currency)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      'ITBIS ${widget.controller.settings.taxRate.toStringAsFixed(0)}%',
                    ),
                    selected: _applyTax,
                    onSelected: (v) => setState(() {
                      _applyTaxOverride = v;
                      _syncPaidField();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TotalRow(
                label: 'Subtotal',
                value: AppFormatters.money(_subtotal, symbol: currency),
              ),
              if (_discount > 0)
                _TotalRow(
                  label: 'Descuento',
                  value: '-${AppFormatters.money(_discount, symbol: currency)}',
                ),
              _TotalRow(
                label: 'ITBIS',
                value: AppFormatters.money(_taxAmount, symbol: currency),
              ),
              const SizedBox(height: 4),
              _TotalRow(
                label: 'TOTAL',
                value: AppFormatters.money(_total, symbol: currency),
                isBold: true,
              ),
              const SizedBox(height: 10),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.efectivo,
                    label: Text('Efectivo'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.tarjeta,
                    label: Text('Tarjeta'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.transferencia,
                    label: Text('Transf.'),
                  ),
                ],
                selected: {_paymentMethod},
                onSelectionChanged: (sel) {
                  setState(() {
                    _paymentMethod = sel.first;
                    _syncPaidField();
                  });
                },
              ),
              const SizedBox(height: 10),
              if (_paymentMethod == PaymentMethod.efectivo)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Recibido ($currency)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Cambio', style: TextStyle(fontSize: 12)),
                        Text(
                          AppFormatters.money(
                            ((double.tryParse(_paidCtrl.text.trim()) ?? 0) -
                                    _total)
                                .clamp(0, double.infinity),
                            symbol: currency,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _cart.isEmpty || _isProcessing ? null : _checkout,
                icon: const Icon(Icons.point_of_sale),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _isProcessing ? 'Procesando...' : 'Cobrar Venta',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 18 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
