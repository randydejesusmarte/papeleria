import 'package:material_ui/material_ui.dart';

import '../../../domain/models/product.dart';
import '../../core/app_controller.dart';
import '../../core/formatters.dart';

/// Dual inventory management for stationery, services, blanks, and supplies.
class InventoryView extends StatefulWidget {
  const InventoryView({super.key, required this.controller});

  final AppController controller;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  ProductCategory? _categoryFilter;
  bool _onlyLowStock = false;
  String _search = '';

  Future<void> _openProductDialog({Product? existing}) async {
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'unidad');
    final costCtrl = TextEditingController(
      text: (existing?.costPrice ?? 0).toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: (existing?.salePrice ?? 0).toStringAsFixed(2),
    );
    final wholesaleCtrl = TextEditingController(
      text: (existing?.wholesalePrice ?? 0).toStringAsFixed(2),
    );
    final wholesaleMinCtrl = TextEditingController(
      text: (existing?.wholesaleMinQty ?? 12).toString(),
    );
    final stockCtrl = TextEditingController(
      text: (existing?.stock ?? 0).toStringAsFixed(0),
    );
    final minStockCtrl = TextEditingController(
      text: (existing?.minStock ?? 5).toStringAsFixed(0),
    );
    ProductCategory category = existing?.category ?? ProductCategory.papeleria;
    bool trackStock = existing?.trackStock ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            existing == null ? 'Nuevo Producto / Insumo' : 'Editar Producto',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: skuCtrl,
                          decoration: const InputDecoration(
                            labelText: 'SKU / Código *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<ProductCategory>(
                          initialValue: category,
                          decoration:
                              const InputDecoration(labelText: 'Categoría'),
                          items: [
                            for (final cat in ProductCategory.values)
                              DropdownMenuItem(
                                value: cat,
                                child: Text(cat.label),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setLocal(() {
                                category = v;
                                if (v == ProductCategory.servicio) {
                                  trackStock = false;
                                }
                              });
                            }
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
                          controller: nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nombre *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unidad (ej. hoja, metro)',
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
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Costo (${widget.controller.currency})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'Precio Venta (${widget.controller.currency})',
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
                          controller: wholesaleCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'Precio Mayoreo (${widget.controller.currency})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: wholesaleMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cant. mínima mayoreo',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: trackStock,
                    onChanged: (v) => setLocal(() => trackStock = v),
                    title: const Text('Controlar inventario / stock'),
                  ),
                  if (trackStock)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Existencia actual',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minStockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock mínimo (alerta)',
                            ),
                          ),
                        ),
                      ],
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
                if (nameCtrl.text.trim().isEmpty || skuCtrl.text.trim().isEmpty) {
                  return;
                }
                final product = Product(
                  id: existing?.id,
                  sku: skuCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  category: category,
                  unit: unitCtrl.text.trim().isEmpty
                      ? 'unidad'
                      : unitCtrl.text.trim(),
                  costPrice: double.tryParse(costCtrl.text.trim()) ?? 0,
                  salePrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                  wholesalePrice:
                      double.tryParse(wholesaleCtrl.text.trim()) ?? 0,
                  wholesaleMinQty:
                      int.tryParse(wholesaleMinCtrl.text.trim()) ?? 12,
                  stock: double.tryParse(stockCtrl.text.trim()) ?? 0,
                  minStock: double.tryParse(minStockCtrl.text.trim()) ?? 0,
                  trackStock: trackStock,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                await widget.controller.repository.saveProduct(product);
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

  Future<void> _adjustStockDialog(Product product) async {
    final deltaCtrl = TextEditingController(text: '10');
    bool isMerma = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Ajustar stock: ${product.name}'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entrada (+)')),
                    ButtonSegment(value: true, label: Text('Merma / Salida (-)')),
                  ],
                  selected: {isMerma},
                  onSelectionChanged: (s) => setLocal(() => isMerma = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deltaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad (${product.unit})',
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(deltaCtrl.text.trim()) ?? 0;
      if (qty > 0 && product.id != null) {
        await widget.controller.repository
            .adjustStock(product.id!, isMerma ? -qty : qty);
        await widget.controller.refreshAll();
      }
    }
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    if (product.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ítem'),
        content: Text(
          '¿Seguro que deseas borrar "${product.name}" (${product.sku}) del inventario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.repository.deleteProduct(product.id!);
      await widget.controller.refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${product.name}" eliminado del inventario')),
        );
      }
    }
  }

  Future<void> _showRowContextMenu(Offset globalPosition, Product p) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        if (p.trackStock)
          const PopupMenuItem(
            value: 'stock',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.exposure),
              title: Text('Entrada / Merma'),
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              'Borrar ítem',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openProductDialog(existing: p);
      case 'stock':
        await _adjustStockDialog(p);
      case 'delete':
        await _confirmDeleteProduct(p);
    }
  }

  DataCell _contextCell(Product p, Widget child) {
    return DataCell(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) =>
            _showRowContextMenu(details.globalPosition, p),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = widget.controller.products;
    final filtered = allProducts.where((p) {
      if (_categoryFilter != null && p.category != _categoryFilter) {
        return false;
      }
      if (_onlyLowStock && !p.isLowStock) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q);
    }).toList();

    final c = widget.controller.currency;
    final totalCostValue = allProducts
        .where((p) => p.trackStock)
        .fold(0.0, (s, p) => s + (p.costPrice * p.stock));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(
                label: 'Total ítems',
                value: '${allProducts.length}',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Stock bajo',
                value: '${widget.controller.lowStockCount}',
                icon: Icons.warning_amber_rounded,
                highlightColor:
                    widget.controller.lowStockCount > 0 ? Colors.red : null,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Valor en costo',
                value: AppFormatters.money(totalCostValue, symbol: c),
                icon: Icons.attach_money,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar Ítem'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por SKU o nombre...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Solo stock bajo'),
                selected: _onlyLowStock,
                onSelected: (v) => setState(() => _onlyLowStock = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: _categoryFilter == null,
                onSelected: (_) => setState(() => _categoryFilter = null),
              ),
              for (final cat in ProductCategory.values)
                FilterChip(
                  label: Text(cat.label),
                  selected: _categoryFilter == cat,
                  onSelected: (_) => setState(
                    () => _categoryFilter =
                        _categoryFilter == cat ? null : cat,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Categoría')),
                      DataColumn(label: Text('Costo'), numeric: true),
                      DataColumn(label: Text('Venta'), numeric: true),
                      DataColumn(label: Text('Mayoreo'), numeric: true),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: [
                      for (final p in filtered)
                        DataRow(
                          cells: [
                            _contextCell(p, Text(p.sku)),
                            _contextCell(p, Text(p.name)),
                            _contextCell(p, Text(p.category.label)),
                            _contextCell(
                              p,
                              Text(AppFormatters.money(p.costPrice, symbol: c)),
                            ),
                            _contextCell(
                              p,
                              Text(AppFormatters.money(p.salePrice, symbol: c)),
                            ),
                            _contextCell(
                              p,
                              Text(
                                p.wholesalePrice > 0
                                    ? '${AppFormatters.money(p.wholesalePrice, symbol: c)} (${p.wholesaleMinQty}+)'
                                    : '-',
                              ),
                            ),
                            _contextCell(
                              p,
                              p.trackStock
                                  ? Text(
                                      '${p.stock.toStringAsFixed(0)} ${p.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: p.isLowStock
                                            ? Colors.red.shade700
                                            : Colors.green.shade800,
                                      ),
                                    )
                                  : const Text('N/A'),
                            ),
                            _contextCell(
                              p,
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p.trackStock)
                                    IconButton(
                                      tooltip: 'Entrada / Merma',
                                      icon: const Icon(Icons.exposure),
                                      onPressed: () => _adjustStockDialog(p),
                                    ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _openProductDialog(existing: p),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: highlightColor ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: highlightColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
