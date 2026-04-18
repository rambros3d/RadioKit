import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget renderSvgFile(String path, {Color? color, double? width, double? height}) {
  return SvgPicture.file(
    File(path),
    colorFilter: color != null 
        ? ColorFilter.mode(color, BlendMode.srcIn) 
        : null,
    width: width,
    height: height,
  );
}
