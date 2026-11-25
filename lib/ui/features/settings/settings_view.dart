import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/app_settings.dart';
import '../../core/app_controller.dart';

/// Store profile, theme mode, and configurable tax (ITBIS) settings.
/// Pressing Ctrl + Alt + A opens the protected admin tools (NCF & DB reset).
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Clave predeterminada en el código fuente para acceder a herramientas avanzadas.
  static const String _adminAccessKey = 'ADMIN2026';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _rncCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _taxRateCtrl;
  late bool _taxEnabled;
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _syncFromSettings(widget.controller.settings);
  }

  void _syncFromSettings(AppSettings s) {
    _nameCtrl = TextEditingController(text: s.businessName);
    _rncCtrl = TextEditingController(text: s.rnc);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _currencyCtrl = TextEditingController(text: s.currencySymbol);
    _taxRateCtrl = TextEditingController(text: s.taxRate.toStringAsFixed(1));
    _taxEnabled = s.taxEnabled;
    _darkMode = s.darkMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rncCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _currencyCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = widget.controller.settings;
    final updated = current.copyWith(
      businessName: _nameCtrl.text.trim().isEmpty
          ? 'Papelería & Personalizados'
          : _nameCtrl.text.trim(),
      rnc: _rncCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      currencySymbol: _currencyCtrl.text.trim().isEmpty
          ? 'RD\$'
          : _currencyCtrl.text.trim(),
      taxEnabled: _taxEnabled,
      taxRate: double.tryParse(_taxRateCtrl.text.trim()) ?? 18.0,
      darkMode: _darkMode,
    );

    await widget.controller.updateSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada en SQLite')),
      );
    }
  }

  Future<void> _promptAdminKey() async {
    final keyCtrl = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acceso de Administrador'),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: keyCtrl,
            obscureText: true,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v),
            decoration: const InputDecoration(
              labelText: 'Clave de acceso',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, keyCtrl.text),
            child: const Text('Ingresar'),
          ),
        ],
      ),
    );

    if (!mounted || submitted == null) return;
    if (submitted.trim() != _adminAccessKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clave incorrecta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _openAdminToolsDialog();
  }

  Future<void> _openAdminToolsDialog() async {
    final s = widget.controller.settings;
    String ncfPrefix = s.ncfPrefix;
    final ncfSeqCtrl = TextEditingController(text: s.ncfNextSequence.toString());
    final ncfValidCtrl = TextEditingController(text: s.ncfValidUntil);
    bool keepSettingsOnClear = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined),
              SizedBox(width: 8),
              Text('Herramientas Avanzadas'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración de Comprobantes Fiscales (NCF)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ncfPrefix,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo NCF por defecto',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'B01', child: Text('B01 - Crédito Fiscal')),
                      DropdownMenuItem(
                          value: 'B02', child: Text('B02 - Consumo')),
                      DropdownMenuItem(
                          value: 'B14',
                          child: Text('B14 - Regímenes Especiales')),
                      DropdownMenuItem(
                          value: 'B15', child: Text('B15 - Gubernamental')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => ncfPrefix = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ncfSeqCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Próxima secuencia NCF',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ncfValidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Válido hasta (ej. 31/12/2026)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final updated = widget.controller.settings.copyWith(
                          ncfPrefix: ncfPrefix,
                          ncfNextSequence:
                              (int.tryParse(ncfSeqCtrl.text.trim()) ?? 1)
                                  .clamp(1, 99999999),
                          ncfValidUntil: ncfValidCtrl.text.trim(),
                        );
                        await widget.controller.updateSettings(updated);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Comprobantes fiscales guardados'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar NCF'),
                    ),
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Mantenimiento de Base de Datos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elimina productos, clientes, ventas, pedidos, cotizaciones y cortes de caja.',
                    style: TextStyle(fontSize: 13),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: keepSettingsOnClear,
                    onChanged: (v) =>
                        setLocal(() => keepSettingsOnClear = v ?? true),
                    title: const Text(
                      'Conservar datos del negocio e ITBIS',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (cCtx) => AlertDialog(
                          title: const Text('Confirmar limpieza'),
                          content: const Text(
                            'Esta acción borrará todos los registros de la base de datos local y no se puede deshacer. ¿Continuar?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(cCtx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(cCtx, true),
                              child: const Text('Sí, limpiar DB'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await widget.controller.repository.clearDatabase(
                          keepSettings: keepSettingsOnClear,
                        );
                        await widget.controller.refreshAll();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Base de datos limpiada correctamente'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Limpiar Base de Datos'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA,
            control: true, alt: true): _promptAdminKey,
      },
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 640,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración del Negocio e Impuestos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del negocio',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rncCtrl,
                              decoration: const InputDecoration(
                                labelText: 'RNC del negocio (opcional)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono / WhatsApp',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Dirección'),
                      ),
                      const Divider(height: 32),
                      Text(
                        'Apariencia, Moneda e ITBIS',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _darkMode,
                        onChanged: (v) => setState(() => _darkMode = v),
                        title: const Text('Modo oscuro (Dark Mode)'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _taxEnabled,
                        onChanged: (v) => setState(() => _taxEnabled = v),
                        title: const Text(
                          'Aplicar ITBIS por defecto en ventas y cotizaciones',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _currencyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Símbolo de moneda',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _taxRateCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tasa de impuesto / ITBIS (%)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Cambios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
