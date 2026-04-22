import 'dart:math' show pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/debug_provider.dart';
import '../services/debug_transport.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';
import '../widgets/button_widget.dart';
import '../widgets/switch_widget.dart';
import '../widgets/slide_switch_widget.dart';
import '../widgets/slider_widget.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/led_widget.dart';
import '../widgets/text_widget.dart';
import '../widgets/multiple_widget.dart';
import '../widgets/knob_widget.dart';
import '../theme/skin/skin_manager.dart';
import '../theme/skin/skin_tokens.dart';

/// Dynamic widget rendering screen for the connected RadioKit device.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _debugWrapped = false;

  Future<void> _disconnect() async {
    final dp = context.read<DeviceProvider>();
    await dp.disconnect();
    if (mounted) context.go('/models');
  }

  void _openDebug() {
    final dp     = context.read<DeviceProvider>();
    if (!mounted) return;
    final debugP = context.read<DebugProvider>();

    if (!_debugWrapped) {
      final inner   = dp.currentTransport;
      final wrapped = DebugTransport(inner: inner, sink: debugP);
      dp.setTransport(wrapped);
      debugP.attachTransport(wrapped);
      _debugWrapped = true;
    }

    if (mounted) {
      context.push('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        final device      = deviceProvider.connectedDevice;
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
                            .withValues(alpha: 0.6),
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
              if (kDebugMode)
                IconButton(
                  icon: const Icon(Icons.bug_report_rounded),
                  tooltip: 'Debug Monitor',
                  onPressed: _openDebug,
                ),
              TextButton.icon(
                icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
                label: const Text('Disconnect'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _disconnect,
              ),
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Theme Gallery',
                onPressed: () => context.push('/skins'),
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
      case DeviceConnectionState.disconnected:
        return _buildLoadingState('Disconnecting...');
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
              color: AppColors.brandOrange, strokeWidth: 2),
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
            TextButton(onPressed: _disconnect, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }

  (double, double) _canvasDimensions(int orientation) {
    if (orientation == kOrientationPortrait) {
      return (kCanvasPortraitW, kCanvasPortraitH);
    }
    return (kCanvasLandscapeW, kCanvasLandscapeH);
  }

  Widget _buildCanvas(DeviceProvider deviceProvider) {
    final orientation = deviceProvider.orientation;
    final (canvasVW, canvasVH) = _canvasDimensions(orientation);
    
    // Fixed internal scale of 8.0 ensures consistent 1:1 proportions
    const double internalScale = 8.0;
    final double physicalW = canvasVW * internalScale;
    final double physicalH = canvasVH * internalScale;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: physicalW,
            height: physicalH,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0), // Margin for debug labels
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListenableBuilder(
                    listenable: SkinManager(),
                    builder: (context, _) {
                      final skin = SkinManager().current;
                      final gridColor = skin?.colors['grid'] ?? Theme.of(context).dividerColor;
                      
                      return CustomPaint(
                        size: Size(physicalW, physicalH),
                        painter: _GridPainter(
                          color: gridColor,
                          style: skin?.gridStyle ?? GridStyle.lines,
                          spacing: skin?.gridSpacing ?? 10.0,
                          scaleX: internalScale,
                          scaleY: internalScale,
                        ),
                      );
                    },
                  ),
                  ...deviceProvider.widgets.map((config) {
                    return _buildPositionedWidget(
                        config, internalScale, canvasVH, deviceProvider);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionedWidget(
    WidgetConfig config,
    double scale,
    double canvasVH,
    DeviceProvider deviceProvider,
  ) {
    final scaledW  = config.w * scale;
    final scaledH  = config.h * scale;
    final screenX  = config.x * scale;
    final screenY  = (canvasVH - config.y) * scale;
    final left     = screenX - scaledW / 2;
    final top      = screenY - scaledH / 2;
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
        child: _buildWidgetForConfig(config, state, deviceProvider, scale),
      ),
    );
  }

  Widget _buildWidgetForConfig(
      WidgetConfig config, RadioWidgetState? state, DeviceProvider dp, double scale) {
    switch (config.typeId) {
      case kWidgetButton:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return ButtonWidget(
          config: config,
          value: value,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

      case kWidgetSwitch:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return SwitchWidget(
          config: config,
          value: value,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

      case kWidgetSlideSwitch:
        final slideValue = state?.inputValues[config.widgetId]?.first ?? 0;
        return SlideSwitchWidget(
          config: config,
          value: slideValue,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

      case kWidgetSlider:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return SliderWidget(
          config: config,
          value: value,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

      case kWidgetJoystick:
        final values = state?.inputValues[config.widgetId] ?? [0, 0];
        return JoystickWidget(
          config: config,
          x: values.isNotEmpty ? values[0] : 0,
          y: values.length > 1 ? values[1] : 0,
          onChanged: (x, y) => dp.setInputValue(config.widgetId, [x, y]),
          scale: scale,
        );

      case kWidgetLed:
        final value = state?.outputValues[config.widgetId] ?? [0, 0, 0, 0];
        return LedWidget(config: config, value: value, scale: scale);

      case kWidgetText:
        final value = state?.outputValues[config.widgetId] ?? '';
        return TextWidget(config: config, text: value.toString(), scale: scale);

      case kWidgetMultiple:
        final value = state?.inputValues[config.widgetId]?.first ?? 0;
        return MultipleWidget(
          config: config,
          value: value,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

      case kWidgetKnob:
        final knobValue = state?.inputValues[config.widgetId]?.first ?? 0;
        return KnobWidget(
          config: config,
          value: knobValue,
          onChanged: (v) => dp.setInputValue(config.widgetId, [v]),
          scale: scale,
        );

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

// ── Grid background painter ───────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  final GridStyle style;
  final double spacing;
  final double scaleX;
  final double scaleY;

  _GridPainter({
    required this.color,
    required this.style,
    required this.spacing,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == GridStyle.none) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    final physSpacingX = spacing * scaleX;
    final physSpacingY = spacing * scaleY;

    if (style == GridStyle.lines) {
      // Draw vertical lines
      for (double x = 0; x <= size.width + 0.1; x += physSpacingX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      // Draw horizontal lines
      for (double y = 0; y <= size.height + 0.1; y += physSpacingY) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else {
      // Draw dots
      paint.style = PaintingStyle.fill;
      const radius = 1.25;
      for (double x = 0; x <= size.width + 0.1; x += physSpacingX) {
        for (double y = 0; y <= size.height + 0.1; y += physSpacingY) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.style != style ||
           oldDelegate.spacing != spacing ||
           oldDelegate.scaleX != scaleX ||
           oldDelegate.scaleY != scaleY;
  }
}
