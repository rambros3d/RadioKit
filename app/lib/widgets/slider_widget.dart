import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/widget_config.dart';
import '../providers/skin_provider.dart';
import '../models/skin_manifest.dart';
import '../theme/app_theme.dart';

/// Linear slider widget (0 to 100).
///
/// Shows the current value as a label and sends updates on change.
class SliderWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.watch<SkinProvider>().tokens;
    final surfaceColor = tokens.colors['surface'] ?? Theme.of(context).cardTheme.color;
    final primaryColor = tokens.colors['primary'] ?? Theme.of(context).colorScheme.primary;
    final fgColor = tokens.colors['dim'] ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(tokens.borderRadius + 4),
        border: Border.all(
            color: primaryColor!.withValues(alpha: 0.3),
            width: tokens.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 160, // Fixed internal width for slider to have spread
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label + value row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        config.label.isNotEmpty ? config.label : 'Slider',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.borderRadius),
                      ),
                      child: Text(
                        value.toString(),
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: tokens.fontWeight == 'bold' || tokens.fontWeight == '700' 
                                      ? FontWeight.bold 
                                      : (tokens.fontWeight == '900' ? FontWeight.w900 : FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryColor,
                    thumbColor: primaryColor,
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: value.toString(),
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),

                // Min / Max labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor.withValues(alpha: 0.5),
                          fontSize: 10,
                        )),
                    Text('100',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor.withValues(alpha: 0.5),
                          fontSize: 10,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
