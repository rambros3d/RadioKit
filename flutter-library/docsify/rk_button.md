# RKButton

**A hardware‑style button widget for RadioKit.**

- **Mode**: `push` (momentary) or `toggle` (latching).
- **Features**: optional label, icon, custom active colour, haptic feedback, interaction callbacks.

## Constructor
```dart
RKButton({
  required ValueChanged<bool> onChanged,
  RKButtonMode mode = RKButtonMode.push,
  String? label,
  IconData? icon,
  String? onText,
  String? offText,
  IconData? onIcon,
  IconData? offIcon,
  double size = 64.0,
  Color? activeColor,
  bool enableHapticFeedback = true,
  ValueChanged<bool>? onInteractionChanged,
})
```

> [!NOTE]
> `RKButton` uses a fixed vertical layout with the label/icon positioned above the physical button.

| Parameter | Description |
|---|---|
| `onChanged` | Called with the new logical state (`true`/`false`). |
| `mode` | `RKButtonMode.push` for momentary press, `RKButtonMode.toggle` for latch. |
| `label` / `icon` | Visual content shown on the button. |
| `onText` / `offText` | Text shown when the button is in the respective state (overrides label). |
| `onIcon` / `offIcon` | Icons shown for each state. |
| `size` | Diameter of the circular button. |
| `activeColor` | Colour of the glow when active; defaults to theme primary. |
| `enableHapticFeedback` | Emit a light haptic pulse on interaction. |
| `onInteractionChanged` | Optional callback when the user starts/stops touching the widget. |

## Example
```dart
bool _power = false;

RKButton(
  mode: RKButtonMode.toggle,
  label: 'Power',
  onChanged: (v) => setState(() => _power = v),
);
```

The button will glow with the theme's primary colour when toggled on.
