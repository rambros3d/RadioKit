import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../providers/skin_provider.dart';

/// Linear slider widget (-100 to +100).
///
/// Self-centering and detent snapping governed by the config.variant byte.
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

  void _onChangeEnd(double _) {
    _springController.stop();
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
    final tokens       = context.watch<SkinProvider>().tokens;
    final surfaceColor = tokens.colors['surface'] ?? Theme.of(context).cardTheme.color;
    final primaryColor  = tokens.colors['primary'] ?? Theme.of(context).colorScheme.primary;
    final fgColor       = tokens.colors['dim']     ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;
    final centering     = variantCentering(widget.config.variant);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(tokens.borderRadius + 4),
        border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
            width: tokens.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label + value row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.config.label.isNotEmpty
                            ? widget.config.label
                            : 'Slider',
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
                        borderRadius:
                            BorderRadius.circular(tokens.borderRadius),
                      ),
                      child: Text(
                        '${widget.value > 0 ? '+' : ''}${widget.value}',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Slider
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center line indicator
                    if (centering != kCenterNone)
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 1,
                            height: 20,
                            color: primaryColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor:   primaryColor,
                        inactiveTrackColor: primaryColor.withValues(alpha: 0.2),
                        thumbColor:         primaryColor,
                        trackHeight:        4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 18),
                      ),
                      child: Slider(
                        value: widget.value.toDouble(),
                        min:   -100,
                        max:    100,
                        divisions: 200,
                        label: '${widget.value > 0 ? '+' : ''}${widget.value}',
                        onChanged:   (v) => widget.onChanged(v.round()),
                        onChangeEnd: _onChangeEnd,
                      ),
                    ),
                  ],
                ),

                // Min / Mid / Max labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('-100',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor.withValues(alpha: 0.5),
                          fontSize: 9,
                        )),
                    Text('0',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor.withValues(alpha: 0.35),
                          fontSize: 9,
                        )),
                    Text('+100',
                        style: GoogleFonts.getFont(
                          tokens.fontFamily,
                          color: fgColor.withValues(alpha: 0.5),
                          fontSize: 9,
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
