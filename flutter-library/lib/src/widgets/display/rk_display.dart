import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/rk_theme.dart';

/// A text display output widget for RadioKit.
class RKDisplay extends StatelessWidget {
  const RKDisplay({
    super.key,
    required this.text,
    this.width = 180,
    this.height = 40,
    this.fontSize = 14,
    this.fontFamily = 'monospace',
    this.textColor,
    this.orientation = RKAxis.horizontal,
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
  });

  final String text;
  final double width;
  final double height;
  final double fontSize;
  final String fontFamily;
  final Color? textColor;
  final RKAxis orientation;
  final ValueChanged<bool>? onInteractionChanged;
  final double rotation;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final isVertical = orientation == RKAxis.vertical;

    final baseStyle = TextStyle(
      color: textColor ?? tokens.primary,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );

    TextStyle textStyle;
    if (['monospace', 'serif', 'sans-serif'].contains(fontFamily)) {
      textStyle = baseStyle;
    } else {
      try {
        textStyle = GoogleFonts.getFont(fontFamily, textStyle: baseStyle);
      } catch (_) {
        textStyle = baseStyle;
      }
    }
    
    Widget content = Listener(
      onPointerDown: (_) => onInteractionChanged?.call(true),
      onPointerUp: (_) => onInteractionChanged?.call(false),
      onPointerCancel: (_) => onInteractionChanged?.call(false),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          border: Border.all(color: tokens.trackColor, width: 1.5),
        ),
        child: Text(
          text,
          style: textStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    Widget finalContent;
    if (isVertical) {
      finalContent = RotatedBox(
        quarterTurns: 1,
        child: content,
      );
    } else {
      finalContent = content;
    }

    return Transform.rotate(
      angle: rotation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null && label!.isNotEmpty) ...[
            Text(
              label!.toUpperCase(),
              style: TextStyle(
                color: tokens.primary.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
          ],
          finalContent,
        ],
      ),
    );
  }
}
