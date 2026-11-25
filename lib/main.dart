import 'package:material_ui/material_ui.dart';

import 'data/repositories/store_repository.dart';
import 'data/services/local_database_service.dart';
import 'ui/core/app_controller.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = LocalDatabaseService();
  final repository = StoreRepository(dbService: dbService);
  final controller = AppController(repository: repository);
  await controller.initialize();

  runApp(PapeleriaApp(controller: controller));
}

class PapeleriaApp extends StatelessWidget {
  const PapeleriaApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Papelería & Personalizados',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode:
              controller.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainShell(controller: controller),
        );
      },
    );
  }
}
