import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'theme/skin/skin_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dynamic skins v1.6
  final skinManager = SkinManager();
  await skinManager.init();

  // Lock orientation to portrait for consistent widget layout
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar with adaptive brightness
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(RadioKitApp(skinManager: skinManager));
}
