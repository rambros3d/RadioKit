import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';

/// A skin renderer that uses native Flutter widgets to visualize 
/// widget state and metadata without requiring external assets.
class DebugSkinRenderer extends SkinRenderer {
  const DebugSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    final manager = SkinManager();
    final manifest = manager.current;
    if (manifest == null) return const SizedBox.shrink();

    final style = manifest.tokens.styles[state.styleIndex] ?? 
                  manifest.tokens.styles[0]!;
    
    final accentColor = state.colorOverride ?? style.primary;
    final textColor = manifest.tokens.colors['onSurface'] ?? Colors.black;
    final outlineColor = manifest.tokens.colors['outline'] ?? Colors.grey;

    final isBaseLayer = layer == null || layer == 'base' || layer == 'track';
    final displayTitle = state.label.isNotEmpty ? state.label : widgetFolder.toUpperCase();
    final isBinary = widgetFolder.contains('button') || widgetFolder.contains('switch') || widgetFolder == 'led';

    return Container(
      decoration: isBaseLayer ? BoxDecoration(
        border: Border.all(color: outlineColor.withValues(alpha: 0.3), width: 1),
        color: (manifest.tokens.colors['surface'] ?? Colors.white).withValues(alpha: 0.1),
      ) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildVisual(accentColor),
          
          if (isBaseLayer)
            Positioned(
              top: 2,
              left: 4,
              child: _debugText(displayTitle, textColor.withValues(alpha: 0.6), size: 7, bold: true),
            ),

          if (isBaseLayer)
            Positioned(
              bottom: 2,
              right: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (state.isOn && isBinary) _debugText('ON', Colors.green, size: 8, bold: true),
                  if (state.isPressed) _debugText('PRESSED', Colors.orange, size: 8, bold: true),
                  if (!isBinary) _debugText('VAL: ${state.value.toStringAsFixed(2)}', textColor, size: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisual(Color color) {
    switch (widgetFolder) {
      case 'knob':
        return Center(
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _KnobPainter(value: state.value, color: color, isIndicator: layer == 'indicator'),
          ),
        );
      case 'slider':
        return LayoutBuilder(builder: (context, constraints) {
          final isHorizontal = constraints.maxWidth >= constraints.maxHeight;
          if (layer == 'track') {
            return Center(
              child: Container(
                width: isHorizontal ? double.infinity : 2,
                height: isHorizontal ? 2 : double.infinity,
                margin: EdgeInsets.symmetric(horizontal: isHorizontal ? 4 : 0, vertical: isHorizontal ? 0 : 4),
                color: color.withValues(alpha: 0.3),
              ),
            );
          } else {
            return Center(
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0, 1))],
                ),
              ),
            );
          }
        });
      case 'led':
        return Center(
          child: LayoutBuilder(builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.8;
            return Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.8), color, color.withValues(alpha: 0.5)],
                  stops: const [0.0, 0.4, 1.0],
                ),
                boxShadow: state.isOn ? [BoxShadow(color: color, blurRadius: size/2, spreadRadius: size/4)] : null,
              ),
              child: Center(
                child: Container(
                  width: size * 0.2, height: size * 0.2,
                  transform: Matrix4.translationValues(-size*0.15, -size*0.15, 0),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            );
          }),
        );
      case 'button_push':
      case 'button_toggle':
        final isDown = state.isPressed || (widgetFolder == 'button_toggle' && state.isOn);
        return Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: double.infinity, height: double.infinity,
              margin: EdgeInsets.all(isDown ? 4 : 2),
              decoration: BoxDecoration(
                color: isDown ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color, width: 2),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final iconSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.4;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.icon.isNotEmpty)
                      Icon(_getIconData(state.icon), color: color, size: iconSize.clamp(8, 24)),
                    if (state.label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _debugText(state.label, color, size: (iconSize * 0.6).clamp(6, 12), bold: true),
                      ),
                  ],
                );
              }),
            ),
          ),
        );
      case 'toggle_switch':
        return Center(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth * 0.8;
            final h = w / 2;
            return Container(
              width: w, height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                color: state.isOn ? color.withValues(alpha: 0.2) : Colors.black12,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: state.isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: h * 0.8, height: h * 0.8,
                  margin: EdgeInsets.symmetric(horizontal: h * 0.1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                  child: Center(
                    child: Icon(
                      _getIconData(state.icon),
                      color: Colors.white,
                      size: h * 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      case 'multiple_button':
      case 'multiple_select':
        if (layer == 'item') {
          return Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  color: state.isOn 
                      ? color.withValues(alpha: 0.25) 
                      : color.withValues(alpha: 0.05),
                  border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                padding: const EdgeInsets.all(2),
                child: LayoutBuilder(builder: (context, constraints) {
                  final iconSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.5;
                  final contentColor = state.isOn ? color : color.withValues(alpha: 0.5);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(state.icon, fallback: Icons.apps_rounded), 
                        color: contentColor, 
                        size: iconSize.clamp(8, 24)
                      ),
                      if (state.label.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: _debugText(
                            state.label, 
                            contentColor.withValues(alpha: 0.8), 
                            size: (iconSize * 0.5).clamp(5, 10), 
                            bold: true,
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          );
        }
        return const SizedBox.expand();
      case 'joystick':
        return LayoutBuilder(builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
          final stickSize = size * 0.3;
          
          return Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: SizedBox(
                width: size, height: size,
                child: Stack(
                  children: [
                    Center(child: Container(width: double.infinity, height: 1.5, color: color.withValues(alpha: 0.15))),
                    Center(child: Container(width: 1.5, height: double.infinity, color: color.withValues(alpha: 0.15))),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.1)),
                        gradient: RadialGradient(colors: [color.withValues(alpha: 0.05), Colors.transparent]),
                      ),
                    ),
                    Align(
                      alignment: Alignment(state.valueX, state.valueY),
                      child: Container(
                        width: stickSize, height: stickSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [color.withValues(alpha: 0.4), color],
                            center: const Alignment(-0.3, -0.3),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: stickSize * 0.3, height: stickSize * 0.3,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      default:
        return const SizedBox.expand();
    }
  }

  IconData _getIconData(String name, {IconData fallback = Icons.help_outline}) {
    switch (name.toLowerCase()) {
      case 'zap':        return Icons.bolt_rounded;
      case 'power':      return Icons.power_settings_new_rounded;
      case 'sliders':    return Icons.tune_rounded;
      case 'wifi':       return Icons.wifi_rounded;
      case 'bluetooth':  return Icons.bluetooth_rounded;
      case 'map-pin':    return Icons.place_rounded;
      case 'cpu':        return Icons.memory_rounded;
      case 'mouse':      return Icons.mouse_rounded;
      case 'refresh':    
      case 'rotate-cw':  return Icons.refresh_rounded;
      case 'thermometer':return Icons.thermostat_rounded;
      case 'droplet':    return Icons.water_drop_rounded;
      case 'leaf':       return Icons.eco_rounded;
      case 'wind':       return Icons.air_rounded;
      case 'skull':      return Icons.dangerous_rounded;
      case 'grid':       return Icons.grid_view_rounded;
      case 'settings':   return Icons.settings_rounded;
      case 'home':       return Icons.home_rounded;
      case 'user':       return Icons.person_rounded;
      case 'bell':       return Icons.notifications_rounded;
      default:           return fallback;
    }
  }

  Widget _debugText(String text, Color color, {double size = 10, bool bold = false}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double value;
  final Color color;
  final bool isIndicator;

  _KnobPainter({required this.value, required this.color, this.isIndicator = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (!isIndicator) {
      // Background graduations
      for (int i = 0; i <= 10; i++) {
        final angle = 0.75 * math.pi + (i / 10.0) * 1.5 * math.pi;
        final p1 = center + Offset(math.cos(angle) * (radius * 1.1), math.sin(angle) * (radius * 1.1));
        final p2 = center + Offset(math.cos(angle) * (radius * 1.2), math.sin(angle) * (radius * 1.2));
        canvas.drawLine(p1, p2, paint);
      }
      
      // Main circle
      paint.color = color.withValues(alpha: 0.1);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      
      paint.color = color.withValues(alpha: 0.3);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }

    // Value active arc
    paint.style = PaintingStyle.stroke;
    paint.color = color;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = 4;
    const startAngle = 0.75 * math.pi;
    final sweepAngle = value * 1.5 * math.pi;

    if (!isIndicator) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    } else {
      // Indicator line
      final angle = startAngle + sweepAngle;
      final lineStart = center + Offset(math.cos(angle) * (radius * 0.4), math.sin(angle) * (radius * 0.4));
      final lineEnd = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(lineStart, lineEnd, paint..strokeWidth = 3);
      
      // Pivot dot
      canvas.drawCircle(center, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) => true;
}
