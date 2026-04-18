import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../providers/skin_provider.dart';

/// Rotary knob widget (-100 to +100).
///
/// Interaction: vertical drag — drag up increases, drag down decreases.
/// Self-centering and detent snapping governed by the config.variant byte.
class KnobWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const KnobWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  @override
  State<KnobWidget> createState() => _KnobWidgetState();
}

class _KnobWidgetState extends State<KnobWidget>
    with SingleTickerProviderStateMixin {
  /// Drag accumulator in raw pixels.
  double _dragAccum = 0.0;

  late final AnimationController _springController;
  late Animation<double> _springAnimation;
  VoidCallback? _springListener;

  static const double _sensitivity = 1.5; // px per unit

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    if (_springListener != null) {
      _springAnimation.removeListener(_springListener!);
    }
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    _springController.stop();
    _dragAccum = 0.0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragAccum -= details.delta.dy * _sensitivity;
    final raw = (widget.value + _dragAccum).round().clamp(-100, 100);
    widget.onChanged(raw);
    _dragAccum -= (raw - widget.value); // consume what was applied
  }

  void _onPanEnd(DragEndDetails _) {
    _dragAccum = 0.0;
    final centering = variantCentering(widget.config.variant);
    final detents   = variantDetents(widget.config.variant);

    if (centering != kCenterNone) {
      // Spring to target
      final target = centering == kCenterLeft  ? -100
                   : centering == kCenterRight ?  100
                   : 0;
      _animateSpring(widget.value, target);
    } else if (detents > 0) {
      // Snap to nearest detent
      final snapped = snapToDetents(widget.value, detents);
      if (snapped != widget.value) _animateSpring(widget.value, snapped);
    }
  }

  void _animateSpring(int from, int to) {
    if (_springListener != null) {
      _springAnimation.removeListener(_springListener!);
      _springListener = null;
    }

    _springAnimation = Tween<double>(
      begin: from.toDouble(),
      end: to.toDouble(),
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.elasticOut,
    ));

    _springListener = () {
      widget.onChanged(_springAnimation.value.round().clamp(-100, 100));
    };

    _springAnimation.addListener(_springListener!);
    _springController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens       = context.watch<SkinProvider>().tokens;
    final primaryColor = tokens.colors['primary'] ?? Theme.of(context).colorScheme.primary;
    final surfaceColor = tokens.colors['surface'] ?? Theme.of(context).cardTheme.color;
    final dimColor     = tokens.colors['dim']     ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;

    return GestureDetector(
      onPanStart:  _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd:    _onPanEnd,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(tokens.borderRadius + 4),
          border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: tokens.borderWidth),
        ),
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 80,
            height: 90,
            child: Column(
              children: [
                // Knob arc
                Expanded(
                  child: CustomPaint(
                    painter: _KnobPainter(
                      value:        widget.value,
                      primaryColor: primaryColor,
                      trackColor:   dimColor.withValues(alpha: 0.15),
                      centeringMode: variantCentering(widget.config.variant),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Label
                Text(
                  widget.config.label.isNotEmpty ? widget.config.label : 'Knob',
                  style: GoogleFonts.getFont(
                    tokens.fontFamily,
                    color: dimColor.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Value
                Text(
                  '${widget.value > 0 ? '+' : ''}${widget.value}',
                  style: GoogleFonts.getFont(
                    tokens.fontFamily,
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the 270° arc knob.
///
/// Arc layout:
///   Start = 135° (7 o'clock) → value −100
///   Midpoint = 270° (12 o'clock) → value 0
///   End = 405° (5 o'clock) → value +100
class _KnobPainter extends CustomPainter {
  final int value;
  final Color primaryColor;
  final Color trackColor;
  final int centeringMode;

  const _KnobPainter({
    required this.value,
    required this.primaryColor,
    required this.trackColor,
    required this.centeringMode,
  });

  static const double _startDeg = 135.0;
  static const double _sweepDeg = 270.0;

  double get _valueFraction => (value + 100) / 200.0; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide / 2) - 8;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final trackPaint = Paint()
      ..color       = trackColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap   = StrokeCap.round;

    final valuePaint = Paint()
      ..color       = primaryColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap   = StrokeCap.round;

    final startRad = _startDeg * pi / 180.0;
    final sweepRad = _sweepDeg * pi / 180.0;

    // Track
    canvas.drawArc(arcRect, startRad, sweepRad, false, trackPaint);

    // Center mark (at 0, the midpoint of the arc) - thin tick
    final midRad = (_startDeg + _sweepDeg / 2) * pi / 180.0;
    final tickInner = radius - 10;
    final tickOuter = radius + 2;
    canvas.drawLine(
      Offset(cx + cos(midRad) * tickInner, cy + sin(midRad) * tickInner),
      Offset(cx + cos(midRad) * tickOuter, cy + sin(midRad) * tickOuter),
      Paint()
        ..color       = primaryColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.5,
    );

    // Filled value arc
    if (centeringMode == kCenterNone || centeringMode == kCenterLeft ||
        centeringMode == kCenterRight) {
      // Arcs from start to current position
      final fillSweep = sweepRad * _valueFraction;
      if (fillSweep.abs() > 0.01) {
        canvas.drawArc(arcRect, startRad, fillSweep, false, valuePaint);
      }
    } else {
      // Center mode: arc from middle outward
      final midRad2 = startRad + sweepRad / 2;
      final halfSweep = sweepRad / 2 * (value / 100.0);
      if (halfSweep.abs() > 0.01) {
        canvas.drawArc(
          arcRect,
          halfSweep >= 0 ? midRad2 : midRad2 + halfSweep,
          halfSweep.abs(),
          false,
          valuePaint,
        );
      }
    }

    // Knob body circle
    canvas.drawCircle(
      Offset(cx, cy),
      radius - 9,
      Paint()
        ..color = trackColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    // Pointer dot
    final pointerAngle = (_startDeg + _sweepDeg * _valueFraction) * pi / 180.0;
    final pointerRadius = radius - 16;
    canvas.drawCircle(
      Offset(
        cx + cos(pointerAngle) * pointerRadius,
        cy + sin(pointerAngle) * pointerRadius,
      ),
      3,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter old) =>
      old.value != value ||
      old.primaryColor != primaryColor ||
      old.centeringMode != centeringMode;
}
