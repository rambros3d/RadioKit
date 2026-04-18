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

  const TextWidget({
    super.key,
    required this.config,
    required this.text,
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
            ),
          ),
        ),
        // Text overlay
        Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasIcon) ...[
                          Icon(
                            parseIconFromName(config.icon),
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            text.isEmpty ? '—' : text,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
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

