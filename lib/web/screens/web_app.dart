import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/rfid_service.dart';
import '../../services/mock_rfid_adapter.dart';
import '../services/floor_plan_service.dart';
import 'web_shell.dart';

/// Root widget for the web application.
///
/// Provides both [RfidService] (using [MockRfidAdapter] since BLE is
/// not available in browsers) and [FloorPlanService].
class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RfidService(hardware: MockRfidAdapter()),
        ),
        ChangeNotifierProvider(create: (_) => FloorPlanService()),
      ],
      child: MaterialApp(
        title: 'RFID Web Console',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        home: const WebShell(),
      ),
    );
  }
}
