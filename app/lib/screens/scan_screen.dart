import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../models/device_info.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'control_screen.dart';

/// BLE device scanner screen.
///
/// Shows discovered RadioKit devices and allows the user to tap one to connect.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // On native, start scanning automatically.
    // On web, the user taps a button to trigger the browser device picker.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BleProvider>().startScan();
      });
    }
  }

  Future<void> _onDeviceTapped(DeviceInfo device) async {
    final bleProvider = context.read<BleProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    // Stop scanning before connecting
    await bleProvider.stopScan();

    if (!mounted) return;

    // Show connecting indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to ${device.displayName}...'),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    await deviceProvider.connectToDevice(device);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (deviceProvider.connectionState == DeviceConnectionState.connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      final error = deviceProvider.errorMessage ?? 'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Row(
              children: [
                _RadioKitLogo(),
                SizedBox(width: 10),
                Text('RadioKit'),
              ],
            ),
            actions: [
              // On web, scanning is triggered via button — no toolbar action
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: bleProvider.isScanning
                      ? const _ScanningIndicator()
                      : IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Rescan',
                          onPressed: () => bleProvider.startScan(),
                        ),
                ),
              
              IconButton(
                icon: Icon(
                  context.watch<ThemeProvider>().isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: () => bleProvider.startScan(),
            child: _buildBody(bleProvider),
          ),
        );
      },
    );
  }

  Widget _buildBody(BleProvider bleProvider) {
    if (bleProvider.errorMessage != null) {
      return _buildErrorState(bleProvider.errorMessage!);
    }

    // Web: show the one-shot browser picker UI
    if (kIsWeb) {
      return _buildWebPickerState(bleProvider);
    }

    if (bleProvider.devices.isEmpty) {
      return _buildEmptyState(bleProvider.isScanning);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: bleProvider.devices.length,
      itemBuilder: (context, index) {
        return _DeviceCard(
          device: bleProvider.devices[index],
          onTap: () => _onDeviceTapped(bleProvider.devices[index]),
        );
      },
    );
  }

  Widget _buildWebPickerState(BleProvider bleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _RadioKitLogo(),
            const SizedBox(height: 32),
            Text(
              'RadioKit Web',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: bleProvider.isAvailable,
              builder: (context, snapshot) {
                final isSupported = bleProvider.isSupported;
                final isAvailable = snapshot.data ?? false;

                String message = 'Ready to connect';
                IconData icon = Icons.check_circle_outline_rounded;
                Color color = AppColors.connected;

                if (!isSupported) {
                  message = 'Browser does not support Web Bluetooth';
                  icon = Icons.error_outline_rounded;
                  color = Theme.of(context).colorScheme.error;
                } else if (!isAvailable && snapshot.connectionState == ConnectionState.done) {
                  message = 'Bluetooth hardware not found or disabled';
                  icon = Icons.bluetooth_disabled_rounded;
                  color = Theme.of(context).colorScheme.error;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Click the button below to open the browser Bluetooth device picker.\n'
              'Make sure your Arduino is powered on and running the RadioKit sketch.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            bleProvider.isScanning
                ? CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.bluetooth_searching_rounded),
                    label: const Text('Connect to Device'),
                    onPressed: () => _startWebConnect(bleProvider),
                  ),
            const SizedBox(height: 32),
            _DemoModeButton(
              onPressed: () => _startDemoMode(bleProvider),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _startWebConnect(BleProvider bleProvider) async {
    // Trigger the browser's device picker
    await bleProvider.startScan();

    if (!mounted) return;

    final devices = bleProvider.devices;
    if (devices.isNotEmpty) {
      // A device was selected — connect immediately
      await _onDeviceTapped(devices.first);
    }
  }

  void _startDemoMode(BleProvider bleProvider) async {
    // 1. Inject the mock device into the list
    bleProvider.useMockDevice();
    
    // 2. Tapping it will trigger the standard connection flow
    // which eventually calls BleService._handleMockConnect
    final device = bleProvider.devices.first;
    await _onDeviceTapped(device);
  }

  void _startMockConnect(BleProvider bleProvider) {
    bleProvider.useMockDevice();
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isScanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.bluetooth_disabled_rounded,
              size: 72,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 24),
            Text(
              isScanning ? 'Scanning for devices...' : 'No RadioKit devices found.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isScanning
                  ? 'Make sure your Arduino device is powered on and running the RadioKit library.'
                  : 'No RadioKit devices found. Make sure your device is powered on.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (isScanning) ...[
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: AppColors.brandOrange,
                strokeWidth: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Bluetooth Error',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open Settings'),
              onPressed: () {
                // openAppSettings() from permission_handler
                // This would open system settings to enable BLE permissions
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ScanningIndicator extends StatefulWidget {
  const _ScanningIndicator();

  @override
  State<_ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<_ScanningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

/// Device list card showing name, ID, and signal strength.
class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // BLE icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bluetooth_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.id,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Signal strength + RSSI
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SignalBars(bars: device.signalBars),
                  const SizedBox(height: 3),
                  Text(
                    '${device.rssi} dBm',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signal strength bar indicator (1-4 bars).
class _SignalBars extends StatelessWidget {
  final int bars;

  const _SignalBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = (i + 1) <= bars;
        return Container(
          width: 5,
          height: 6.0 + i * 3.0,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.connected : Theme.of(context).disabledColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}

/// Inline SVG-style RadioKit logo mark.
class _RadioKitLogo extends StatelessWidget {
  const _RadioKitLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    final outerRingPaint = Paint()
      ..color = AppColors.brandOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final innerDotPaint = Paint()
      ..color = AppColors.brandOrange
      ..style = PaintingStyle.fill;

    final signalPaint = Paint()
      ..color = AppColors.brandOrange.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Outer circle
    canvas.drawCircle(center, r - 2, outerRingPaint);

    // Inner dot
    canvas.drawCircle(center, 4, innerDotPaint);

    // Radio wave arcs (left side)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: r * 1.0, height: r * 1.0),
      2.5,
      1.3,
      false,
      signalPaint,
    );

    // Radio wave arcs (right side — mirror)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: r * 1.0, height: r * 1.0),
      -0.8,
      1.3,
      false,
      signalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _DemoModeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DemoModeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Try Interactive Demo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
