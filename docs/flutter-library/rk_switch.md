# RKSwitch

**A premium animated toggle switch for RadioKit** featuring a sliding thumb, glow effects and optional icons/labels.

## Constructor
```dart
RKSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
  double width = 72.0,
  double height = 36.0,
  Widget? onChild,
  Widget? offChild,
  Widget? onThumbChild,
  Widget? offThumbChild,
  Color? activeColor,
  Color? inactiveColor,
  bool enableHapticFeedback = true,
  ValueChanged<bool>? onInteractionChanged,
  double rotation = 0.0,
  String? label,
})
```

> [!NOTE]
> `RKSwitch` is a fixed horizontal sliding switch.

| Parameter | Description |
|---|---|
| `value` | Current logical state (`true` = ON). |
| `onChanged` | Callback invoked when the user toggles the switch. |
| `onChild` / `offChild` | Widgets shown on the right/left side of the track. |
| `onThumbChild` / `offThumbChild` | Widgets displayed inside the thumb for each state. |
| `activeColor` / `inactiveColor` | Track colours when ON/OFF (defaults to theme primary/track). |
| `enableHapticFeedback` | Emit a light haptic impact on state change. |
| `onInteractionChanged` | Optional callback signalling interaction start/end. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

## Example
```dart
bool _lights = false;

RKSwitch(
  value: _lights,
  onChanged: (v) => setState(() => _lights = v),
  onChild: const Icon(Icons.lightbulb),
  offChild: const Icon(Icons.lightbulb_outline),
);
```

The switch animates the thumb and provides a subtle glow on the active side.
