import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/print_service.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/quote.dart';
import '../../core/app_controller.dart';
import '../../core/customer_autocomplete_field.dart';
import '../../core/formatters.dart';

/// Cost calculator and quotation generator with 1-click conversion to Custom Order.
class QuoterView extends StatefulWidget {
  const QuoterView({super.key, required this.controller});

  final AppController controller;

  @override
  State<QuoterView> createState() => _QuoterViewState();
}

class _QuoterViewState extends State<QuoterView> {
  final TextEditingController _productCtrl =
      TextEditingController(text: 'Taza Blanca 11 oz');
  final TextEditingController _baseCostCtrl =
      TextEditingController(text: '95');
  final TextEditingController _suppliesCostCtrl =
      TextEditingController(text: '35');
  final TextEditingController _laborCostCtrl =
      TextEditingController(text: '45');
  final TextEditingController _marginCtrl = TextEditingController(text: '80');
  final TextEditingController _qtyCtrl = TextEditingController(text: '12');
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();

  Customer? _selectedCustomer;
  String _technique = 'Sublimación';
  bool? _applyTaxOverride;

  bool get _applyTax => _applyTaxOverride ?? widget.controller.settings.taxEnabled;

  @override
  void dispose() {
    _productCtrl.dispose();
    _baseCostCtrl.dispose();
    _suppliesCostCtrl.dispose();
    _laborCostCtrl.dispose();
    _marginCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  double get _baseCost => double.tryParse(_baseCostCtrl.text.trim()) ?? 0;
  double get _suppliesCost => double.tryParse(_suppliesCostCtrl.text.trim()) ?? 0;
  double get _laborCost => double.tryParse(_laborCostCtrl.text.trim()) ?? 0;
  double get _marginPercent => double.tryParse(_marginCtrl.text.trim()) ?? 0;
  int get _qty => (int.tryParse(_qtyCtrl.text.trim()) ?? 1).clamp(1, 100000);

  double get _unitCost => _baseCost + _suppliesCost + _laborCost;
  double get _unitPrice => _unitCost * (1 + (_marginPercent / 100));
  double get _subtotal => _unitPrice * _qty;
  double get _taxAmount =>
      _applyTax ? _subtotal * (widget.controller.settings.taxRate / 100) : 0;
  double get _total => _subtotal + _taxAmount;
  double get _estimatedProfit => (_unitPrice - _unitCost) * _qty;

  Future<void> _saveQuote() async {
    if (_productCtrl.text.trim().isEmpty) return;
    final repo = widget.controller.repository;
    final quoteNumber = await repo.generateNextQuoteNumber();
    final now = DateTime.now();

    final typedCustomer = _customerNameCtrl.text.trim();
    final quote = Quote(
      quoteNumber: quoteNumber,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ??
          (typedCustomer.isEmpty ? 'Cliente general' : typedCustomer),
      productName: _productCtrl.text.trim(),
      technique: _technique,
      baseCost: _baseCost,
      suppliesCost: _suppliesCost,
      laborCost: _laborCost,
      marginPercent: _marginPercent,
      quantity: _qty,
      unitPrice: _unitPrice,
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      total: _total,
      notes: _notesCtrl.text.trim(),
      validUntil: now.add(const Duration(days: 15)),
      createdAt: now,
    );

    await repo.saveQuote(quote);
    await widget.controller.refreshAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cotización $quoteNumber guardada')),
      );
    }
  }

  void _copyQuoteText({Quote? quote}) {
    final c = widget.controller.currency;
    final prod = quote?.productName ?? _productCtrl.text.trim();
    final tech = quote?.technique ?? _technique;
    final qty = quote?.quantity ?? _qty;
    final unit = quote?.unitPrice ?? _unitPrice;
    final sub = quote?.subtotal ?? _subtotal;
    final tax = quote?.taxAmount ?? _taxAmount;
    final tot = quote?.total ?? _total;
    final typedCustomer = _customerNameCtrl.text.trim();
    final cust = quote?.customerName ??
        (_selectedCustomer?.name ??
            (typedCustomer.isEmpty ? 'Cliente' : typedCustomer));

    final text = '*COTIZACIÓN ${quote?.quoteNumber ?? ""}*\n'
        '${widget.controller.settings.businessName}\n'
        'Para: $cust\n'
        'Producto: $qty x $prod ($tech)\n'
        'Precio unitario: ${AppFormatters.money(unit, symbol: c)}\n'
        'Subtotal: ${AppFormatters.money(sub, symbol: c)}\n'
        'ITBIS: ${AppFormatters.money(tax, symbol: c)}\n'
        '*TOTAL: ${AppFormatters.money(tot, symbol: c)}*\n'
        'Válida por 15 días.';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cotización copiada para WhatsApp')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller.currency;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Calculator
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculadora de Costos y Cotización',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CustomerAutocompleteField(
                            customers: widget.controller.customers,
                            controller: _customerNameCtrl,
                            onCustomerChanged: (v) =>
                                setState(() => _selectedCustomer = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _technique,
                            decoration:
                                const InputDecoration(labelText: 'Técnica'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Sublimación',
                                  child: Text('Sublimación')),
                              DropdownMenuItem(value: 'DTF', child: Text('DTF')),
                              DropdownMenuItem(
                                  value: 'Vinil Textil',
                                  child: Text('Vinil Textil')),
                              DropdownMenuItem(
                                  value: 'Grabado Láser',
                                  child: Text('Grabado Láser')),
                              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _technique = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _productCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Objeto / Trabajo a cotizar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _baseCostCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Costo objeto base ($c)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _suppliesCostCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Insumos / tinta ($c)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _laborCostCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Mano de obra / máq. ($c)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _marginCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Margen de ganancia (%)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(labelText: 'Cantidad'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilterChip(
                          label: Text(
                            'ITBIS ${widget.controller.settings.taxRate.toStringAsFixed(0)}%',
                          ),
                          selected: _applyTax,
                          onSelected: (v) =>
                              setState(() => _applyTaxOverride = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        const Text('Volumen rápido:'),
                        for (final preset in [1, 6, 12, 24, 50])
                          ActionChip(
                            label: Text('$preset pzas'),
                            onPressed: () {
                              setState(() {
                                _qtyCtrl.text = '$preset';
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notas o condiciones',
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Costo unitario: ${AppFormatters.money(_unitCost, symbol: c)}',
                            ),
                            Text(
                              'Precio sugerido c/u: ${AppFormatters.money(_unitPrice, symbol: c)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Ganancia neta est.: ${AppFormatters.money(_estimatedProfit, symbol: c)}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Subtotal: ${AppFormatters.money(_subtotal, symbol: c)}',
                            ),
                            Text(
                              'ITBIS: ${AppFormatters.money(_taxAmount, symbol: c)}',
                            ),
                            Text(
                              'Total: ${AppFormatters.money(_total, symbol: c)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copyQuoteText(),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar WhatsApp'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _saveQuote,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Cotización'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right: Saved quotes
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cotizaciones Guardadas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: widget.controller.quotes.isEmpty
                          ? const Center(
                              child: Text('Aún no hay cotizaciones guardadas.'),
                            )
                          : ListView.separated(
                              itemCount: widget.controller.quotes.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) {
                                final q = widget.controller.quotes[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${q.quoteNumber} • ${q.quantity}x ${q.productName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${q.customerName} • ${AppFormatters.money(q.total, symbol: c)}\n'
                                    'Vence: ${AppFormatters.date(q.validUntil)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Imprimir Hoja 6x8"',
                                        onPressed: () =>
                                            PrintService.printQuote(
                                          quote: q,
                                          settings: widget.controller.settings,
                                          format: PrintPaperFormat.sheet6x8,
                                        ),
                                        icon: const Icon(Icons.print_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Copiar WhatsApp',
                                        onPressed: () =>
                                            _copyQuoteText(quote: q),
                                        icon: const Icon(Icons.chat_outlined),
                                      ),
                                      if (q.convertedOrderId == null)
                                        FilledButton.tonal(
                                          onPressed: () async {
                                            await widget.controller.repository
                                                .convertQuoteToOrder(q);
                                            await widget.controller
                                                .refreshAll();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Convertida en Pedido Personalizado',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('A Pedido'),
                                        )
                                      else
                                        const Chip(
                                          label: Text('Convertida'),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
