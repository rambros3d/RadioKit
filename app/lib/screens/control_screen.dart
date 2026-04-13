import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';
import '../widgets/button_widget.dart';
import '../widgets/switch_widget.dart';
import '../widgets/slider_widget.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/led_widget.dart';
import '../widgets/text_widget.dart';

/// Dynamic widget rendering screen for the connected RadioKit device.
///
/// Positions widgets on a virtual 1000×1000 canvas, scaled to the actual
/// screen dimensions while maintaining aspect ratio.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();

    // Watch for disconnection and auto-navigate back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForDisconnect();
    });
  }

  void _listenForDisconnect() {
    final deviceProvider = context.read<DeviceProvider>();
    deviceProvider.addListener(_checkConnection);
  }

  void _checkConnection() {
    if (!mounted) return;
    final deviceProvider = context.read<DeviceProvider>();
    if (deviceProvider.connectionState == DeviceConnectionState.disconnected &&
        !deviceProvider.isConnected) {
      // Remove listener to avoid duplicate calls
      deviceProvider.removeListener(_checkConnection);

      final reason = deviceProvider.errorMessage ?? 'Device disconnected';
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: AppColors.disconnected,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    final deviceProvider = context.read<DeviceProvider>();
    deviceProvider.removeListener(_checkConnection);
    super.dispose();
  }

  Future<void> _disconnect() async {
    final deviceProvider = context.read<DeviceProvider>();
    deviceProvider.removeListener(_checkConnection);
    await deviceProvider.disconnect();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        final device = deviceProvider.connectedDevice;
        final isConnected = deviceProvider.isConnected;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                // Connection status dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.connected
                        : AppColors.disconnected,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected
                                ? AppColors.connected
                                : AppColors.disconnected)
                            .withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    device?.displayName ?? 'RadioKit Device',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
                label: const Text('Disconnect'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.disconnected,
                ),
                onPressed: _disconnect,
              ),
            ],
          ),
          body: _buildBody(deviceProvider),
        );
      },
    );
  }

  Widget _buildBody(DeviceProvider deviceProvider) {
    switch (deviceProvider.connectionState) {
      case DeviceConnectionState.fetchingConfig:
        return _buildLoadingState('Loading device configuration...');

      case DeviceConnectionState.error:
        return _buildErrorState(
            deviceProvider.errorMessage ?? 'Unknown error', deviceProvider);

      case DeviceConnectionState.connected:
        return _buildCanvas(deviceProvider);

      default:
        return _buildLoadingState('Connecting...');
    }
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.highlight,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, DeviceProvider deviceProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.disconnected),
            const SizedBox(height: 20),
            Text('Connection Error',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: () async {
                final device = deviceProvider.connectedDevice;
                if (device != null) {
                  await deviceProvider.connectToDevice(device);
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _disconnect,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the main widget canvas.
  Widget _buildCanvas(DeviceProvider deviceProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = _computeCanvasSize(constraints);
        final scale = canvasSize / 1000.0;

        return Center(
          child: Container(
            width: canvasSize,
            height: canvasSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.widgetBorder, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Grid background
                  CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: _GridPainter(),
                  ),

                  // Positioned widgets
                  ...deviceProvider.widgets.map((config) {
                    return _buildPositionedWidget(
                        config, scale, deviceProvider);
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Compute the canvas size (square) fitting within the available space.
  double _computeCanvasSize(BoxConstraints constraints) {
    const padding = 16.0;
    final availableWidth = constraints.maxWidth - padding * 2;
    final availableHeight = constraints.maxHeight - padding * 2;
    return availableWidth < availableHeight ? availableWidth : availableHeight;
  }

  /// Build a positioned widget from its config.
  Widget _buildPositionedWidget(
      WidgetConfig config, double scale, DeviceProvider deviceProvider) {
    final left = config.x * scale;
    final top = config.y * scale;
    final width = config.w * scale;
    final height = config.h * scale;

    final state = deviceProvider.widgetState;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _buildWidgetForConfig(config, state, deviceProvider),
    );
  }

  Widget _buildWidgetForConfig(
      WidgetConfig config, WidgetState? state, DeviceProvider deviceProvider) {
    switch (config.typeId) {
      case kWidgetButton:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return ButtonWidget(
          config: config,
          value: value,
          onChanged: (v) =>
              deviceProvider.setInputValue(config.widgetId, [v]),
        );

      case kWidgetSwitch:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return SwitchWidget(
          config: config,
          value: value,
          onChanged: (v) =>
              deviceProvider.setInputValue(config.widgetId, [v]),
        );

      case kWidgetSlider:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return SliderWidget(
          config: config,
          value: value,
          onChanged: (v) =>
              deviceProvider.setInputValue(config.widgetId, [v]),
        );

      case kWidgetJoystick:
        final values = state?.inputValues[config.widgetId] ?? [0, 0];
        final x = values.isNotEmpty ? values[0] : 0;
        final y = values.length > 1 ? values[1] : 0;
        return JoystickWidget(
          config: config,
          x: x,
          y: y,
          onChanged: (x, y) =>
              deviceProvider.setInputValue(config.widgetId, [x, y]),
        );

      case kWidgetLed:
        final value = state?.outputValues[config.widgetId] ?? 0;
        return LedWidget(config: config, value: value as int);

      case kWidgetText:
        final value = state?.outputValues[config.widgetId] ?? '';
        return TextWidget(config: config, text: value.toString());

      default:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.widgetCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.widgetBorder),
          ),
          child: Center(
            child: Text(
              'Unknown\n${config.widgetId}',
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Grid background painter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.widgetBorder.withOpacity(0.3)
      ..strokeWidth = 0.5;

    const spacing = 50.0; // 50px grid
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (int i = 0; i <= cols; i++) {
      final x = i * spacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int i = 0; i <= rows; i++) {
      final y = i * spacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
