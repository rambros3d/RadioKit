import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A wrapper that handles RadioKit widget rotation and ensures the layout
/// respects the rotated bounding box, preventing overflows in preview containers.
class RKRotatedWrapper extends StatelessWidget {
  final double rotation;
  final String? label;
  final Widget child;
  final double contentWidth;
  final double contentHeight;
  final Color labelColor;

  const RKRotatedWrapper({
    super.key,
    required this.rotation,
    required this.child,
    required this.contentWidth,
    required this.contentHeight,
    required this.labelColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (rotation == 0 && (label == null || label!.isEmpty)) {
      return child;
    }

    final double labelH = (label != null && label!.isNotEmpty) ? 33.0 : 0.0; // 25 (text) + 8 (gap)
    final double totalH = contentHeight + (labelH * 2); // Double for symmetry
    final double totalW = math.max(contentWidth, 120.0); // Minimum width for labels

    // Calculate the bounding box of the rotated rectangle
    final double absCos = math.cos(rotation).abs();
    final double absSin = math.sin(rotation).abs();
    
    final double rotatedW = totalW * absCos + totalH * absSin;
    final double rotatedH = totalW * absSin + totalH * absCos;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: rotatedW,
          height: rotatedH,
          child: Center(
            child: Transform.rotate(
              angle: rotation,
              child: SizedBox(
                width: totalW,
                height: totalH,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (label != null && label!.isNotEmpty) ...[
                      Text(
                        label!.toUpperCase(),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    child,
                    if (label != null && label!.isNotEmpty)
                      const SizedBox(height: 33), // Match top spacer height (text + gap)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

  }
}
