import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../providers/skin_provider.dart';
import '../models/widget_config.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';
import '../theme/skin/behavior_config.dart';
import '../theme/skin/skin_tokens.dart';
import '../theme/skin/skin_manager.dart';

/// 2-axis joystick widget with support for premium multi-layer skins.
/// Handles pan interaction in Flutter and stacks Base + Stick layers.
class JoystickWidget extends StatefulWidget {
  final WidgetConfig config;
  final int x;
  final int y;
  final void Function(int x, int y) onChanged;
  final double scale;

  const JoystickWidget({
    super.key,
    required this.config,
    required this.x,
    required this.y,
    required this.onChanged,
    this.scale = 1.0,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget>
    with SingleTickerProviderStateMixin {
  
  // Normalised -1..1 space
  double _nx = 0;
  double _ny = 0;

  late final AnimationController _springController;
  late Animation<Offset> _springAnimation;
  VoidCallback? _springListener;
  BehaviorConfig _behavior = BehaviorConfig.empty();
  String? _lastSkin;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(vsync: this);
    // Initialize with current values from hardware
    _nx = (widget.x / 100).clamp(-1.0, 1.0);
    _ny = (widget.y / 100).clamp(-1.0, 1.0);
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
    final config = await SkinManager().getWidgetConfig('joystick');
    if (mounted) {
      setState(() {
        _behavior = config;
        final springAnim = _behavior.animations['spring'];
        if (springAnim != null) {
          _springController.duration = Duration(milliseconds: springAnim.durationMs);
        } else {
          _springController.duration = const Duration(milliseconds: 200);
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

  void _onPanUpdate(DragUpdateDetails details) {
    _springController.stop();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final center = Offset(box.size.width / 2, box.size.height / 2);

    final delta = localPos - center;
    final trackRadius = box.size.width / 2;
    final dist = delta.distance;

    Offset clamped = delta;
    if (dist > trackRadius) {
      clamped = delta * (trackRadius / dist);
    }

    setState(() {
      _nx = (clamped.dx / trackRadius).clamp(-1.0, 1.0);
      _ny = (clamped.dy / trackRadius).clamp(-1.0, 1.0);
    });

    widget.onChanged((_nx * 100).round(), (_ny * 100).round());
  }

  void _onPanEnd(DragEndDetails _) {
    if (_springListener != null) {
      _springAnimation.removeListener(_springListener!);
    }

    // Use SpringSimulation parameters
    final spring = SpringDescription(
      mass: _behavior.physics.mass,
      stiffness: _behavior.physics.stiffness,
      damping: _behavior.physics.damping,
    );

    _springAnimation = Tween<Offset>(
      begin: Offset(_nx, _ny),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.linear),
    );

    _springListener = () {
      setState(() {
        _nx = _springAnimation.value.dx;
        _ny = _springAnimation.value.dy;
      });
      widget.onChanged((_nx * 100).round(), (_ny * 100).round());
    };

    _springAnimation.addListener(_springListener!);
    _springController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = SkinManager().current;
    final isNative = manifest?.renderer == SkinRendererType.native || manifest?.name == 'neon';

    if (isNative) {
      return Center(
        child: DynamicSkinRenderer(
          widgetFolder: 'joystick',
          state: RKSkinState(
            styleIndex: widget.config.style,
            label: widget.config.label,
            icon: widget.config.icon,
            scale: widget.scale,
            // Pass the callback to the native renderer
            onJoystickChanged: (dx, dy) => widget.onChanged((dx * 100).round(), (dy * 100).round()),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce square aspect ratio for joystick
        final side = constraints.maxWidth < constraints.maxHeight 
            ? constraints.maxWidth 
            : constraints.maxHeight;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // Layer 1: Base (Stationary)
                  DynamicSkinRenderer(
                    widgetFolder: 'joystick',
                    layer: 'base',
                    state: RKSkinState(
                      styleIndex: widget.config.style,
                      label: widget.config.label,
                      icon: widget.config.icon,
                      scale: widget.scale,
                    ),
                  ),
                  // Layer 2: Stick (Moving)
                  // Offset by half side to move from center
                  Center(
                    child: Transform.translate(
                      offset: Offset(_nx * side * 0.35, _ny * side * 0.35),
                      child: DynamicSkinRenderer(
                        widgetFolder: 'joystick',
                        layer: 'stick',
                        state: RKSkinState(
                          isPressed: true,
                          styleIndex: widget.config.style,
                          label: widget.config.label,
                          icon: widget.config.icon,
                          scale: widget.scale,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
