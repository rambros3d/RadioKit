import 'package:flutter/material.dart';
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
    
    // Calculate 0..1 based on horizontal width
    final percent = (localPos.dx / box.size.width).clamp(0.0, 1.0);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: _onDragUpdate,
          onPanEnd:    _onDragEnd,
          behavior: HitTestBehavior.opaque,
          child: DynamicSkinRenderer(
            widgetFolder: 'slider',
            state: RKSkinState(
              isPressed: _isDragging,
              value: normalizedValue,
              styleIndex: widget.config.style,
            ),
          ),
        );
      },
    );
  }
}
