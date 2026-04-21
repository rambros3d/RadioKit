import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../providers/skin_provider.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';
import '../theme/skin/behavior_config.dart';
import '../theme/skin/skin_manager.dart';

/// Linear slider widget (-100 to +100) using v1.6 skin engine.
/// Maintains physics-based interaction while delegating rendering to the skin engine.
class SliderWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;
  final double scale;

  const SliderWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget>
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
    final config = await SkinManager().getWidgetConfig('slider');
    if (mounted) {
      setState(() {
        _behavior = config;
        // Update controller duration if provided in 'spring' animation spec
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

  bool get _isHorizontal => widget.config.w > widget.config.h;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _isDragging = true);
    _springController.stop();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    
    double percent;
    if (_isHorizontal) {
      percent = (localPos.dx / box.size.width).clamp(0.0, 1.0);
    } else {
      percent = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
    }
    
    final val = ((percent * 200) - 100).round();
    widget.onChanged(val);
  }

  void _onDragEnd(DragEndDetails _) {
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
    final normalizedValue = (widget.value + 100) / 200.0;
    final skinName = context.watch<SkinProvider>().skinName;

    return GestureDetector(
      onPanUpdate: _onDragUpdate,
      onPanEnd:    _onDragEnd,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If the skin defines universal rendering layers, delegate the ENTIRE stack to the engine.
          // This avoids duplicate layering and offset conflicts.
          if (_behavior.renderingLayers.isNotEmpty) {
            return DynamicSkinRenderer(
              widgetFolder: 'slider',
              state: RKSkinState(
                isPressed: _isDragging,
                isOn: false,
                styleIndex: widget.config.style,
                value: normalizedValue, 
                label: widget.config.label,
                icon: widget.config.icon,
                scale: widget.scale,
              ),
            );
          }

          final isDebug = skinName == 'debug';
          
          // Legacy Path: Manual stacking for Standard/SVG skins
          final bool needsRotation = _isHorizontal && !isDebug;

          Widget buildLayer(String layer) {
            Widget renderer = DynamicSkinRenderer(
              widgetFolder: 'slider',
              layer: layer,
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
            );
            
            if (needsRotation) {
              return RotatedBox(quarterTurns: 3, child: renderer);
            }
            return renderer;
          }

          final thumbSize = _isHorizontal ? constraints.maxHeight : constraints.maxWidth;
          final travel = _isHorizontal ? constraints.maxWidth : constraints.maxHeight;

          final thumbOffset = _isHorizontal 
              ? Offset((normalizedValue - 0.5) * (travel - thumbSize), 0)
              : Offset(0, (0.5 - normalizedValue) * (travel - thumbSize));

          return Stack(
            children: [
              buildLayer('track'),
              Transform.translate(
                offset: thumbOffset,
                child: buildLayer('thumb'),
              ),
            ],
          );
        },
      ),
    );
  }
}
