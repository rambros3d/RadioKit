import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/app_theme.dart';

/// Read-only text display widget.
///
/// Shows a string value received from the Arduino (up to 32 bytes).
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.widgetBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with label
          if (config.label.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Text(
                config.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: text.isEmpty
                    ? Text(
                        '—',
                        style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
