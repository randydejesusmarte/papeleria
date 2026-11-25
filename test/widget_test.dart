import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:papeleria/data/repositories/store_repository.dart';
import 'package:papeleria/data/services/local_database_service.dart';
import 'package:papeleria/main.dart';
import 'package:papeleria/ui/core/app_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('PapeleriaApp renders navigation shell with seeded data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late LocalDatabaseService dbService;
    late AppController controller;

    await tester.runAsync(() async {
      dbService = LocalDatabaseService(
        customPath: inMemoryDatabasePath,
        seedSampleData: true,
      );
      final repo = StoreRepository(dbService: dbService);
      controller = AppController(repository: repo);
      await controller.initialize();
    });

    await tester.pumpWidget(PapeleriaApp(controller: controller));
    await tester.pump();

    expect(find.text('Papelería & Personalizados'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('Ticket Actual'), findsOneWidget);

    await tester.runAsync(() async {
      await dbService.close();
    });
  });
}
