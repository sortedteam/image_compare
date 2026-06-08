import 'package:flutter/material.dart';

import 'compare_lab_screen.dart';

void main() {
  runApp(const ImageCompareLabApp());
}

class ImageCompareLabApp extends StatelessWidget {
  const ImageCompareLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Compare Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CompareLabScreen(),
    );
  }
}
