import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../providers/skin_provider.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';
import '../theme/skin/behavior_config.dart';
import '../theme/skin/skin_manager.dart';

/// Rotary knob widget (-100 to +100) using v1.6 skin engine.
/// Maintains vertical-drag interaction and physics while delegating rendering.
class KnobWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;
  final double scale;

  const KnobWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  @override
  State<KnobWidget> createState() => _KnobWidgetState();
}

class _KnobWidgetState extends State<KnobWidget>
    with SingleTickerProviderStateMixin {

  late final AnimationController _springController;
  late Animation<double> _springAnimation;
  VoidCallback? _springListener;

  bool _isDragging = false;
  BehaviorConfig _behavior = BehaviorConfig.empty();
  String? _lastSkin;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final skinName = context.watch<SkinProvider>().skinName;
    if (skinName != _lastSkin) {
      _lastSkin = skinName;
      _loadBehavior();
    }
  }

  Future<void> _loadBehavior() async {
    final config = await SkinManager().getWidgetConfig('knob');
    if (mounted) {
      setState(() {
        _behavior = config;
        final springAnim = _behavior.animations['spring'];
        if (springAnim != null) {
          _springController.duration = Duration(milliseconds: springAnim.durationMs);
        } else {
          _springController.duration = const Duration(milliseconds: 250);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_springListener != null) {
      _springAnimation.removeListener(_springListener!);
    }
    _springController.dispose();
    super.dispose();
  }

  void _handleGesture(Offset localPosition) {
    // 1. Calculate center and local vector
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // 0. Distance check to prevent erratic jumps near the pivot center
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < size.width * 0.2) return;

    // 2. Calculate angle where North (top) is 0 radians
    double angle = math.atan2(dy, dx) + math.pi / 2;

    // 3. Normalize angle to (-PI..PI) range
    if (angle > math.pi) angle -= 2 * math.pi;
    if (angle < -math.pi) angle += 2 * math.pi;

    // 4. Convert to degrees for easier limit handling
    double degrees = angle * 180 / math.pi;

    // 5. Dead zone protection (Hard Wall):
    // The active sweep is -135 to 135 (270 degrees total).
    // The bottom 90 degrees (135 to 225 / -135) is the dead zone.
    // We clamp to the CLOSEST limit based on the CURRENT value to prevent 
    // "jumping" across the gap from -100 to 100.
    if (degrees > 135 || degrees < -135) {
      if (widget.value >= 0) {
        degrees = 135;
      } else {
        degrees = -135;
      }
    }

    // 6. Map degrees (-135..135) to value (-100..100)
    final double valueF = (degrees / 135.0) * 100.0;
    final int rawValue = valueF.round().clamp(-100, 100);

    if (rawValue != widget.value) {
      widget.onChanged(rawValue);
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _springController.stop();
    _handleGesture(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _handleGesture(details.localPosition);
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _isDragging = false);
    
    final centering = variantCentering(widget.config.variant);
    final detents   = variantDetents(widget.config.variant);

    if (centering != kCenterNone) {
      final target = centering == kCenterLeft  ? -100
                   : centering == kCenterRight ?  100
                   : 0;
      _animateSpring(widget.value, target);
    } else if (detents > 0) {
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
      curve: Curves.easeOut, // Better feel than direct linear for spring
    ));

    _springListener = () {
      widget.onChanged(_springAnimation.value.round().clamp(-100, 100));
    };

    _springAnimation.addListener(_springListener!);
    _springController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Normalize -100..100 to 0..1 for the renderer
    final normalizedValue = (widget.value + 100) / 200.0;

    return Center(
      child: GestureDetector(
        onPanStart:  _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Universal Path: Delegate to engine
              if (_behavior.renderingLayers.isNotEmpty) {
                return Transform.rotate(
                  angle: (normalizedValue * 270 - 135) * (math.pi / 180),
                  child: DynamicSkinRenderer(
                    widgetFolder: 'knob',
                    state: RKSkinState(
                      isPressed: _isDragging,
                      styleIndex: widget.config.style,
                      value: normalizedValue,
                      x: widget.config.x,
                      y: widget.config.y,
                      label: widget.config.label,
                      icon: widget.config.icon,
                      scale: widget.scale,
                    ),
                  ),
                );
              }

              // Legacy Path: Manual stacking
              return Stack(
                children: [
                  DynamicSkinRenderer(
                    widgetFolder: 'knob',
                    layer: 'base',
                    state: RKSkinState(
                      isPressed: _isDragging,
                      styleIndex: widget.config.style,
                      label: widget.config.label,
                      value: normalizedValue,
                      x: widget.config.x,
                      y: widget.config.y,
                      icon: widget.config.icon,
                      scale: widget.scale,
                    ),
                  ),
                  Transform.rotate(
                    angle: (normalizedValue * 270 - 135) * (math.pi / 180),
                    child: DynamicSkinRenderer(
                      widgetFolder: 'knob',
                      layer: 'indicator',
                      state: RKSkinState(
                        isPressed: _isDragging,
                        styleIndex: widget.config.style,
                        label: widget.config.label, 
                        icon: widget.config.icon,
                        scale: widget.scale,
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
