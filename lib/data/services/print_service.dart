import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/custom_order.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/sale.dart';
import '../../ui/core/formatters.dart';

/// Supported paper sizes for POS receipts, custom orders, and quotes.
enum PrintPaperFormat {
  ticket80mm('Ticket 80mm'),
  sheet6x8('Hoja 6x8"');

  const PrintPaperFormat(this.label);

  final String label;

  PdfPageFormat get pageFormat {
    switch (this) {
      case PrintPaperFormat.ticket80mm:
        return PdfPageFormat.roll80;
      case PrintPaperFormat.sheet6x8:
        return const PdfPageFormat(
          6 * PdfPageFormat.inch,
          8 * PdfPageFormat.inch,
          marginAll: 0.4 * PdfPageFormat.inch,
        );
    }
  }
}

/// Generates and dispatches PDF documents for 80mm thermal tickets and 6x8" sheets.
class PrintService {
  PrintService._();

  static Future<void> printSale({
    required Sale sale,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    await Printing.layoutPdf(
      name: '${sale.receiptNumber}_${format.name}',
      format: format.pageFormat,
      onLayout: (_) => buildSalePdf(
        sale: sale,
        settings: settings,
        format: format,
      ),
    );
  }

  static Future<void> printCustomOrder({
    required CustomOrder order,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    await Printing.layoutPdf(
      name: '${order.orderNumber}_${format.name}',
      format: format.pageFormat,
      onLayout: (_) => buildOrderPdf(
        order: order,
        settings: settings,
        format: format,
      ),
    );
  }

  static Future<void> printQuote({
    required Quote quote,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    await Printing.layoutPdf(
      name: '${quote.quoteNumber}_${format.name}',
      format: format.pageFormat,
      onLayout: (_) => buildQuotePdf(
        quote: quote,
        settings: settings,
        format: format,
      ),
    );
  }

  static Future<Uint8List> buildSalePdf({
    required Sale sale,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    final doc = pw.Document();
    final c = settings.currencySymbol;
    final isTicket = format == PrintPaperFormat.ticket80mm;

    doc.addPage(
      pw.Page(
        pageFormat: format.pageFormat,
        build: (ctx) => isTicket
            ? _buildTicketSaleLayout(sale, settings, c)
            : _buildSheetSaleLayout(sale, settings, c),
      ),
    );
    return doc.save();
  }

  static pw.Widget _buildTicketSaleLayout(
    Sale sale,
    AppSettings settings,
    String c,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          settings.businessName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (settings.rnc.isNotEmpty)
          pw.Text(
            'RNC: ${settings.rnc}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        if (settings.phone.isNotEmpty)
          pw.Text(
            'Tel: ${settings.phone}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        if (settings.address.isNotEmpty)
          pw.Text(
            settings.address,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        pw.Divider(thickness: 0.5),
        if (sale.isFiscal && sale.ncf.isNotEmpty) ...[
          pw.Text(
            sale.ncfType == 'B01'
                ? 'FACTURA DE CRÉDITO FISCAL'
                : 'FACTURA CON VALOR FISCAL',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('NCF: ${sale.ncf}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          if (settings.ncfValidUntil.isNotEmpty)
            pw.Text('Válido hasta: ${settings.ncfValidUntil}',
                style: const pw.TextStyle(fontSize: 8)),
          pw.Divider(thickness: 0.5),
        ],
        pw.Text('Recibo: ${sale.receiptNumber}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Fecha: ${AppFormatters.dateTime(sale.createdAt)}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Cliente: ${sale.customerName}',
            style: const pw.TextStyle(fontSize: 9)),
        if (sale.customerRnc.isNotEmpty)
          pw.Text('RNC/Cédula: ${sale.customerRnc}',
              style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(thickness: 0.5),
        for (final item in sale.items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)}x ${item.description}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  AppFormatters.money(item.total, symbol: c),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        pw.Divider(thickness: 0.5),
        _pdfRow('Subtotal', AppFormatters.money(sale.subtotal, symbol: c),
            fontSize: 9),
        if (sale.discount > 0)
          _pdfRow(
            'Descuento',
            '-${AppFormatters.money(sale.discount, symbol: c)}',
            fontSize: 9,
          ),
        _pdfRow('ITBIS', AppFormatters.money(sale.taxAmount, symbol: c),
            fontSize: 9),
        _pdfRow(
          'TOTAL',
          AppFormatters.money(sale.total, symbol: c),
          fontSize: 11,
          bold: true,
        ),
        pw.SizedBox(height: 4),
        _pdfRow('Pago (${sale.paymentMethod.label})',
            AppFormatters.money(sale.amountPaid, symbol: c),
            fontSize: 8),
        _pdfRow('Cambio', AppFormatters.money(sale.changeAmount, symbol: c),
            fontSize: 8),
        pw.SizedBox(height: 8),
        pw.Text(
          '¡Gracias por su compra!',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static pw.Widget _buildSheetSaleLayout(
    Sale sale,
    AppSettings settings,
    String c,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sheetHeader(
          settings: settings,
          docTitle: sale.isFiscal && sale.ncf.isNotEmpty
              ? (sale.ncfType == 'B01'
                  ? 'FACTURA DE CRÉDITO FISCAL'
                  : 'FACTURA CON VALOR FISCAL')
              : 'COMPROBANTE DE VENTA',
          docNumber: sale.isFiscal && sale.ncf.isNotEmpty
              ? 'NCF: ${sale.ncf}'
              : sale.receiptNumber,
          dateText: sale.isFiscal && settings.ncfValidUntil.isNotEmpty
              ? '${AppFormatters.dateTime(sale.createdAt)} • Vence: ${settings.ncfValidUntil}'
              : AppFormatters.dateTime(sale.createdAt),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Cliente: ${sale.customerName}',
            style: const pw.TextStyle(fontSize: 10)),
        if (sale.customerRnc.isNotEmpty)
          pw.Text('RNC / Cédula: ${sale.customerRnc}',
              style: const pw.TextStyle(fontSize: 10)),
        if (sale.isFiscal)
          pw.Text('Ref. interna: ${sale.receiptNumber}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text('Método de pago: ${sale.paymentMethod.label}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          headers: const ['Descripción', 'Cant.', 'Precio', 'Total'],
          data: [
            for (final item in sale.items)
              [
                item.description,
                item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1),
                AppFormatters.money(item.unitPrice, symbol: c),
                AppFormatters.money(item.total, symbol: c),
              ],
          ],
        ),
        pw.Spacer(),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 190,
            child: pw.Column(
              children: [
                _pdfRow(
                    'Subtotal', AppFormatters.money(sale.subtotal, symbol: c)),
                if (sale.discount > 0)
                  _pdfRow('Descuento',
                      '-${AppFormatters.money(sale.discount, symbol: c)}'),
                _pdfRow(
                    'ITBIS', AppFormatters.money(sale.taxAmount, symbol: c)),
                pw.Divider(thickness: 0.5),
                _pdfRow(
                  'TOTAL',
                  AppFormatters.money(sale.total, symbol: c),
                  fontSize: 12,
                  bold: true,
                ),
                _pdfRow(
                    'Recibido', AppFormatters.money(sale.amountPaid, symbol: c),
                    fontSize: 9),
                _pdfRow(
                    'Cambio', AppFormatters.money(sale.changeAmount, symbol: c),
                    fontSize: 9),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '¡Gracias por su preferencia!',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static Future<Uint8List> buildOrderPdf({
    required CustomOrder order,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    final doc = pw.Document();
    final c = settings.currencySymbol;
    final isTicket = format == PrintPaperFormat.ticket80mm;

    doc.addPage(
      pw.Page(
        pageFormat: format.pageFormat,
        build: (ctx) {
          if (isTicket) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  settings.businessName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'ORDEN ${order.orderNumber}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(thickness: 0.5),
                pw.Text('Cliente: ${order.customerName}',
                    style: const pw.TextStyle(fontSize: 9)),
                if (order.customerPhone.isNotEmpty)
                  pw.Text('Tel: ${order.customerPhone}',
                      style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Entrega: ${AppFormatters.date(order.dueDate)}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Estado: ${order.status.label}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Divider(thickness: 0.5),
                pw.Text(
                  '${order.quantity}x ${order.productName}',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Técnica: ${order.technique}',
                    style: const pw.TextStyle(fontSize: 9)),
                if (order.colorSize.isNotEmpty)
                  pw.Text('Color/Talla: ${order.colorSize}',
                      style: const pw.TextStyle(fontSize: 9)),
                if (order.customText.isNotEmpty)
                  pw.Text('Texto: ${order.customText}',
                      style: const pw.TextStyle(fontSize: 9)),
                if (order.designNotes.isNotEmpty)
                  pw.Text('Notas: ${order.designNotes}',
                      style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(thickness: 0.5),
                _pdfRow('Total', AppFormatters.money(order.total, symbol: c),
                    bold: true, fontSize: 10),
                _pdfRow('Abonado',
                    AppFormatters.money(order.depositPaid, symbol: c),
                    fontSize: 9),
                _pdfRow('Pendiente',
                    AppFormatters.money(order.balanceDue, symbol: c),
                    bold: true, fontSize: 10),
              ],
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sheetHeader(
                settings: settings,
                docTitle: 'ORDEN DE PERSONALIZACIÓN',
                docNumber: order.orderNumber,
                dateText: 'Entrega: ${AppFormatters.date(order.dueDate)}',
              ),
              pw.SizedBox(height: 12),
              pw.Text('Cliente: ${order.customerName}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (order.customerPhone.isNotEmpty)
                pw.Text('Teléfono: ${order.customerPhone}',
                    style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Estado actual: ${order.status.label}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${order.quantity}x ${order.productName}',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Técnica: ${order.technique}',
                        style: const pw.TextStyle(fontSize: 10)),
                    if (order.colorSize.isNotEmpty)
                      pw.Text('Color / Talla: ${order.colorSize}',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (order.customText.isNotEmpty)
                      pw.Text('Texto a estampar: ${order.customText}',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (order.designNotes.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Notas de diseño: ${order.designNotes}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _pdfRow('Subtotal',
                          AppFormatters.money(order.subtotal, symbol: c)),
                      _pdfRow('ITBIS',
                          AppFormatters.money(order.taxAmount, symbol: c)),
                      _pdfRow(
                          'TOTAL', AppFormatters.money(order.total, symbol: c),
                          bold: true, fontSize: 12),
                      _pdfRow('Abonado',
                          AppFormatters.money(order.depositPaid, symbol: c)),
                      pw.Divider(thickness: 0.5),
                      _pdfRow('SALDO PENDIENTE',
                          AppFormatters.money(order.balanceDue, symbol: c),
                          bold: true, fontSize: 11),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildQuotePdf({
    required Quote quote,
    required AppSettings settings,
    required PrintPaperFormat format,
  }) async {
    final doc = pw.Document();
    final c = settings.currencySymbol;

    doc.addPage(
      pw.Page(
        pageFormat: format.pageFormat,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _sheetHeader(
              settings: settings,
              docTitle: 'COTIZACIÓN',
              docNumber: quote.quoteNumber,
              dateText: 'Válida hasta: ${AppFormatters.date(quote.validUntil)}',
            ),
            pw.SizedBox(height: 12),
            pw.Text('Para: ${quote.customerName}',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              headers: const ['Trabajo / Técnica', 'Cant.', 'Unit.', 'Subtotal'],
              data: [
                [
                  '${quote.productName} (${quote.technique})',
                  '${quote.quantity}',
                  AppFormatters.money(quote.unitPrice, symbol: c),
                  AppFormatters.money(quote.subtotal, symbol: c),
                ],
              ],
            ),
            if (quote.notes.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Notas: ${quote.notes}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 190,
                child: pw.Column(
                  children: [
                    _pdfRow('Subtotal',
                        AppFormatters.money(quote.subtotal, symbol: c)),
                    _pdfRow('ITBIS',
                        AppFormatters.money(quote.taxAmount, symbol: c)),
                    pw.Divider(thickness: 0.5),
                    _pdfRow(
                        'TOTAL', AppFormatters.money(quote.total, symbol: c),
                        bold: true, fontSize: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _sheetHeader({
    required AppSettings settings,
    required String docTitle,
    required String docNumber,
    required String dateText,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                settings.businessName,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (settings.rnc.isNotEmpty)
                pw.Text('RNC: ${settings.rnc}',
                    style: const pw.TextStyle(fontSize: 9)),
              if (settings.phone.isNotEmpty)
                pw.Text('Tel: ${settings.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
              if (settings.address.isNotEmpty)
                pw.Text(settings.address,
                    style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              docTitle,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              docNumber,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(dateText, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _pdfRow(
    String label,
    String value, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
