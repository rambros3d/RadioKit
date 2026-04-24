# RKLed

**LED indicator widget for RadioKit** – a simple circular light that can be turned on or off and optionally tinted.

## Constructor
```dart
RKLed({
  required bool on,
  double size = 24.0,
  Color? color,
})
```

| Parameter | Description |
|---|---|
| `on` | Whether the LED is illuminated. |
| `size` | Diameter of the LED circle. |
| `color` | Optional colour; defaults to the theme's primary colour. |

When `on` is true the LED shows a glow using a subtle `BoxShadow`.

## Example
```dart
bool _connected = true;

RKLed(on: _connected, color: Colors.green);
```
