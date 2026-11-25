import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../cash_reports/cash_reports_view.dart';
import '../customers/customers_view.dart';
import '../inventory/inventory_view.dart';
import '../orders/orders_view.dart';
import '../pos/pos_view.dart';
import '../quoter/quoter_view.dart';
import '../settings/settings_view.dart';

/// Main desktop navigation shell with NavigationRail and live status header.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = widget.controller.settings;
        final cashOpen = widget.controller.openCashSession != null;

        final destinations = [
          const NavigationRailDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: Text('POS'),
          ),
          NavigationRailDestination(
            icon: Badge(
              isLabelVisible: widget.controller.activeOrdersCount > 0,
              label: Text('${widget.controller.activeOrdersCount}'),
              child: const Icon(Icons.design_services_outlined),
            ),
            selectedIcon: const Icon(Icons.design_services),
            label: const Text('Pedidos'),
          ),
          NavigationRailDestination(
            icon: Badge(
              isLabelVisible: widget.controller.lowStockCount > 0,
              label: Text('${widget.controller.lowStockCount}'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: const Icon(Icons.inventory_2),
            label: const Text('Inventario'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: Text('Cotizador'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('Clientes'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: Text('Caja/Rep.'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text('Config.'),
          ),
        ];

        final pages = [
          PosView(controller: widget.controller),
          OrdersView(controller: widget.controller),
          InventoryView(controller: widget.controller),
          QuoterView(controller: widget.controller),
          CustomersView(controller: widget.controller),
          CashReportsView(controller: widget.controller),
          SettingsView(controller: widget.controller),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.storefront,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  settings.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Chip(
                  avatar: Icon(
                    cashOpen ? Icons.lock_open : Icons.lock_outline,
                    size: 16,
                    color: cashOpen ? Colors.green.shade800 : Colors.grey,
                  ),
                  label: Text(cashOpen ? 'Caja abierta' : 'Caja cerrada'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    settings.taxEnabled
                        ? 'ITBIS ${settings.taxRate.toStringAsFixed(0)}%'
                        : 'Sin ITBIS',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: settings.darkMode
                    ? 'Cambiar a modo claro'
                    : 'Cambiar a modo oscuro',
                icon: Icon(
                  settings.darkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  widget.controller.updateSettings(
                    settings.copyWith(darkMode: !settings.darkMode),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                labelType: NavigationRailLabelType.all,
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[_selectedIndex]),
            ],
          ),
        );
      },
    );
  }
}
