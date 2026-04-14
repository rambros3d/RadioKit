import 'package:flutter/foundation.dart';
import '../models/console_entry.dart';

class ConsoleProvider extends ChangeNotifier {
  final List<ConsoleEntry> _entries = [];
  final int _maxEntries = 100;

  List<ConsoleEntry> get entries => _entries;

  void log(String message, {ConsoleLogLevel level = ConsoleLogLevel.info}) {
    if (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(ConsoleEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    ));
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
