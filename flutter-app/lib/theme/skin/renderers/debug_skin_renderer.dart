import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import '../../../models/protocol.dart';
import '../../../utils/icon_utils.dart';

/// A skin renderer that displays a descriptive "placeholder" for development and debugging.
/// It visualizes the state and boundaries of the widget without requiring any asset files.
class DebugSkinRenderer extends SkinRenderer {
  const DebugSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = SkinManager().current;
    if (manifest == null) return const SizedBox.shrink();

    final style = manifest.tokens.styles[state.styleIndex] ?? 
                  manifest.tokens.styles[0]!;
    
    final accentColor = state.colorOverride ?? style.primary;
    final textColor = manifest.tokens.colors['onSurface'] ?? Colors.black;

    final isBaseLayer = layer == null || layer == 'base' || layer == 'track';
    final displayTitle = state.label.isNotEmpty ? state.label : widgetFolder.toUpperCase();
    final isBinary = widgetFolder.contains('button') || widgetFolder.contains('switch') || widgetFolder == 'led';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: isBaseLayer ? BoxDecoration(
            border: Border.all(color: textColor.withValues(alpha: 0.1), width: 1),
            color: (manifest.tokens.colors['surface'] ?? Colors.white).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4 * state.scale),
          ) : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. The Visual Representation
              _buildVisual(accentColor, constraints),
              
              // 2. Debug Info Overlays (only on base layers)
              if (isBaseLayer) ...[
                // Top-Left: Widget Title
                Positioned(
                  top: -1.5 * state.scale,
                  left: 0,
                  child: _debugText(displayTitle, textColor.withValues(alpha: 0.4), size: 1.0 * state.scale, bold: true),
                ),
    
                // Top-Right: Values (VAL / X:Y / Mask / RGB)
                if (widgetFolder != 'display')
                  Positioned(
                    top: -1.5 * state.scale,
                    right: 0,
                    child: () {
                      final isContinuous = widgetFolder == 'slider' || widgetFolder == 'knob';
                      final isJoystick   = widgetFolder == 'joystick';
                      final isMulti      = widgetFolder.contains('multiple');
                      final isLed        = widgetFolder == 'led';
    
                      String label = 'VAL: ';
                      String val = '';
    
                      if (isJoystick) {
                        label = '';
                        val = 'X:${(state.valueX * 100).round()} Y:${(state.valueY * 100).round()}';
                      } else if (isLed) {
                        label = '';
                        final c = state.colorOverride ?? Colors.black;
                        val = 'R:${c.r.toInt()} G:${c.g.toInt()} B:${c.b.toInt()}';
                      } else if (isContinuous) {
                        val = (state.value * 200 - 100).round().toString();
                      } else if (widgetFolder == 'multiple_select') {
                        // Binary bitmask for toggles, padded to bitCount
                        val = state.value.toInt().toRadixString(2).toUpperCase().padLeft(state.bitCount, '0');
                      } else if (isMulti) {
                        // Decimal for radio buttons (multiple_button)
                        val = state.value.toInt().toString();
                      } else {
                        // Binary or other
                        val = state.value.toInt().toString();
                      }
                      
                      return _debugText('$label$val', textColor, size: 1.0 * state.scale, bold: true);
                    }(),
                  ),
    
                // Bottom-Left: Widget Type (SLIDER, KNOB, etc)
                Positioned(
                  bottom: -1.5 * state.scale,
                  left: 0,
                  child: _debugText(widgetFolder.toUpperCase(), textColor.withValues(alpha: 0.6), size: 1.0 * state.scale),
                ),
    
                // Bottom-Right: Position (POS: x,y)
                Positioned(
                  bottom: -1.5 * state.scale,
                  right: 0,
                  child: _debugText('POS: (${state.x.round()},${state.y.round()})', textColor.withValues(alpha: 0.6), size: 1.0 * state.scale),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisual(Color color, BoxConstraints constraints) {
    final s = state.scale;
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    switch (widgetFolder) {
      case 'knob':
        // If it's the indicator layer, it's already rotated by KnobWidget
        // We draw a fixed indicator line pointing North (relative to the rotated container)
        if (layer == 'indicator') {
          return Center(
            child: CustomPaint(
              size: Size(w, h),
              painter: _KnobPainter(value: 0.5, color: color, isIndicator: true, staticIndicator: true),
            ),
          );
        }
        return Center(
          child: CustomPaint(
            size: Size(math.min(w, h), math.min(w, h)),
            painter: _KnobPainter(value: state.value, color: color, isIndicator: false),
          ),
        );

      case 'slider':
        final isHorizontal = w > h;
        if (layer == 'track') {
          return Center(
            child: Container(
              width: isHorizontal ? w : w * 0.6,
              height: isHorizontal ? h * 0.6 : h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(math.min(w, h) / 2),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
            ),
          );
        } else {
          // Thumb - should be a nicely sized handle
          final thumbSize = math.min(w, h) * 0.9;
          return Center(
            child: Container(
              width: thumbSize, height: thumbSize,
              decoration: BoxDecoration(
                color: color, 
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4 * s, offset: const Offset(0, 2))],
              ),
            ),
          );
        }

      case 'led':
        return Center(
          child: Container(
            width: math.min(w, h) * 0.7, height: math.min(w, h) * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isOn ? color : color.withValues(alpha: 0.2),
              boxShadow: state.isOn ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10 * s, spreadRadius: 2 * s)] : [],
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            ),
          ),
        );

      case 'joystick':
        if (layer == 'base') {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
              color: color.withValues(alpha: 0.05),
            ),
            child: Center(
              child: Container(
                width: 2 * s, height: 2 * s,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
              ),
            ),
          );
        } else {
          // Stick - usually around 30-40% of the base size
          final stickSize = math.min(w, h) * 0.4;
          return Center(
            child: Container(
              width: stickSize, height: stickSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white70, color],
                  stops: const [0.1, 1.0],
                ),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4 * s, offset: const Offset(0, 2))],
              ),
            ),
          );
        }

      case 'slide_switch':
        final isTrack = layer == null || layer == 'base' || layer == 'track';
        final isThumb = layer == 'thumb';
        
        if (isTrack && layer != null) {
          return Center(
            child: Container(
              width: w, height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
              ),
            ),
          );
        } else if (isThumb) {
          final thumbSize = h * 0.8;
          return Center(
            child: Container(
              width: thumbSize, height: thumbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.isOn ? color : Colors.grey.shade400,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2 * s)],
              ),
            ),
          );
        } else {
          // Self-contained toggle switch (layer == null)
          final thumbSize = h * 0.7;
          return Center(
            child: Container(
              width: w, height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                color: color.withValues(alpha: 0.05),
                border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment: state.isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(h * 0.1),
                      child: Container(
                        width: thumbSize, height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isOn ? color : Colors.grey.shade400,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2 * s)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

      case 'display':
        return Center(
          child: Container(
            width: w, height: h,
            padding: EdgeInsets.symmetric(horizontal: 4 * s),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(2 * s),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                state.content.isNotEmpty ? state.content : 'NO DATA',
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontSize: math.min(w * 0.15, h * 0.6),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );

      case 'multiple_button':
      case 'multiple_select':
      default:
        // Generic box/button or Multiple Item
        final isBase = layer == 'base' || layer == 'track';
        final iconData = !isBase ? parseIconFromName(state.icon) : null;
        final isPressed = state.isPressed || (state.isOn && layer == 'item');
        
        return Container(
          width: w, height: h,
          decoration: BoxDecoration(
            color: isPressed ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.1),
            border: Border.all(color: isPressed ? color : color.withValues(alpha: 0.5), width: isPressed ? 2 : 1),
            borderRadius: BorderRadius.circular(4 * s),
          ),
          child: iconData != null 
            ? Center(child: Icon(iconData, size: math.min(w, h) * 0.5, color: isPressed ? Colors.white : color)) 
            : (state.label.isNotEmpty && layer == 'item' 
                ? Center(child: _debugText(state.label, isPressed ? Colors.white : color, size: 1.2 * s, bold: true))
                : null),
        );
    }
  }

  Widget _debugText(String text, Color color, {double size = 10, bool bold = false}) {
    return Text(
      text,
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
  final bool staticIndicator;

  _KnobPainter({
    required this.value, 
    required this.color, 
    required this.isIndicator, 
    this.staticIndicator = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw background circle
    if (!isIndicator) {
      canvas.drawCircle(center, radius, paint);
    }

    paint.color = color;
    paint.strokeCap = StrokeCap.round;

    if (!isIndicator) {
      // Draw value arc
      paint.strokeWidth = 4;
      const startAngle = 0.75 * math.pi;
      final sweepAngle = value * 1.5 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    } else {
      // Indicator line
      // If staticIndicator is true, we draw it pointing up because the container is rotated
      final angle = staticIndicator ? -0.5 * math.pi : (0.75 * math.pi + value * 1.5 * math.pi);
      final lineStart = center + Offset(math.cos(angle) * (radius * 0.3), math.sin(angle) * (radius * 0.3));
      final lineEnd = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(lineStart, lineEnd, paint..strokeWidth = 3);
      
      // Pivot dot
      canvas.drawCircle(center, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) => true;
}
