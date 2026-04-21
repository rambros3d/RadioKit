import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// Renders a push button (momentary) or toggle button (latched) based on
/// [config.variant]: 0 = push/momentary, 1 = toggle.
class ButtonWidget extends StatefulWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;
  final double scale;

  const ButtonWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  bool _localPressed = false;

  bool get _isToggle => widget.config.variant == 1 || widget.config.typeId == kWidgetSwitch;
  String get _folder => _isToggle ? 'button_toggle' : 'button_push';

  void _handleTapDown(TapDownDetails details) {
    if (_isToggle) return;
    setState(() => _localPressed = true);
    widget.onChanged(1);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isToggle) return;
    setState(() => _localPressed = false);
    widget.onChanged(0);
  }

  void _handleTapCancel() {
    if (_isToggle) return;
    setState(() => _localPressed = false);
    widget.onChanged(0);
  }

  void _handleTap() {
    if (!_isToggle) return;
    widget.onChanged(widget.value != 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: DynamicSkinRenderer(
        widgetFolder: _folder,
        state: RKSkinState(
          isPressed: _isToggle ? (widget.value != 0) : _localPressed,
          isOn: widget.value != 0,
          value: widget.value.toDouble(),
          x: widget.config.x,
          y: widget.config.y,
          styleIndex: widget.config.style,
          isEnabled: true,
          label: widget.config.label,
          icon: widget.config.icon,
          scale: widget.scale,
        ),
      ),
    );
  }
}
