import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/serial_provider.dart';
import 'providers/device_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/scan_screen.dart';

/// Root application widget.
///
/// Sets up the Provider tree, theme, and initial route.
class RadioKitApp extends StatelessWidget {
  const RadioKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        // BleProvider owns the BleService instance
        ChangeNotifierProvider<BleProvider>(
          create: (_) => BleProvider(),
        ),
        // SerialProvider owns the SerialService instance
        ChangeNotifierProvider<SerialProvider>(
          create: (_) => SerialProvider(),
        ),
        // DeviceProvider is transport-agnostic; starts with BLE transport.
        // ScanScreen swaps the transport before calling connectToDevice().
        ChangeNotifierProxyProvider2<BleProvider, SerialProvider, DeviceProvider>(
          create: (context) => DeviceProvider(
            transport: context.read<BleProvider>().bleService,
          ),
          update: (context, bleProvider, serialProvider, previous) =>
              previous ??
              DeviceProvider(transport: bleProvider.bleService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'RadioKit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const ScanScreen(),
          );
        },
      ),
    );
  }
}
