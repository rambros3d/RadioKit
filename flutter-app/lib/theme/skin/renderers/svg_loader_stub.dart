import 'package:flutter/material.dart';

Widget renderSvgFile(String path, {Color? color, double? width, double? height}) {
  // Sideloading from raw local file paths is not supported on Web.
  // We return a sized box or an info icon to indicate the limitation.
  return SizedBox(
    width: width,
    height: height,
    child: Icon(Icons.broken_image_outlined, color: color, size: (width ?? 24) * 0.8),
  );
}
