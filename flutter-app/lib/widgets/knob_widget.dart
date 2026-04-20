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
  
  double _dragAccum = 0.0;
  static const double _sensitivity = 1.5; 

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

  void _onPanStart(DragStartDetails _) {
    setState(() => _isDragging = true);
    _springController.stop();
    _dragAccum = 0.0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragAccum -= details.delta.dy * _sensitivity;
    final raw = (widget.value + _dragAccum).round().clamp(-100, 100);
    widget.onChanged(raw);
    _dragAccum -= (raw - widget.value); 
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _isDragging = false);
    _dragAccum = 0.0;
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

    // Use SpringSimulation for a more premium, physics-accurate feel
    final spring = SpringDescription(
      mass: _behavior.physics.mass,
      stiffness: _behavior.physics.stiffness,
      damping: _behavior.physics.damping,
    );

    _springAnimation = Tween<double>(
      begin: from.toDouble(),
      end: to.toDouble(),
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.linear,
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
          child: Stack(
            children: [
              // Layer 1: Base (Stationary)
              DynamicSkinRenderer(
                widgetFolder: 'knob',
                layer: 'base',
                state: RKSkinState(
                  isPressed: _isDragging,
                  styleIndex: widget.config.style,
                ),
              ),
              // Layer 2: Indicator (Rotatable)
              Transform.rotate(
                // Rotate based on -100..100 value
                // Standard knob swept angle is ~270 degrees
                angle: (normalizedValue * 270 - 135) * (3.14159 / 180),
                child: DynamicSkinRenderer(
                  widgetFolder: 'knob',
                  layer: 'indicator',
                  state: RKSkinState(
                    isPressed: _isDragging,
                    styleIndex: widget.config.style,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
