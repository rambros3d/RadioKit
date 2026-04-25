# RKRollingSwitch

**A premium rolling toggle switch for RadioKit** where the thumb rotates as it slides, creating a rolling visual effect.

## Constructor
```dart
RKRollingSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
  double width = 110.0,
  double height = 44.0,
  Widget? onChild,
  Widget? offChild,
  Widget? onThumbChild,
  Widget? offThumbChild,
  Color? activeColor,
  Color? inactiveColor,
  bool enableHapticFeedback = true,
  ValueChanged<bool>? onInteractionChanged,
  double rotation = 0.0,
})
```

> [!NOTE]
> `RKRollingSwitch` is a fixed horizontal rolling switch.

| Parameter | Description |
|---|---|
| `value` | Current logical state (`true` = ON). |
| `onChanged` | Called when the switch toggles. |
| `onChild` / `offChild` | Widgets shown on the respective sides of the track. |
| `onThumbChild` / `offThumbChild` | Widgets displayed inside the moving thumb for each state. |
| `activeColor` / `inactiveColor` | Track colours for ON and OFF positions (defaults to theme primary/track). |
| `enableHapticFeedback` | Emit a light haptic pulse on tap/drag. |
| `onInteractionChanged` | Callback for interaction start/end. |
| `rotation` | Visual rotation of the widget in radians. |

## Example
```dart
bool _enabled = false;

RKRollingSwitch(
  value: _enabled,
  onChanged: (v) => setState(() => _enabled = v),
  onChild: const Text('ON'),
  offChild: const Text('OFF'),
);
```

The thumb rolls a full circle as it moves, with optional custom content inside.
