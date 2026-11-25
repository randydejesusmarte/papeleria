import 'package:flutter_test/flutter_test.dart';
import 'package:papeleria/data/services/print_service.dart';
import 'package:papeleria/domain/models/app_settings.dart';
import 'package:papeleria/domain/models/custom_order.dart';
import 'package:papeleria/domain/models/quote.dart';
import 'package:papeleria/domain/models/sale.dart';
import 'package:pdf/pdf.dart';

void main() {
  test('sheet6x8 pageFormat is 6x8 inches (432x576 pt)', () {
    final fmt = PrintPaperFormat.sheet6x8.pageFormat;
    expect(fmt.width, closeTo(6 * PdfPageFormat.inch, 0.01));
    expect(fmt.height, closeTo(8 * PdfPageFormat.inch, 0.01));
  });

  test('generates valid PDF bytes for sale in both 80mm ticket and 6x8 sheet',
      () async {
    final sale = Sale(
      receiptNumber: 'FAC-00001',
      customerName: 'María Rodríguez',
      customerRnc: '001-1234567-8',
      isFiscal: true,
      ncf: 'B0100000001',
      ncfType: 'B01',
      subtotal: 350,
      discount: 0,
      taxAmount: 63,
      total: 413,
      paymentMethod: PaymentMethod.efectivo,
      amountPaid: 500,
      changeAmount: 87,
      createdAt: DateTime(2026, 11, 21, 10, 30),
      items: const [
        SaleItem(
          description: 'Taza Blanca 11 oz',
          category: 'blank',
          quantity: 1,
          unitPrice: 350,
          costPrice: 95,
        ),
      ],
    );

    final ticketBytes = await PrintService.buildSalePdf(
      sale: sale,
      settings: AppSettings.defaults,
      format: PrintPaperFormat.ticket80mm,
    );
    expect(ticketBytes, isNotEmpty);

    final sheetBytes = await PrintService.buildSalePdf(
      sale: sale,
      settings: AppSettings.defaults,
      format: PrintPaperFormat.sheet6x8,
    );
    expect(sheetBytes, isNotEmpty);
  });

  test('generates valid PDF bytes for custom order and quote in 6x8 sheet',
      () async {
    final now = DateTime(2026, 11, 21);
    final order = CustomOrder(
      orderNumber: 'PED-0001',
      customerName: 'Colegio Nuevo Horizonte',
      productName: 'Taza Blanca 11 oz',
      technique: 'Sublimación',
      quantity: 12,
      unitPrice: 280,
      subtotal: 3360,
      taxAmount: 604.8,
      total: 3964.8,
      depositPaid: 2000,
      status: OrderStatus.enProduccion,
      dueDate: now.add(const Duration(days: 3)),
      createdAt: now,
      updatedAt: now,
    );

    final orderBytes = await PrintService.buildOrderPdf(
      order: order,
      settings: AppSettings.defaults,
      format: PrintPaperFormat.sheet6x8,
    );
    expect(orderBytes, isNotEmpty);

    final quote = Quote(
      quoteNumber: 'COT-0001',
      customerName: 'Carlos Pérez',
      productName: 'Termo 20 oz',
      technique: 'Grabado Láser',
      baseCost: 320,
      suppliesCost: 20,
      laborCost: 60,
      marginPercent: 50,
      quantity: 5,
      unitPrice: 600,
      subtotal: 3000,
      taxAmount: 540,
      total: 3540,
      validUntil: now.add(const Duration(days: 15)),
      createdAt: now,
    );

    final quoteBytes = await PrintService.buildQuotePdf(
      quote: quote,
      settings: AppSettings.defaults,
      format: PrintPaperFormat.sheet6x8,
    );
    expect(quoteBytes, isNotEmpty);
  });
}
