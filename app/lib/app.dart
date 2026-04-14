import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/serial_provider.dart';
import 'providers/device_provider.dart';
import 'providers/debug_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/scan_screen.dart';

/// Root application widget.
class RadioKitApp extends StatelessWidget {
  const RadioKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (_) => BleProvider(),
        ),
        ChangeNotifierProvider<SerialProvider>(
          create: (_) => SerialProvider(),
        ),
        // DebugProvider is always registered; DebugTransport is only
        // activated in debug builds (see control_screen.dart FAB).
        ChangeNotifierProvider<DebugProvider>(
          create: (_) => DebugProvider(),
        ),
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
