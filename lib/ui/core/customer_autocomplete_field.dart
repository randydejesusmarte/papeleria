import 'package:material_ui/material_ui.dart';

import '../../domain/models/customer.dart';

/// Searchable customer input that allows picking a registered customer
/// or typing any walk-in customer name directly.
class CustomerAutocompleteField extends StatefulWidget {
  const CustomerAutocompleteField({
    super.key,
    required this.customers,
    required this.controller,
    required this.onCustomerChanged,
    this.labelText = 'Cliente (opcional)',
    this.hintText = 'Cliente general o escribe un nombre...',
  });

  final List<Customer> customers;
  final TextEditingController controller;
  final ValueChanged<Customer?> onCustomerChanged;
  final String labelText;
  final String hintText;

  @override
  State<CustomerAutocompleteField> createState() =>
      _CustomerAutocompleteFieldState();
}

class _CustomerAutocompleteFieldState extends State<CustomerAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<Customer>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          displayStringForOption: (c) => c.name,
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) return widget.customers;
            return widget.customers.where(
              (c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.phone.toLowerCase().contains(q) ||
                  c.rncOrId.toLowerCase().contains(q),
            );
          },
          onSelected: (customer) {
            widget.onCustomerChanged(customer);
          },
          fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textCtrl,
              focusNode: focusNode,
              onChanged: (value) {
                final trimmed = value.trim().toLowerCase();
                Customer? exactMatch;
                for (final c in widget.customers) {
                  if (c.name.toLowerCase() == trimmed) {
                    exactMatch = c;
                    break;
                  }
                }
                widget.onCustomerChanged(exactMatch);
              },
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: textCtrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpiar cliente',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          textCtrl.clear();
                          widget.onCustomerChanged(null);
                        },
                      )
                    : null,
              ),
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(option.name),
                        subtitle: (option.phone.isNotEmpty ||
                                option.rncOrId.isNotEmpty)
                            ? Text(
                                [
                                  if (option.phone.isNotEmpty) option.phone,
                                  if (option.rncOrId.isNotEmpty)
                                    'RNC: ${option.rncOrId}',
                                ].join(' • '),
                              )
                            : null,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
