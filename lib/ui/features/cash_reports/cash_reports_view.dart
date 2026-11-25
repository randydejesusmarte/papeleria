import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/store_repository.dart';
import '../../../domain/models/cash_register.dart';
import '../../../domain/models/custom_order.dart';
import '../../core/app_controller.dart';
import '../../core/formatters.dart';

/// Cash register control (open/close/petty cash), accounts receivable, and sales reports.
class CashReportsView extends StatefulWidget {
  const CashReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CashReportsView> createState() => _CashReportsViewState();
}

class _CashReportsViewState extends State<CashReportsView> {
  int _days = 30;
  StoreReportSummary? _summary;
  List<CashSession> _sessions = const [];
  List<CashMovement> _movements = const [];
  double _expectedCash = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = widget.controller.repository;
    final summary = await repo.getReportSummary(days: _days);
    final sessions = await repo.getCashSessions(limit: 15);
    final open = widget.controller.openCashSession;
    List<CashMovement> movs = const [];
    double expected = 0;
    if (open != null && open.id != null) {
      movs = await repo.getMovementsForSession(open.id!);
      expected = await repo.computeExpectedCashInSession(open);
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _sessions = sessions;
      _movements = movs;
      _expectedCash = expected;
    });
  }

  Future<void> _openCashDialog() async {
    final amountCtrl = TextEditingController(text: '2000');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apertura de Caja'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Fondo inicial (${widget.controller.currency})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Caja'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      await widget.controller.repository.openCashSession(amount);
      await widget.controller.refreshAll();
      await _loadData();
    }
  }

  Future<void> _addMovementDialog(CashSession session) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'gasto';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Movimiento de Caja'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'gasto', child: Text('Gasto / Caja Chica')),
                    DropdownMenuItem(value: 'retiro', child: Text('Retiro de efectivo')),
                    DropdownMenuItem(value: 'ingreso', child: Text('Ingreso manual')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => type = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monto (${widget.controller.currency})',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Concepto / Motivo'),
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

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amount > 0 && session.id != null) {
        await widget.controller.repository.addCashMovement(
          CashMovement(
            sessionId: session.id!,
            type: type,
            amount: amount,
            description: descCtrl.text.trim().isEmpty
                ? type
                : descCtrl.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
        await _loadData();
      }
    }
  }

  Future<void> _closeCashDialog(CashSession session) async {
    final countedCtrl = TextEditingController(
      text: _expectedCash.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corte / Cierre de Caja'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Efectivo esperado: ${AppFormatters.money(_expectedCash, symbol: widget.controller.currency)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countedCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Efectivo contado (${widget.controller.currency})',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Observaciones'),
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
            child: const Text('Cerrar Caja'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final counted = double.tryParse(countedCtrl.text.trim()) ?? 0;
      await widget.controller.repository.closeCashSession(
        session: session,
        countedAmount: counted,
        notes: notesCtrl.text.trim(),
      );
      await widget.controller.refreshAll();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller.currency;
    final openSession = widget.controller.openCashSession;
    final pendingOrders = widget.controller.orders
        .where(
          (o) =>
              o.status != OrderStatus.entregado &&
              o.status != OrderStatus.cancelado &&
              o.balanceDue > 0,
        )
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.point_of_sale), text: 'Control de Caja'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Reportes'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Cuentas por Cobrar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Cash Register
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: openSession == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.lock_outline,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'La caja está cerrada actualmente.',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: _openCashDialog,
                                        icon: const Icon(Icons.lock_open),
                                        label: const Text('Abrir Caja'),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Caja Abierta',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                'Desde: ${AppFormatters.dateTime(openSession.openedAt)}',
                                              ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _addMovementDialog(
                                                        openSession),
                                                icon: const Icon(Icons.swap_vert),
                                                label: const Text(
                                                    'Gasto / Movimiento'),
                                              ),
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _closeCashDialog(
                                                        openSession),
                                                icon: const Icon(Icons.lock),
                                                label: const Text('Cerrar Caja'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          _KpiCard(
                                            title: 'Fondo Inicial',
                                            value: AppFormatters.money(
                                              openSession.openingAmount,
                                              symbol: c,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          _KpiCard(
                                            title: 'Efectivo Esperado',
                                            value: AppFormatters.money(
                                              _expectedCash,
                                              symbol: c,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Movimientos del turno',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: _movements.isEmpty
                                            ? const Text(
                                                'Sin gastos ni retiros registrados.',
                                              )
                                            : ListView.separated(
                                                itemCount: _movements.length,
                                                separatorBuilder: (_, _) =>
                                                    const Divider(height: 1),
                                                itemBuilder: (_, idx) {
                                                  final m = _movements[idx];
                                                  final isIn =
                                                      m.type == 'ingreso';
                                                  return ListTile(
                                                    title: Text(m.description),
                                                    subtitle: Text(
                                                      '${m.type.toUpperCase()} • ${AppFormatters.dateTime(m.createdAt)}',
                                                    ),
                                                    trailing: Text(
                                                      '${isIn ? "+" : "-"}${AppFormatters.money(m.amount, symbol: c)}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isIn
                                                            ? Colors.green
                                                            : Colors.red,
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
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Historial de Cortes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _sessions.length,
                                    separatorBuilder: (_, _) => const Divider(),
                                    itemBuilder: (_, idx) {
                                      final s = _sessions[idx];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${AppFormatters.dateTime(s.openedAt)} (${s.status})',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        subtitle: s.isOpen
                                            ? Text(
                                                'Inicial: ${AppFormatters.money(s.openingAmount, symbol: c)}',
                                              )
                                            : Text(
                                                'Contado: ${AppFormatters.money(s.closingAmountCounted, symbol: c)} | Dif: ${AppFormatters.money(s.difference, symbol: c)}',
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
                    ],
                  ),
                ),

                // Tab 2: Reports
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _summary == null
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Periodo:',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                SegmentedButton<int>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 7, label: Text('7 días')),
                                    ButtonSegment(
                                        value: 30, label: Text('30 días')),
                                    ButtonSegment(
                                        value: 90, label: Text('90 días')),
                                  ],
                                  selected: {_days},
                                  onSelectionChanged: (sel) {
                                    setState(() => _days = sel.first);
                                    _loadData();
                                  },
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Actualizar',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _KpiCard(
                                  title: 'Ventas Totales',
                                  value: AppFormatters.money(
                                    _summary!.totalSales,
                                    symbol: c,
                                  ),
                                ),
                                _KpiCard(
                                  title: 'Papelería & Blanks',
                                  value: AppFormatters.money(
                                    _summary!.stationerySales,
                                    symbol: c,
                                  ),
                                ),
                                _KpiCard(
                                  title: 'Servicios Mostrador',
                                  value: AppFormatters.money(
                                    _summary!.serviceSales,
                                    symbol: c,
                                  ),
                                ),
                                _KpiCard(
                                  title: 'Abonos Personalizados',
                                  value: AppFormatters.money(
                                    _summary!.customOrderSales,
                                    symbol: c,
                                  ),
                                ),
                                _KpiCard(
                                  title: 'Utilidad Estimada',
                                  value: AppFormatters.money(
                                    _summary!.estimatedProfit,
                                    symbol: c,
                                  ),
                                ),
                                _KpiCard(
                                  title: 'Gastos / Retiros',
                                  value: AppFormatters.money(
                                    _summary!.totalExpenses,
                                    symbol: c,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Productos y Servicios Más Vendidos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: _summary!.topProducts.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'Aún no hay ventas registradas en este periodo.',
                                                ),
                                              )
                                            : ListView.separated(
                                                itemCount: _summary!
                                                    .topProducts.length,
                                                separatorBuilder: (_, _) =>
                                                    const Divider(height: 1),
                                                itemBuilder: (_, idx) {
                                                  final row = _summary!
                                                      .topProducts[idx];
                                                  return ListTile(
                                                    title: Text(row.name),
                                                    subtitle: Text(
                                                      'Cantidad: ${row.quantitySold.toStringAsFixed(0)}',
                                                    ),
                                                    trailing: Text(
                                                      AppFormatters.money(
                                                        row.revenue,
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
                          ],
                        ),
                ),

                // Tab 3: Accounts Receivable
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldos Pendientes de Pedidos (${pendingOrders.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: pendingOrders.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No hay saldos pendientes por cobrar.',
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: pendingOrders.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, idx) {
                                      final o = pendingOrders[idx];
                                      return ListTile(
                                        title: Text(
                                          '${o.orderNumber} • ${o.customerName}',
                                        ),
                                        subtitle: Text(
                                          '${o.quantity}x ${o.productName} • Estado: ${o.status.label}',
                                        ),
                                        trailing: Text(
                                          'Pendiente: ${AppFormatters.money(o.balanceDue, symbol: c)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}
