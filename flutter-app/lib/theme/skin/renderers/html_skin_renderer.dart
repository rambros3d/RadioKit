import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';

/// Renders HTML/CSS-based skins.
class HtmlSkinRenderer extends SkinRenderer {
  const HtmlSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
  });

  @override
  Widget build(BuildContext context) {
    final manager = SkinManager();

    return FutureBuilder<List<String?>>(
      future: Future.wait([
        manager.loadString(widgetFolder, 'widget.html'),
        manager.loadString(widgetFolder, 'widget.css'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data![0] == null) {
          return const SizedBox.shrink();
        }

        final html = snapshot.data![0]!;
        final css = snapshot.data![1] ?? '';
        
        final stateClasses = _buildStateClasses();
        final styleIndexClass = 'rk-style-${state.styleIndex}';
        
        // Inject variables for X/Y positions (scaled -100..100)
        final activeColor = state.colorOverride ?? Colors.transparent;
        final colorHex = '#${activeColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

        final fullHtml = '''
          <style>$css</style>
          <div class="rk-root $stateClasses $styleIndexClass" 
               style="--rk-x: ${state.valueX * 100}; --rk-y: ${state.valueY * 100}; --rk-val: ${state.value * 100}; --rk-color: $colorHex;">
            $html
          </div>
        ''';

        return HtmlWidget(
          fullHtml,
          textStyle: const TextStyle(fontSize: 14),
        );
      },
    );
  }

  String _buildStateClasses() {
    final List<String> classes = [];
    if (state.isPressed) classes.add('rk-pressed');
    if (state.isEnabled) classes.add('rk-enabled'); else classes.add('rk-disabled');
    if (state.isOn) classes.add('rk-on'); else classes.add('rk-off');
    return classes.join(' ');
  }
}
