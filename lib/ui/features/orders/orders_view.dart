import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/print_service.dart';
import '../../../domain/models/custom_order.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/sale.dart';
import '../../core/app_controller.dart';
import '../../core/formatters.dart';

/// Custom personalization orders (work orders, deposits, design notes, and due dates).
class OrdersView extends StatefulWidget {
  const OrdersView({super.key, required this.controller});

  final AppController controller;

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  OrderStatus? _statusFilter;
  String _search = '';

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.cotizado:
        return Colors.grey.shade700;
      case OrderStatus.conAnticipo:
        return Colors.blue.shade700;
      case OrderStatus.enDiseno:
        return Colors.purple.shade700;
      case OrderStatus.enProduccion:
        return Colors.orange.shade800;
      case OrderStatus.listo:
        return Colors.green.shade700;
      case OrderStatus.entregado:
        return Colors.teal.shade700;
      case OrderStatus.cancelado:
        return Colors.red.shade700;
    }
  }

  Future<void> _openOrderDialog({CustomOrder? existing}) async {
    final repo = widget.controller.repository;
    final settings = widget.controller.settings;

    Customer? selectedCustomer;
    if (existing?.customerId != null) {
      for (final c in widget.controller.customers) {
        if (c.id == existing!.customerId) {
          selectedCustomer = c;
          break;
        }
      }
    }

    Product? selectedBlank;
    if (existing?.baseProductId != null) {
      for (final p in widget.controller.products) {
        if (p.id == existing!.baseProductId) {
          selectedBlank = p;
          break;
        }
      }
    }

    final customerNameCtrl =
        TextEditingController(text: existing?.customerName ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.customerPhone ?? '');
    final productCtrl =
        TextEditingController(text: existing?.productName ?? '');
    final colorSizeCtrl =
        TextEditingController(text: existing?.colorSize ?? '');
    final customTextCtrl =
        TextEditingController(text: existing?.customText ?? '');
    final designNotesCtrl =
        TextEditingController(text: existing?.designNotes ?? '');
    final imagePathCtrl =
        TextEditingController(text: existing?.designImagePath ?? '');
    final qtyCtrl =
        TextEditingController(text: (existing?.quantity ?? 1).toString());
    final priceCtrl = TextEditingController(
      text: (existing?.unitPrice ?? 350).toStringAsFixed(2),
    );
    final depositCtrl = TextEditingController(
      text: (existing?.depositPaid ?? 0).toStringAsFixed(2),
    );

    String technique = existing?.technique ?? 'Sublimación';
    DateTime dueDate =
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 3));
    bool applyTax = existing != null
        ? existing.taxAmount > 0
        : settings.taxEnabled;
    bool deductStock = existing == null;

    final blanks = widget.controller.products
        .where((p) => p.category == ProductCategory.blank)
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
          final unit = double.tryParse(priceCtrl.text.trim()) ?? 0;
          final subtotal = qty * unit;
          final tax = applyTax ? subtotal * (settings.taxRate / 100) : 0.0;
          final total = subtotal + tax;

          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Nuevo Pedido Personalizado'
                  : 'Editar ${existing.orderNumber}',
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Customer?>(
                            initialValue: selectedCustomer,
                            decoration: const InputDecoration(
                              labelText: 'Cliente registrado (opcional)',
                            ),
                            items: [
                              const DropdownMenuItem<Customer?>(
                                value: null,
                                child: Text('Escribir cliente manual'),
                              ),
                              for (final c in widget.controller.customers)
                                DropdownMenuItem<Customer?>(
                                  value: c,
                                  child: Text(c.name),
                                ),
                            ],
                            onChanged: (c) {
                              setLocal(() {
                                selectedCustomer = c;
                                if (c != null) {
                                  customerNameCtrl.text = c.name;
                                  phoneCtrl.text = c.phone;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: customerNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del cliente *',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono / WhatsApp',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<Product?>(
                            initialValue: selectedBlank,
                            decoration: const InputDecoration(
                              labelText: 'Objeto base (Blank)',
                            ),
                            items: [
                              const DropdownMenuItem<Product?>(
                                value: null,
                                child: Text('Personalizado / otro'),
                              ),
                              for (final b in blanks)
                                DropdownMenuItem<Product?>(
                                  value: b,
                                  child: Text(
                                    '${b.name} (${b.stock.toStringAsFixed(0)} disp.)',
                                  ),
                                ),
                            ],
                            onChanged: (b) {
                              setLocal(() {
                                selectedBlank = b;
                                if (b != null) {
                                  productCtrl.text = b.name;
                                  priceCtrl.text =
                                      b.salePrice.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: productCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Descripción del objeto *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: technique,
                            decoration:
                                const InputDecoration(labelText: 'Técnica'),
                            items: const [
                              DropdownMenuItem(
                                value: 'Sublimación',
                                child: Text('Sublimación'),
                              ),
                              DropdownMenuItem(
                                value: 'DTF',
                                child: Text('DTF'),
                              ),
                              DropdownMenuItem(
                                value: 'Vinil Textil',
                                child: Text('Vinil Textil'),
                              ),
                              DropdownMenuItem(
                                value: 'Vinil Adhesivo',
                                child: Text('Vinil Adhesivo'),
                              ),
                              DropdownMenuItem(
                                value: 'Grabado Láser',
                                child: Text('Grabado Láser'),
                              ),
                              DropdownMenuItem(
                                value: 'Otro',
                                child: Text('Otro'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setLocal(() => technique = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: colorSizeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Color / Talla / Capacidad',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: customTextCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Texto o nombre a estampar',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: designNotesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas de diseño / especificaciones',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imagePathCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Ruta local de imagen / mockup (opcional)',
                        hintText: '/home/.../diseno.png',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setLocal(() {}),
                            decoration:
                                const InputDecoration(labelText: 'Cantidad'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setLocal(() {}),
                            decoration: InputDecoration(
                              labelText: 'Precio unit. (${settings.currencySymbol})',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: depositCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Anticipo (${settings.currencySymbol})',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setLocal(() => dueDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            'Entrega: ${AppFormatters.date(dueDate)}',
                          ),
                        ),
                        const Spacer(),
                        FilterChip(
                          label: Text(
                            'ITBIS ${settings.taxRate.toStringAsFixed(0)}%',
                          ),
                          selected: applyTax,
                          onSelected: (v) => setLocal(() => applyTax = v),
                        ),
                      ],
                    ),
                    if (existing == null && selectedBlank != null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: deductStock,
                        onChanged: (v) =>
                            setLocal(() => deductStock = v ?? false),
                        title: const Text(
                          'Descontar objeto base del inventario al crear',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: ${AppFormatters.money(total, symbol: settings.currencySymbol)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (customerNameCtrl.text.trim().isEmpty ||
                      productCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final now = DateTime.now();
                  final orderNumber = existing?.orderNumber ??
                      await repo.generateNextOrderNumber();
                  final deposit = double.tryParse(depositCtrl.text.trim()) ?? 0;
                  final status = existing?.status ??
                      (deposit > 0
                          ? OrderStatus.conAnticipo
                          : OrderStatus.cotizado);

                  final order = CustomOrder(
                    id: existing?.id,
                    orderNumber: orderNumber,
                    customerId: selectedCustomer?.id ?? existing?.customerId,
                    customerName: customerNameCtrl.text.trim(),
                    customerPhone: phoneCtrl.text.trim(),
                    baseProductId: selectedBlank?.id ?? existing?.baseProductId,
                    productName: productCtrl.text.trim(),
                    technique: technique,
                    colorSize: colorSizeCtrl.text.trim(),
                    customText: customTextCtrl.text.trim(),
                    designNotes: designNotesCtrl.text.trim(),
                    designImagePath: imagePathCtrl.text.trim(),
                    quantity: qty,
                    unitPrice: unit,
                    subtotal: subtotal,
                    taxAmount: tax,
                    total: total,
                    depositPaid: deposit,
                    status: status,
                    dueDate: dueDate,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  );

                  await repo.saveCustomOrder(
                    order,
                    deductBaseProductStock: existing == null && deductStock,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Guardar Pedido'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      await widget.controller.refreshAll();
    }
  }

  Future<void> _registerPayment(CustomOrder order) async {
    final amountCtrl = TextEditingController(
      text: order.balanceDue.toStringAsFixed(2),
    );
    PaymentMethod method = PaymentMethod.efectivo;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Registrar pago - ${order.orderNumber}'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo pendiente: ${AppFormatters.money(order.balanceDue, symbol: widget.controller.currency)}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monto a abonar (${widget.controller.currency})',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                  items: [
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => method = v);
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
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amount > 0) {
        await widget.controller.repository.recordOrderPayment(
          order: order,
          paymentAmount: amount,
          paymentMethod: method,
          cashSessionId: widget.controller.openCashSession?.id,
        );
        await widget.controller.refreshAll();
      }
    }
  }

  void _copyWhatsAppNotice(CustomOrder order) {
    final c = widget.controller.currency;
    final msg = 'Hola ${order.customerName}, te saludamos de '
        '${widget.controller.settings.businessName}. '
        'Tu pedido ${order.orderNumber} (${order.quantity}x ${order.productName}) '
        'se encuentra en estado: *${order.status.label}*. '
        '${order.balanceDue > 0 ? "Saldo pendiente: ${AppFormatters.money(order.balanceDue, symbol: c)}." : "¡Pagado en su totalidad!"}';
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje para WhatsApp copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.controller.orders.where((o) {
      if (_statusFilter != null && o.status != _statusFilter) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.productName.toLowerCase().contains(q);
    }).toList();

    final c = widget.controller.currency;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por # pedido, cliente o producto...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openOrderDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Pedido'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                for (final s in OrderStatus.values) ...[
                  FilterChip(
                    label: Text(s.label),
                    selected: _statusFilter == s,
                    onSelected: (_) => setState(
                      () => _statusFilter = _statusFilter == s ? null : s,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Text('No hay pedidos en esta vista.'),
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      final hasImage = o.designImagePath.isNotEmpty &&
                          File(o.designImagePath).existsSync();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasImage) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(o.designImagePath),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          o.orderNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(o.status)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            o.status.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _statusColor(o.status),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (o.isOverdue)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Atrasado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${o.quantity}x ${o.productName} • ${o.technique}'
                                      '${o.colorSize.isNotEmpty ? " (${o.colorSize})" : ""}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Cliente: ${o.customerName}'
                                      '${o.customerPhone.isNotEmpty ? " (${o.customerPhone})" : ""}'
                                      ' • Entrega: ${AppFormatters.date(o.dueDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    if (o.customText.isNotEmpty ||
                                        o.designNotes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Diseño: ${o.customText} ${o.designNotes}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total: ${AppFormatters.money(o.total, symbol: c)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Abonado: ${AppFormatters.money(o.depositPaid, symbol: c)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Pendiente: ${AppFormatters.money(o.balanceDue, symbol: c)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: o.balanceDue > 0
                                          ? Colors.deepOrange
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      PopupMenuButton<OrderStatus>(
                                        tooltip: 'Cambiar estado',
                                        onSelected: (next) async {
                                          await widget.controller.repository
                                              .updateOrderStatus(o.id!, next);
                                          await widget.controller.refreshAll();
                                        },
                                        itemBuilder: (_) => [
                                          for (final s in OrderStatus.values)
                                            PopupMenuItem(
                                              value: s,
                                              child: Text(s.label),
                                            ),
                                        ],
                                        child: const Chip(
                                          avatar: Icon(Icons.sync_alt, size: 16),
                                          label: Text('Estado'),
                                        ),
                                      ),
                                      if (o.balanceDue > 0)
                                        OutlinedButton.icon(
                                          onPressed: () => _registerPayment(o),
                                          icon: const Icon(Icons.payments_outlined,
                                              size: 16),
                                          label: const Text('Abonar'),
                                        ),
                                      PopupMenuButton<PrintPaperFormat>(
                                        tooltip: 'Imprimir orden',
                                        onSelected: (fmt) =>
                                            PrintService.printCustomOrder(
                                          order: o,
                                          settings: widget.controller.settings,
                                          format: fmt,
                                        ),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: PrintPaperFormat.ticket80mm,
                                            child: Text('Imprimir Ticket 80mm'),
                                          ),
                                          PopupMenuItem(
                                            value: PrintPaperFormat.sheet6x8,
                                            child: Text('Imprimir Hoja 6x8"'),
                                          ),
                                        ],
                                        icon: const Icon(Icons.print_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Copiar aviso WhatsApp',
                                        onPressed: () => _copyWhatsAppNotice(o),
                                        icon: const Icon(Icons.chat_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Editar pedido',
                                        onPressed: () =>
                                            _openOrderDialog(existing: o),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
