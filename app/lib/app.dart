import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/device_provider.dart';
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
        // BleProvider owns the BleService instance
        ChangeNotifierProvider<BleProvider>(
          create: (_) => BleProvider(),
        ),

        // DeviceProvider shares the BleService from BleProvider
        ChangeNotifierProxyProvider<BleProvider, DeviceProvider>(
          create: (context) => DeviceProvider(
            bleService: context.read<BleProvider>().bleService,
          ),
          update: (context, bleProvider, previous) =>
              previous ??
              DeviceProvider(bleService: bleProvider.bleService),
        ),
      ],
      child: MaterialApp(
        title: 'RadioKit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const ScanScreen(),
      ),
    );
  }
}
