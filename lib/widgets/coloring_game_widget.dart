import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColoringGameWidget extends StatefulWidget {
  const ColoringGameWidget({super.key});

  @override
  State<ColoringGameWidget> createState() => _ColoringGameWidgetState();
}

class _ColoringGameWidgetState extends State<ColoringGameWidget> {
  Color currentColor = Colors.red;
  double brushSize = 5.0;
  final List<Color> colors = [
    Colors.red, Colors.orange, Colors.yellow,
    Colors.green, Colors.blue, Colors.purple,
    Colors.brown, Colors.pink, Colors.black, Colors.white
  ];

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: BlockPicker(pickerColor: currentColor, onColorChanged: (color) {
          setState(() => currentColor = color);
          Navigator.pop(context);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            child: const Center(child: Text('Coloring Canvas Area')),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey[200],
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Brush Size:'),
                  Expanded(
                    child: Slider(
                      value: brushSize,
                      min: 1,
                      max: 20,
                      onChanged: (value) => setState(() => brushSize = value),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ...colors.map((color) => GestureDetector(
                    onTap: () => setState(() => currentColor = color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  )),
                  const SizedBox(width: 10),
                  IconButton(onPressed: _pickColor, icon: const Icon(Icons.colorize)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
