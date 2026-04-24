import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';

/// A premium animated toggle switch for RadioKit.
///
/// Features a sliding thumb with glow effects and support for dual icons/labels.
class RKSwitch extends StatefulWidget {
  const RKSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 72.0,
    this.height = 36.0,
    this.onChild,
    this.offChild,
    this.onThumbChild,
    this.offThumbChild,
    this.activeColor,
    this.inactiveColor,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
  });

  /// Current state of the switch.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool> onChanged;

  /// Called when the user starts/stops touching the switch.
  final ValueChanged<bool>? onInteractionChanged;

  /// Width of the switch track.
  final double width;

  /// Height of the switch track.
  final double height;

  /// Widget displayed on the "on" side (right).
  final Widget? onChild;

  /// Widget displayed on the "off" side (left).
  final Widget? offChild;

  /// Optional widget to display inside the sliding thumb when "on".
  final Widget? onThumbChild;

  /// Optional widget to display inside the sliding thumb when "off".
  final Widget? offThumbChild;

  /// Color of the track when active. Defaults to tokens.primary.
  final Color? activeColor;

  /// Color of the track when inactive. Defaults to tokens.trackColor.
  final Color? inactiveColor;

  /// Whether to trigger haptic feedback on state changes.
  final bool enableHapticFeedback;



  @override
  State<RKSwitch> createState() => _RKSwitchState();
}

class _RKSwitchState extends State<RKSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );
  }

  @override
  void didUpdateWidget(RKSwitch oldWidget) {
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

  void _handleToggle() {
    if (_isDragging) return;
    if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
    widget.onChanged(!widget.value);
  }

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

    return GestureDetector(
      onTapDown: (_) => widget.onInteractionChanged?.call(true),
      onTapUp: (_) => widget.onInteractionChanged?.call(false),
      onTapCancel: () => widget.onInteractionChanged?.call(false),
      onTap: _handleToggle,
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
          final currentColor = Color.lerp(inactiveColor, activeColor, pos)!;

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(trackRadius),
              border: Border.all(color: tokens.trackColor, width: 1),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track Fill (Background)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(trackRadius),
                    ),
                  ),
                ),

                // Labels / Icons
                // Track Content (Opposite to thumb position for visibility)
                if (widget.offChild != null)
                  Positioned(
                    right: 8,
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
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: pos.clamp(0.0, 1.0),
                        child: widget.onChild,
                      ),
                    ),
                  ),

                // Sliding Thumb
                Positioned(
                  left: thumbPadding + pos * (width - thumbSize - (thumbPadding * 2)),
                  top: thumbPadding,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(Colors.white, activeColor, pos * 0.5)!,
                          currentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.5 * pos + 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
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
              ],
            ),
          );
        },
      ),
    );
  }
}
