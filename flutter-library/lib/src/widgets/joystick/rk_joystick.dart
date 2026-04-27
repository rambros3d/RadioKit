import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';

/// 2-axis joystick value.
class RKJoystickValue {
  const RKJoystickValue({this.x = 0.0, this.y = 0.0, this.isActive = false});
  /// X axis: -1.0 (left) to 1.0 (right)
  final double x;
  /// Y axis: -1.0 (down) to 1.0 (up)
  final double y;
  /// True when the widget is being actively interacted with (e.g. dragged)
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RKJoystickValue &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          isActive == other.isActive;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ isActive.hashCode;
}

/// A premium 2-axis joystick widget for RadioKit.
class RKJoystick extends StatefulWidget {
  const RKJoystick({
    super.key,
    required this.onChanged,
    this.value,
    this.center = const RKJoystickValue(x: 0, y: 0),
    this.size = 140.0,
    this.autoCenter = true,
    this.label,
    this.springCurve = Curves.easeOutCubic,
    this.springDuration = const Duration(milliseconds: 300),
    this.rotation = 0.0,
  });

  final ValueChanged<RKJoystickValue> onChanged;
  final RKJoystickValue? value;
  final RKJoystickValue center;
  final double size;
  final bool autoCenter;
  final String? label;
  final Curve springCurve;
  final Duration springDuration;
  final double rotation;

  @override
  State<RKJoystick> createState() => _RKJoystickState();
}

class _RKJoystickState extends State<RKJoystick> with SingleTickerProviderStateMixin {
  Offset _knobOffset = Offset.zero;
  late AnimationController _centerController;
  late Animation<Offset> _centerAnimation;
  RKJoystickValue? _lastEmittedValue;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      _knobOffset = _offsetFromValue(widget.value!);
      _lastEmittedValue = widget.value;
    }
    _centerController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    );
    _centerAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));

    _centerController.addListener(() {
      final newOffset = _centerAnimation.value;
      final radius = widget.size / 2;

      setState(() {
        // Constrain to circle to prevent overshoot during elastic animation
        if (newOffset.distance <= radius) {
          _knobOffset = newOffset;
        } else {
          _knobOffset = Offset.fromDirection(newOffset.direction, radius);
        }
      });
      _updateValue(_knobOffset);
    });
  }

  @override
  void didUpdateWidget(covariant RKJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }
    
    // 1. Sync value from external source
    if (widget.value != null && widget.value != oldWidget.value) {
      final newOffset = _offsetFromValue(widget.value!);
      
      // We only react if the new value is significantly different from our current internal state.
      // This prevents "echo" updates (from our own animations) from cancelling themselves.
      final isExternalUpdate = (newOffset - _knobOffset).distance > 0.001;

      if (isExternalUpdate) {
        final centerOffset = _offsetFromValue(widget.center);
        
        // If auto-centering is on and an axis was reset to its neutral position, animate back
        final isRelease = (newOffset.dx == centerOffset.dx && _knobOffset.dx != centerOffset.dx) || 
                          (newOffset.dy == centerOffset.dy && _knobOffset.dy != centerOffset.dy);

        if (widget.autoCenter && isRelease) {
          // Spring back to the actual CENTER, not just the released coordinate
          _lastEmittedValue = widget.value;
          _triggerCenter(target: centerOffset);
        } else {
          // Any other movement (active dragging of slider) stops animation and snaps
          if (_centerController.isAnimating) _centerController.stop();
          setState(() {
            _knobOffset = newOffset;
            _lastEmittedValue = widget.value;
          });
        }
      }
    }

    // 2. Trigger centering if autoCenter was toggled ON or if the center target changed
    if (widget.autoCenter) {
      final centerOffset = _offsetFromValue(widget.center);
      final wasToggledOn = !oldWidget.autoCenter;
      final centerChanged = widget.center != oldWidget.center;

      if ((wasToggledOn || centerChanged) && (_knobOffset - centerOffset).distance > 0.001) {
        _triggerCenter(target: centerOffset);
      }
    }
  }

  void _triggerCenter({Offset? target}) {
    final endTarget = target ?? _offsetFromValue(widget.center);
    _centerController.stop();
    _centerAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: endTarget,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));
    _centerController.forward(from: 0);
  }

  Offset _offsetFromValue(RKJoystickValue value) {
    final radius = widget.size / 2;
    return Offset(
      value.x * radius,
      -value.y * radius,
    );
  }

  @override
  void dispose() {
    _centerController.dispose();
    super.dispose();
  }

  void _updateValue(Offset offset) {
    final radius = widget.size / 2;
    
    // Use a small epsilon to snap to exactly zero for better precision
    double dx = offset.dx / radius;
    double dy = -offset.dy / radius;
    
    if (dx.abs() < 0.001) dx = 0.0;
    if (dy.abs() < 0.001) dy = 0.0;

    final newValue = RKJoystickValue(
      x: dx.clamp(-1.0, 1.0),
      y: dy.clamp(-1.0, 1.0),
      isActive: _isInteracting,
    );

    if (newValue != _lastEmittedValue) {
      _lastEmittedValue = newValue;
      widget.onChanged(newValue);
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isInteracting = true;
    _centerController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final localPos = box.globalToLocal(details.globalPosition);
    final delta = localPos - center;
    
    final radius = widget.size / 2;
    final newOffset = delta;

    // Constrain to circle
    if (newOffset.distance <= radius) {
      setState(() => _knobOffset = newOffset);
    } else {
      setState(() => _knobOffset = Offset.fromDirection(newOffset.direction, radius));
    }
    _updateValue(_knobOffset);
  }

  void _onPanEnd(DragEndDetails details) {
    _isInteracting = false;
    if (widget.autoCenter) {
      _triggerCenter(target: _offsetFromValue(widget.center));
    } else {
      _updateValue(_knobOffset); // Final update to set isActive to false
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final radius = widget.size / 2;

    return Transform.rotate(
      angle: widget.rotation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null && widget.label!.isNotEmpty) ...[
            Text(
              widget.label!.toUpperCase(),
              style: TextStyle(
                color: tokens.primary.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _JoystickPainter(
                  knobOffset: _knobOffset,
                  tokens: tokens,
                  radius: radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobOffset,
    required this.tokens,
    required this.radius,
  });

  final Offset knobOffset;
  final tokens;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    
    // 1. Draw Outer Track (Deep Well)
    final trackPaint = Paint()
      ..shader = tokens.surfaceGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Outer Shadow
    canvas.drawCircle(center, radius, Paint()
      ..color = tokens.shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    canvas.drawCircle(center, radius, trackPaint);
    
    // Inner bevel for "deep" look
    final bevelPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, bevelPaint);

    // 2. Draw Crosshair/Guides
    final guidePaint = Paint()
      ..color = tokens.trackColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), guidePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), guidePaint);

    // 3. Draw Knob Head
    final knobCenter = center + knobOffset;
    final knobRadius = radius * 0.35;

    // Knob Glow
    canvas.drawCircle(knobCenter, knobRadius + 4, Paint()
      ..color = tokens.glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    final knobPaint = Paint()
      ..shader = tokens.primaryGradient.createShader(Rect.fromCircle(center: knobCenter, radius: knobRadius))
      ..style = PaintingStyle.fill;

    // Knob Shadow (Perspective)
    final shadowOffset = knobOffset * 0.2;
    canvas.drawCircle(knobCenter + shadowOffset, knobRadius, Paint()
      ..color = tokens.shadowColor.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    // Subtle highlight on knob
    canvas.drawCircle(knobCenter - Offset(knobRadius * 0.3, knobRadius * 0.3), knobRadius * 0.2, Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knobOffset != knobOffset;
}
