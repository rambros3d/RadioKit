import 'dart:math' show pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/device_provider.dart';
import '../providers/debug_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/settings_provider.dart';
import '../services/debug_transport.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';
import '../widgets/widget_adapter.dart';

/// Dynamic widget rendering screen for the connected RadioKit device.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _debugWrapped = false;

  @override
  void initState() {
    super.initState();
    _applyFullscreen();
  }

  void _applyFullscreen() {
    final settings = context.read<SettingsProvider>();
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    // Restore system UI when leaving the controller
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _disconnect() async {
    final dp = context.read<DeviceProvider>();
    await dp.disconnect();
    if (mounted) context.go('/models');
  }

  void _openDebug() {
    final dp     = context.read<DeviceProvider>();
    if (!mounted) return;
    final debugP = context.read<DebugProvider>();

    // No need to wrap here, DeviceProvider handles it robustly.
    // We just ensure the DebugProvider knows about the current transport for manual sends.
    debugP.attachTransport(dp.currentTransport);

    if (mounted) {
      context.push('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    // Update system UI mode based on setting, but keep the App's UI (AppBar) visible
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        final device      = deviceProvider.connectedDevice;
        final isConnected = deviceProvider.isConnected;

        return WillPopScope(
          onWillPop: () async {
            context.go('/models');
            return false;
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              leadingWidth: 180,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    // Connection indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected ? AppColors.connected : AppColors.disconnected,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isConnected ? AppColors.connected : AppColors.disconnected)
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Telemetry (if connected)
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Icon(Icons.signal_cellular_alt_rounded, 
                                size: 14, color: _getRssiColor(deviceProvider.rssi ?? -127)),
                              const SizedBox(width: 4),
                              Text('${deviceProvider.rssi ?? "--"} dBm', 
                                style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                            if (deviceProvider.rssi != null && deviceProvider.latencyMs != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text('|', style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 10)),
                              ),
                              Icon(Icons.timer_rounded, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text('${deviceProvider.latencyMs ?? "--"}ms', 
                                style: const TextStyle(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              title: Text(
                device?.displayName ?? 'RadioKit Device',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.home_rounded),
                  tooltip: 'Back to Models',
                  onPressed: () => context.go('/models'),
                ),
                if (kDebugMode)
                  IconButton(
                    icon: const Icon(Icons.bug_report_rounded),
                    tooltip: 'Debug',
                    onPressed: _openDebug,
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
                  label: const Text('DISCONNECT'),
                  onPressed: _disconnect,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _buildBody(deviceProvider),
          ),
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

  Color _getRssiColor(int rssi) {
    if (rssi == -127) return Colors.white24;
    if (rssi > -60) return Colors.greenAccent;
    if (rssi > -80) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildCanvas(DeviceProvider deviceProvider) {
    final orientation = deviceProvider.orientation;
    final (canvasVW, canvasVH) = _canvasDimensions(orientation);
    
    // Fixed internal scale of 8.0 ensures consistent 1:1 proportions
    const double internalScale = 8.0;
    final double physicalW = canvasVW * internalScale;
    final double physicalH = canvasVH * internalScale;

    // Source grid color from RKTokens
    final skinProvider = context.watch<SkinProvider>();
    final debugProvider = context.watch<DebugProvider>();
    final tokens = skinProvider.tokens;
    final gridColor = tokens.trackColor.withValues(alpha: 0.3);
    final debugMode = debugProvider.debugMode;

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
                  CustomPaint(
                    size: Size(physicalW, physicalH),
                    painter: _GridPainter(
                      color: gridColor,
                      style: GridStyle.lines,
                      spacing: 10.0,
                      scaleX: internalScale,
                      scaleY: internalScale,
                    ),
                  ),
                  ...deviceProvider.widgets.map((config) {
                    return _buildPositionedWidget(
                        config, internalScale, canvasVH, deviceProvider, debugMode);
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
    bool debugMode,
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            WidgetAdapter.build(
              config: config,
              state: state,
              onInputChanged: (values) => deviceProvider.setInputValue(config.widgetId, values),
              scale: scale,
            ),
            if (debugMode) ...[
              // Bounding box
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Variant top-left
              Positioned(
                top: -12,
                left: 0,
                child: IgnorePointer(
                  child: Text(
                    config.debugLabel,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                ),
              ),
              // Position bottom-right
              Positioned(
                bottom: -12,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    '${config.x},${config.y}',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Grid background painter ───────────────────────────────────────────────────

/// Defines how the background grid should be rendered.
enum GridStyle { lines, dots, none }

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
