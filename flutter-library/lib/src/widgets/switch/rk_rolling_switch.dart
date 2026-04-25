import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';

/// A premium rolling toggle switch for RadioKit.
///
/// The thumb rotates as it slides, creating a "rolling" effect.
class RKRollingSwitch extends StatefulWidget {
  const RKRollingSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 110.0,
    this.height = 44.0,
    this.onChild,
    this.offChild,
    this.onThumbChild,
    this.offThumbChild,
    this.activeColor,
    this.inactiveColor,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
    this.rotation = 0.0,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final double width;
  final double height;
  final Widget? onChild;
  final Widget? offChild;
  final Widget? onThumbChild;
  final Widget? offThumbChild;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool enableHapticFeedback;
  final double rotation;


  @override
  State<RKRollingSwitch> createState() => _RKRollingSwitchState();
}

class _RKRollingSwitchState extends State<RKRollingSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(RKRollingSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final activeColor = widget.activeColor ?? tokens.primary;
    final inactiveColor = widget.inactiveColor ?? tokens.trackColor;

    final width = widget.width;
    final height = widget.height;

    final thumbPadding = 4.0;
    final thumbSize = height - (thumbPadding * 2);
    final trackRadius = height / 2;

    return Transform.rotate(
      angle: widget.rotation,
      child: GestureDetector(
      onTapDown: (_) => widget.onInteractionChanged?.call(true),
      onTapUp: (_) => widget.onInteractionChanged?.call(false),
      onTapCancel: () => widget.onInteractionChanged?.call(false),
      onTap: () {
        if (_isDragging) return;
        if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
        widget.onChanged(!widget.value);
      },
      onHorizontalDragStart: (_) {
        _isDragging = true;
        widget.onInteractionChanged?.call(true);
      },
      onHorizontalDragUpdate: (details) {
        final dragRange = width - thumbSize - (thumbPadding * 2);
        _controller.value = (_controller.value + details.primaryDelta! / dragRange).clamp(0.0, 1.0);
      },
      onHorizontalDragEnd: (details) {
        _isDragging = false;
        widget.onInteractionChanged?.call(false);
        final newValue = _controller.value >= 0.5;
        if (newValue != widget.value) {
          if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
          widget.onChanged(newValue);
        } else {
          if (widget.value) _controller.forward(); else _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final pos = _animation.value;
          final rotation = pos * math.pi * 2; // Full rotation
          final currentColor = Color.lerp(inactiveColor, activeColor, pos)!;

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(trackRadius),
              border: Border.all(color: tokens.trackColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Labels positioned fixed (Opposite to thumb position for visibility)
                if (widget.offChild != null)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - pos).clamp(0.0, 1.0),
                        child: widget.offChild,
                      ),
                    ),
                  ),
                if (widget.onChild != null)
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: pos.clamp(0.0, 1.0),
                        child: widget.onChild,
                      ),
                    ),
                  ),

                // Rolling Thumb
                Positioned(
                  left: thumbPadding + pos * (width - thumbSize - (thumbPadding * 2)),
                  top: thumbPadding,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentColor,
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                          center: const Alignment(-0.3, -0.3),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (widget.offThumbChild != null)
                            Center(
                              child: Opacity(
                                opacity: (1.0 - pos).clamp(0.0, 1.0),
                                child: widget.offThumbChild,
                              ),
                            ),
                          if (widget.onThumbChild != null)
                            Center(
                              child: Opacity(
                                opacity: pos.clamp(0.0, 1.0),
                                child: widget.onThumbChild,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
