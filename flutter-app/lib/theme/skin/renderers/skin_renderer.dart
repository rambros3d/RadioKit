import 'package:flutter/material.dart';
import '../skin_manager.dart';
import '../behavior_config.dart';

/// Base class for all skin-aware widget renderers.
abstract class SkinRenderer extends StatelessWidget {
  final String widgetFolder;
  final RKSkinState state;
  final String? layer;

  const SkinRenderer({
    super.key,
    required this.widgetFolder,
    required this.state,
    this.layer,
  });
}

/// Helper class to pass widget state into the renderer.
class RKSkinState {
  final bool isPressed;
  final bool isEnabled;
  final bool isOn;
  final double value; // Primary value (0-1)
  final double valueX; // 2D X-axis (-1 to 1)
  final double valueY; // 2D Y-axis (-1 to 1)
  final int styleIndex;
  final Color? colorOverride; // For dynamic RGB LEDs
  final String label;
  final String icon;
  final double scale;

  const RKSkinState({
    this.isPressed = false,
    this.isEnabled = true,
    this.isOn = false,
    this.value = 0.0,
    this.valueX = 0.0,
    this.valueY = 0.0,
    this.styleIndex = 0,
    this.colorOverride,
    this.label = '',
    this.icon = '',
    this.scale = 1.0,
  });
}
