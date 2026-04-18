import 'package:flutter/material.dart';
import 'dart:async';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// Linear slider widget (-100 to +100) using v1.6 skin engine.
/// Maintains physics-based interaction while delegating rendering to the skin engine.
class SliderWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const SliderWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
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

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _isDragging = true);
    _springController.stop();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    
    // Calculate 0..1 based on vertical height
    // Assume top is 100, bottom is -100
    final percent = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
    // Convert to -100..100
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
    // Normalize -100..100 to 0..1 for the renderer
    final normalizedValue = (widget.value + 100) / 200.0;

    return AspectRatio(
      aspectRatio: 55 / 132, // Match the premium asset ratio
      child: GestureDetector(
        onPanUpdate: _onDragUpdate,
        onPanEnd:    _onDragEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Layer 1: Track (Stationary)
            DynamicSkinRenderer(
              widgetFolder: 'slider',
              layer: 'track',
              state: RKSkinState(
                isPressed: _isDragging,
                styleIndex: widget.config.style,
              ),
            ),
            // Layer 2: Thumb (Moving)
            // We translate the thumb vertically. 
            // The thumb asset is full track height (132), so we offset it.
            LayoutBuilder(
              builder: (context, constraints) {
                final totalHeight = constraints.maxHeight;
                // Move from center-bottom to center-top
                final offset = (0.5 - normalizedValue) * totalHeight;
                
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: DynamicSkinRenderer(
                    widgetFolder: 'slider',
                    layer: 'thumb',
                    state: RKSkinState(
                      isPressed: _isDragging,
                      styleIndex: widget.config.style,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
