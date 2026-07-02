import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'coloring_game.dart';

class ColoringGameWidget extends StatelessWidget {
  final Color selectedColor;
  const ColoringGameWidget({super.key, required this.selectedColor});

  @override
  Widget build(BuildContext context) {
    return GameWidget<ColoringGame>.game(
      game: ColoringGame(selectedColor: selectedColor),
    );
  }
}
