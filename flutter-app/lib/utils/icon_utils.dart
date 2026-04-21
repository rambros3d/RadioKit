import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Maps a string identifier (e.g. "play", "settings") to a Lucide icon.
/// Used by widgets like TextWidget and MultipleWidget to display icons.
IconData? parseIconFromName(String name) {
  final clean = name.toLowerCase().trim();
  if (clean.isEmpty) return null;
  switch (clean) {
    case 'settings': return LucideIcons.settings;
    case 'play':     return LucideIcons.play;
    case 'pause':    return LucideIcons.pause;
    case 'stop':     return LucideIcons.square;
    case 'power':    return LucideIcons.power;
    case 'volume':   return LucideIcons.volume2;
    case 'mute':     return LucideIcons.volumeX;
    case 'mic':      return LucideIcons.mic;
    case 'wifi':     return LucideIcons.wifi;
    case 'bluetooth':return LucideIcons.bluetooth;
    case 'home':     return LucideIcons.house;
    case 'user':     return LucideIcons.user;
    case 'lock':     return LucideIcons.lock;
    case 'unlock':   return LucideIcons.lockOpen;
    case 'light':    return LucideIcons.sun;
    case 'dark':     return LucideIcons.moon;
    case 'up':       return LucideIcons.chevronUp;
    case 'down':     return LucideIcons.chevronDown;
    case 'left':     return LucideIcons.chevronLeft;
    case 'right':    return LucideIcons.chevronRight;
    case 'plus':     return LucideIcons.plus;
    case 'minus':    return LucideIcons.minus;
    case 'check':    return LucideIcons.check;
    case 'x':        return LucideIcons.x;
    default:         return LucideIcons.circleQuestionMark;
  }
}
