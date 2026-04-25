# RadioKit Widgets

A Flutter widget library providing hardware‑control UI components designed for use with the [RadioKit](https://github.com/rambros3d/RadioKit) Arduino framework.

## Installation
Add the package to your **pubspec.yaml**:

```yaml
dependencies:
  radiokit_widgets: ^0.0.1
```

Import the public library entry point:

```dart
import 'package:radiokit_widgets/radiokit_widgets.dart';
```

## Widgets Overview

- [RKButton](rk_button.md)
- [RKSwitch](rk_switch.md)
- [RKRollingSwitch](rk_rolling_switch.md)
- [RKRockerSwitch](rk_rocker_switch.md)
- [RKSlider](rk_slider.md)
- [RKKnob](rk_knob.md)
- [RKJoystick](rk_joystick.md)
- [RKLed](rk_led.md)
- [RKMultiButton](rk_multi_button.md)
- [RKMultiSelect](rk_multi_select.md)
- [RKDisplay](rk_display.md)

Each widget follows the RadioKit visual language – industrial‑grade, 3‑D depth, and optional haptic feedback.

## Getting Started

```dart
class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  bool _buttonOn = false;
  double _sliderValue = 0.5;

  @override
  Widget build(BuildContext context) {
    return RKTheme(
      tokens: RKTokens.defaultTokens(),
      child: Scaffold(
        backgroundColor: RKTheme.of(context).surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RKButton(
                mode: RKButtonMode.toggle,
                label: 'Power',
                onChanged: (v) => setState(() => _buttonOn = v),
              ),
              const SizedBox(height: 24),
              RKSlider(
                value: _sliderValue,
                onChanged: (v) => setState(() => _sliderValue = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Explore each widget's dedicated page for a full API reference and usage snippets.
