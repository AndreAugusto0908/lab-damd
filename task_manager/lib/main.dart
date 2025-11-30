import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';      // ← ADICIONAR
import 'widgets/connectivity_banner.dart';
import 'screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar banco de dados (cria tabelas incluindo sync_queue)
  await DatabaseService.instance.database;    // ← ADICIONAR
  
  // Inicializar câmera
  await CameraService.instance.initialize();
  
  // Inicializar conectividade
  await ConnectivityService.instance.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ConnectivityBanner(
        child: TaskListScreen(),
      ),
    );
  }
}