import 'package:flutter/material.dart';
import 'screens/converter_screen.dart';

void main() {
  runApp(const GifConverterApp());
}

class GifConverterApp extends StatelessWidget {
  const GifConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GifDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ConverterScreen(),
    );
  }
}
