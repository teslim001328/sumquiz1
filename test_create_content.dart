import 'package:flutter/material.dart';
import 'package:sumquiz/views/screens/web/create_content_screen_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Create Content Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CreateContentScreenWeb(),
    );
  }
}
