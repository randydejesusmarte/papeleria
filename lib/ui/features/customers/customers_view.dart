import 'package:material_ui/material_ui.dart';

import '../../../domain/models/customer.dart';
import '../../core/app_controller.dart';
import '../../core/formatters.dart';

/// Customer directory (CRM) with order history and internal design templates library.
class CustomersView extends StatefulWidget {
  const CustomersView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  String _search = '';
  Customer? _selectedCustomer;

  Future<void> _openCustomerDialog({Customer? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final rncCtrl = TextEditingController(text: existing?.rncOrId ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rncCtrl,
                decoration:
                    const InputDecoration(labelText: 'RNC / Cédula (opcional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
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
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final customer = Customer(
                id: existing?.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                rncOrId: rncCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
                createdAt: existing?.createdAt ?? DateTime.now(),
              );
              await widget.controller.repository.saveCustomer(customer);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await widget.controller.refreshAll();
    }
  }

  Future<void> _openTemplateDialog({DesignTemplate? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl =
        TextEditingController(text: existing?.category ?? 'Cumpleaños');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String technique = existing?.technique ?? 'Sublimación';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nueva Plantilla' : 'Editar Plantilla'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Temática (Escolar, Bodas, Cumpleaños...)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: technique,
                  decoration: const InputDecoration(labelText: 'Técnica'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Sublimación', child: Text('Sublimación')),
                    DropdownMenuItem(value: 'DTF', child: Text('DTF')),
                    DropdownMenuItem(
                        value: 'Vinil Textil', child: Text('Vinil Textil')),
                    DropdownMenuItem(
                        value: 'Grabado Láser', child: Text('Grabado Láser')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => technique = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Detalles / Fuentes / Colores',
                  ),
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
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final tpl = DesignTemplate(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  category: catCtrl.text.trim().isEmpty
                      ? 'General'
                      : catCtrl.text.trim(),
                  technique: technique,
                  notes: notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                await widget.controller.repository.saveDesignTemplate(tpl);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await widget.controller.refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.controller.customers.where((c) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.rncOrId.toLowerCase().contains(q);
    }).toList();

    final c = widget.controller.currency;
    final customerOrders = _selectedCustomer == null
        ? const []
        : widget.controller.orders
            .where((o) =>
                o.customerId == _selectedCustomer!.id ||
                o.customerName == _selectedCustomer!.name)
            .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Clientes (CRM)'),
              Tab(
                icon: Icon(Icons.palette_outlined),
                text: 'Plantillas de Diseño',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Customers + History
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) =>
                                        setState(() => _search = v),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Buscar cliente...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () => _openCustomerDialog(),
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Nuevo Cliente'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                itemCount: customers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final cust = customers[index];
                                  final selected =
                                      _selectedCustomer?.id == cust.id;
                                  return Card(
                                    color: selected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.35)
                                        : null,
                                    child: ListTile(
                                      onTap: () => setState(
                                          () => _selectedCustomer = cust),
                                      title: Text(
                                        cust.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        '${cust.phone}${cust.rncOrId.isNotEmpty ? " • RNC/ID: ${cust.rncOrId}" : ""}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _openCustomerDialog(existing: cust),
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
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _selectedCustomer == null
                                ? const Center(
                                    child: Text(
                                      'Selecciona un cliente para ver su historial.',
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedCustomer!.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      if (_selectedCustomer!.notes.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _selectedCustomer!.notes,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      const Divider(height: 24),
                                      const Text(
                                        'Historial de Pedidos',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: customerOrders.isEmpty
                                            ? const Text(
                                                'Sin pedidos personalizados aún.')
                                            : ListView.builder(
                                                itemCount:
                                                    customerOrders.length,
                                                itemBuilder: (_, idx) {
                                                  final o = customerOrders[idx];
                                                  return ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      '${o.orderNumber} • ${o.quantity}x ${o.productName}',
                                                    ),
                                                    subtitle: Text(
                                                      '${o.status.label} • ${AppFormatters.date(o.createdAt)}',
                                                    ),
                                                    trailing: Text(
                                                      AppFormatters.money(
                                                        o.total,
                                                        symbol: c,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                      ),
                    ),
                  ],
                ),
                // Tab 2: Design Templates
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Biblioteca interna de diseños reutilizables',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openTemplateDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva Plantilla'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisExtent: 150,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: widget.controller.templates.length,
                          itemBuilder: (context, index) {
                            final tpl = widget.controller.templates[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Chip(
                                          label: Text(tpl.category),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18),
                                          onPressed: () async {
                                            if (tpl.id != null) {
                                              await widget.controller.repository
                                                  .deleteDesignTemplate(
                                                      tpl.id!);
                                              await widget.controller
                                                  .refreshAll();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(
                                      tpl.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      tpl.technique,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Text(
                                        tpl.notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
