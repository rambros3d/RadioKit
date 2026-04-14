import 'dart:math' show pi;
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
/// Renders widgets on an orientation-aware virtual canvas:
///   Landscape: 200 × 100  (origin bottom-left, Y increases upward)
///   Portrait:  100 × 200
///
/// Each widget [x, y] is its CENTER point in virtual space.
/// Coordinate transform to Flutter screen pixels:
///   scaleX  = physicalW / canvasW
///   scaleY  = physicalH / canvasH
///   screenX = x * scaleX
///   screenY = (canvasH - y) * scaleY   ← Y-axis flip
///   topLeft = (screenX - w/2 * scaleX,  screenY - h/2 * scaleY)
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
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
                  foregroundColor: Theme.of(context).colorScheme.error,
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
            color: AppColors.brandOrange,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
                size: 64, color: AppColors.brandRed),
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

  /// Returns the virtual canvas (width, height) based on orientation.
  (double, double) _canvasDimensions(int orientation) {
    if (orientation == kOrientationPortrait) {
      return (kCanvasPortraitW, kCanvasPortraitH);
    }
    return (kCanvasLandscapeW, kCanvasLandscapeH);
  }

  /// Build the main widget canvas.
  Widget _buildCanvas(DeviceProvider deviceProvider) {
    final orientation = deviceProvider.orientation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final (canvasVW, canvasVH) = _canvasDimensions(orientation);

        // Fit the virtual canvas into available space, preserving aspect ratio.
        const padding = 16.0;
        final availW = constraints.maxWidth  - padding * 2;
        final availH = constraints.maxHeight - padding * 2;
        final aspectRatio = canvasVW / canvasVH;

        double physW, physH;
        if (availW / availH > aspectRatio) {
          physH = availH;
          physW = physH * aspectRatio;
        } else {
          physW = availW;
          physH = physW / aspectRatio;
        }

        final scaleX = physW / canvasVW;
        final scaleY = physH / canvasVH;

        return Center(
          child: Container(
            width: physW,
            height: physH,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: Theme.of(context).dividerColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(physW, physH),
                    painter: _GridPainter(
                      color:
                          Theme.of(context).dividerColor.withOpacity(0.3),
                    ),
                  ),
                  ...deviceProvider.widgets.map((config) {
                    return _buildPositionedWidget(
                      config,
                      scaleX,
                      scaleY,
                      canvasVH,
                      deviceProvider,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Position and rotate a widget from its virtual-canvas center coordinates.
  ///
  /// Transform steps:
  ///   1. Y-axis flip: screenY = (canvasH - virtualY) * scaleY
  ///   2. Center → top-left: subtract half scaled size
  ///   3. Wrap in Transform.rotate with center alignment
  Widget _buildPositionedWidget(
    WidgetConfig config,
    double scaleX,
    double scaleY,
    double canvasVH,
    DeviceProvider deviceProvider,
  ) {
    final scaledW = config.w * scaleX;
    final scaledH = config.h * scaleY;

    // X: left-to-right, origin bottom-left
    final screenX = config.x * scaleX;
    // Y: flip so that y=0 maps to bottom of physical canvas
    final screenY = (canvasVH - config.y) * scaleY;

    final left = screenX - scaledW / 2;
    final top  = screenY - scaledH / 2;

    final angleRad = config.rotationDegrees * pi / 180.0;

    final state = deviceProvider.widgetState;

    return Positioned(
      left: left,
      top: top,
      width: scaledW,
      height: scaledH,
      child: Transform.rotate(
        angle: angleRad,
        alignment: Alignment.center,
        child: _buildWidgetForConfig(config, state, deviceProvider),
      ),
    );
  }

  Widget _buildWidgetForConfig(
      WidgetConfig config,
      RadioWidgetState? state,
      DeviceProvider deviceProvider) {
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
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
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
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 50.0;
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
