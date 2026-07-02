import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../widgets/coloring_game_widget.dart';

class ColoringScreen extends StatelessWidget {
  const ColoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coloring Fun'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: const ColoringGameWidget(),
    );
  }
}
