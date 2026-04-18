import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import 'button_widget.dart';

/// Toggle switch widget — conceptually a latched push button.
/// Renders identically to [ButtonWidget], but is statically 
/// mapped from the `WidgetType.Switch` type.
class SwitchWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const SwitchWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // A Switch is conceptually identical to a ButtonWidget with variant=1 (Toggle).
    // The underlying ButtonWidget handles latched states based on config type.
    return ButtonWidget(
      config: config,
      value: value,
      onChanged: onChanged,
    );
  }
}
