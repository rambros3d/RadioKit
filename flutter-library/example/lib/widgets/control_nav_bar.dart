import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Top navigation bar matching the CONTROL_SYS_V1.0 design.
class ControlNavBar extends StatelessWidget {
  const ControlNavBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _labels = [
    'BUTTONS',
    'SWITCHES',
    'SLIDERS',
    'KNOBS',
    'JOYSTICKS',
    'DISPLAY',
    'LEDS',
  ];

  static const _routes = [
    '/buttons',
    '/switches',
    '/sliders',
    '/knobs',
    '/joysticks',
    '/display',
    '/leds',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'HW_WIDGETS',
              style: TextStyle(
                color: tokens.primary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Nav items
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_labels.length, (i) {
                  final isActive = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _NavChip(
                      label: _labels[i],
                      isActive: isActive,
                      onTap: () => context.go(_routes[i]),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Right action icons
          Row(
            children: [
              Icon(LucideIcons.settings2, color: tokens.primary, size: 24),
              const SizedBox(width: 12),
              Icon(LucideIcons.code, color: tokens.primary, size: 24),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Icon(LucideIcons.wifi, color: tokens.primary, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isActive ? tokens.primary : const Color(0xFF888888),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
