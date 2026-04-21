import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../utils/icon_utils.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// Displays a read-only text value sent by the device.
/// If [config.icon] is set (kStrMaskIcon), an icon is shown alongside the text.
/// Uses the 'display' skin folder for its background bezel.
class TextWidget extends StatelessWidget {
  final WidgetConfig config;
  final String text;
  final double scale;

  const TextWidget({
    super.key,
    required this.config,
    required this.text,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasIcon = (config.strMask & kStrMaskIcon) != 0 &&
        config.icon.isNotEmpty;

    return Stack(
      children: [
        // Skinned background bezel
        Positioned.fill(
          child: DynamicSkinRenderer(
            widgetFolder: 'display',
            state: RKSkinState(
              styleIndex: config.style,
              label: config.label,
              content: text,
              x: config.x,
              y: config.y,
              scale: scale,
            ),
          ),
        ),
        // Text overlay
        Center(
          child: Padding(
            padding: EdgeInsets.all(6 * scale),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (config.label.isNotEmpty)
                      Text(
                        config.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: (Theme.of(context).textTheme.labelSmall?.fontSize ?? 10) * scale,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 2 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasIcon) ...[
                          Icon(
                            parseIconFromName(config.icon),
                            size: 14 * scale,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 4 * scale),
                        ],
                        Flexible(
                          child: Text(
                            text.isEmpty ? '—' : text,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scale,
                                ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

