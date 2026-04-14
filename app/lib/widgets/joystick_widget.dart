import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/app_theme.dart';

/// 2-axis joystick widget with a draggable thumb.
///
/// Returns x, y each in the range -100 to +100.
/// Springs back to center when the finger is released.
class JoystickWidget extends StatefulWidget {
  final WidgetConfig config;
  final int x;
  final int y;
  final void Function(int x, int y) onChanged;

  const JoystickWidget({
    super.key,
    required this.config,
    required this.x,
    required this.y,
    required this.onChanged,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget>
    with SingleTickerProviderStateMixin {
  /// Thumb position in normalised -1..1 space
  double _nx = 0;
  double _ny = 0;

  late final AnimationController _springController;
  late Animation<Offset> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    _springController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details, double trackRadius) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final center = Offset(box.size.width / 2, box.size.height / 2);

    final delta = localPos - center;
    final dist = delta.distance;

    // Clamp to track circle
    Offset clamped = delta;
    if (dist > trackRadius) {
      clamped = delta * (trackRadius / dist);
    }

    setState(() {
      _nx = (clamped.dx / trackRadius).clamp(-1.0, 1.0);
      _ny = (clamped.dy / trackRadius).clamp(-1.0, 1.0);
    });

    final ix = (_nx * 100).round().clamp(-100, 100);
    final iy = (_ny * 100).round().clamp(-100, 100);
    widget.onChanged(ix, iy);
  }

  void _onPanEnd(DragEndDetails _) {
    _springAnimation = Tween<Offset>(
      begin: Offset(_nx, _ny),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    )..addListener(() {
        setState(() {
          _nx = _springAnimation.value.dx;
          _ny = _springAnimation.value.dy;
        });
        final ix = (_nx * 100).round().clamp(-100, 100);
        final iy = (_ny * 100).round().clamp(-100, 100);
        widget.onChanged(ix, iy);
      });

    _springController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.smallest;
        final radius = (size.shortestSide / 2) - 8;
        final thumbRadius = radius * 0.28;
        final trackRadius = radius - thumbRadius;

        final thumbOffsetX = _nx * trackRadius;
        final thumbOffsetY = _ny * trackRadius;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track circle
              Container(
                width: trackRadius * 2,
                height: trackRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                      width: 1),
                ),
              ),

              // Crosshair lines
              _Crosshair(size: trackRadius * 2),

              // Label
              if (config.label.isNotEmpty)
                Positioned(
                  bottom: 6,
                  child: Text(
                    config.label,
                    style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

              // Thumb
              Transform.translate(
                offset: Offset(thumbOffsetX, thumbOffsetY),
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: (d) => _onPanUpdate(d, trackRadius),
                  onPanEnd: _onPanEnd,
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.brandOrange,
                          AppColors.brandOrange.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Drag capture overlay
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: (d) => _onPanUpdate(d, trackRadius),
                  onPanEnd: _onPanEnd,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  WidgetConfig get config => widget.config;
}

class _Crosshair extends StatelessWidget {
  final double size;

  const _Crosshair({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrosshairPainter(
        color: Theme.of(context).dividerColor.withOpacity(0.4),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;

  _CrosshairPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal line
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    // Vertical line
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
