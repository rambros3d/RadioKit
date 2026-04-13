import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/app_theme.dart';

/// Momentary push-button widget.
///
/// Value = 1 while the finger is pressed down, 0 when released.
class ButtonWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const ButtonWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressController.forward();
    widget.onChanged(1);
  }

  void _onTapUp(TapUpDetails _) {
    _release();
  }

  void _onTapCancel() {
    _release();
  }

  void _release() {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            color: _isPressed ? AppColors.highlightDim : AppColors.highlight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.highlight
                    .withOpacity(_isPressed ? 0.2 : 0.4),
                blurRadius: _isPressed ? 4 : 12,
                spreadRadius: _isPressed ? 0 : 2,
                offset: Offset(0, _isPressed ? 1 : 4),
              ),
            ],
            border: Border.all(
              color: _isPressed
                  ? AppColors.highlightDim
                  : AppColors.highlight.withOpacity(0.8),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.config.label.isNotEmpty) ...[
                  Icon(
                    Icons.radio_button_checked_rounded,
                    color: AppColors.textPrimary
                        .withOpacity(_isPressed ? 0.7 : 1.0),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.config.label,
                    style: TextStyle(
                      color: AppColors.textPrimary
                          .withOpacity(_isPressed ? 0.7 : 1.0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else
                  Icon(
                    Icons.radio_button_checked_rounded,
                    color: AppColors.textPrimary
                        .withOpacity(_isPressed ? 0.7 : 1.0),
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
