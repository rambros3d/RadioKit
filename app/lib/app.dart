import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/serial_provider.dart';
import 'providers/device_provider.dart';
import 'providers/debug_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/history_provider.dart';
import 'providers/console_provider.dart';
import 'router.dart';

class RadioKitApp extends StatefulWidget {
  const RadioKitApp({super.key});

  @override
  State<RadioKitApp> createState() => _RadioKitAppState();
}

class _RadioKitAppState extends State<RadioKitApp> {
  late final BleProvider _bleProvider;
  late final SerialProvider _serialProvider;
  late final DebugProvider _debugProvider;
  late final HistoryProvider _historyProvider;
  late final ConsoleProvider _consoleProvider;
  late final DeviceProvider _deviceProvider;
  late final ConnectionNotifier _connectionNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _bleProvider = BleProvider();
    _serialProvider = SerialProvider();
    _debugProvider = DebugProvider();
    _historyProvider = HistoryProvider();
    _consoleProvider = ConsoleProvider();

    _deviceProvider = DeviceProvider(
      transport: _bleProvider.bleService,
      debugSink: _debugProvider,
      console: _consoleProvider,
    );

    _connectionNotifier = ConnectionNotifier(_deviceProvider);
    _router = createRouter(_connectionNotifier);
  }

  @override
  void dispose() {
    _connectionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
        ChangeNotifierProvider<BleProvider>.value(value: _bleProvider),
        ChangeNotifierProvider<SerialProvider>.value(value: _serialProvider),
        ChangeNotifierProvider<DebugProvider>.value(value: _debugProvider),
        ChangeNotifierProvider<HistoryProvider>.value(value: _historyProvider),
        ChangeNotifierProvider<ConsoleProvider>.value(value: _consoleProvider),
        ChangeNotifierProvider<DeviceProvider>.value(value: _deviceProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'RadioKit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              return ConnectionListener(child: child!);
            },
          );
        },
      ),
    );
  }
}
