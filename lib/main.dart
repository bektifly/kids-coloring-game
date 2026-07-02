import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const KidsColorGame());
}

class KidsColorGame extends StatefulWidget {
  const KidsColorGame({super.key});

  @override
  State<KidsColorGame> createState() => _KidsColorGameState();
}

class _KidsColorGameState extends State<KidsColorGame> {
  Color selectedColor = Colors.red;
  final Map<String, Color> fillColors = {
    'sky': Colors.lightBlue.shade100,
    'grass': Colors.lightGreen.shade200,
    'sun': Colors.amber.shade200,
    'flower1': Colors.pink.shade200,
    'flower2': Colors.purple.shade200,
  };

  final List<Color> colors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow,
    Colors.orange, Colors.purple, Colors.pink, Colors.black, Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Coloring Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Column(
          children: [
            // Color Palette
            Container(
              height: 80,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedColor = color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color
                              ? Colors.black
                              : Colors.grey.shade300,
                          width: selectedColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Game Canvas
            Expanded(
              child: ColoringCanvas(
                selectedColor: selectedColor,
                fillColors: fillColors,
                onColorTap: (region, color) {
                  setState(() => fillColors[region] = color);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ColoringCanvas extends StatelessWidget {
  final Color selectedColor;
  final Map<String, Color> fillColors;
  final Function(String, Color) onColorTap;

  const ColoringCanvas({
    super.key,
    required this.selectedColor,
    required this.fillColors,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return GestureDetector(
          onTapUp: (details) {
            final local = details.localPosition;
            // Check which region was tapped
            if (local.dy < height * 0.4) {
              onColorTap('sky', selectedColor);
            } else if (local.dy < height * 0.5) {
              onColorTap('sun', selectedColor);
            } else if (local.dx < width * 0.2 && local.dy > height * 0.6) {
              onColorTap('flower1', selectedColor);
            } else if (local.dx > width * 0.4 && local.dy > height * 0.6) {
              onColorTap('flower2', selectedColor);
            } else {
              onColorTap('grass', selectedColor);
            }
          },
          child: CustomPaint(
            size: Size(width, height),
            painter: ColoringPainter(fillColors),
          ),
        );
      },
    );
  }
}

class ColoringPainter extends CustomPainter {
  final Map<String, Color> fillColors;

  ColoringPainter(this.fillColors);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky
    canvas.drawColor(
      fillColors['sky'] ?? Colors.lightBlue.shade100,
      BlendMode.src,
    );
    // Sky border
    canvas.drawLine(
      Offset(0, h * 0.4),
      Offset(w, h * 0.4),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 3,
    );

    // Grass
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.4, w, h * 0.6),
      Paint()
        ..color = fillColors['grass'] ?? Colors.lightGreen.shade200,
    );
    // Grass border
    canvas.drawLine(
      Offset(0, h * 1.0),
      Offset(w, h * 1.0),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 3,
    );

    // Sun
    canvas.drawCircle(
      Offset(w * 0.75, h * 0.2),
      w * 0.1,
      Paint()
        ..color = fillColors['sun'] ?? Colors.amber.shade200,
    );
    canvas.drawCircle(
      Offset(w * 0.75, h * 0.2),
      w * 0.1,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Flower 1
    final fx1 = w * 0.1;
    final fy1 = h * 0.7;
    final fr = w * 0.04;
    canvas.drawCircle(Offset(fx1, fy1), fr, Paint()..color = fillColors['flower1'] ?? Colors.pink.shade200);
    canvas.drawCircle(Offset(fx1, fy1), fr, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx1 - fr, fy1), fr * 0.6, Paint()..color = fillColors['flower1'] ?? Colors.pink.shade200);
    canvas.drawCircle(Offset(fx1 - fr, fy1), fr * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx1 + fr, fy1), fr * 0.6, Paint()..color = fillColors['flower1'] ?? Colors.pink.shade200);
    canvas.drawCircle(Offset(fx1 + fr, fy1), fr * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx1, fy1 - fr), fr * 0.6, Paint()..color = fillColors['flower1'] ?? Colors.pink.shade200);
    canvas.drawCircle(Offset(fx1, fy1 - fr), fr * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx1, fy1 + fr), fr * 0.6, Paint()..color = fillColors['flower1'] ?? Colors.pink.shade200);
    canvas.drawCircle(Offset(fx1, fy1 + fr), fr * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    // Stem
    canvas.drawLine(Offset(fx1, fy1 + fr), Offset(fx1, fy1 + fr * 3), Paint()..color = Colors.green..strokeWidth = 3);

    // Flower 2
    final fx2 = w * 0.45;
    final fy2 = h * 0.75;
    final fr2 = w * 0.05;
    canvas.drawCircle(Offset(fx2, fy2), fr2, Paint()..color = fillColors['flower2'] ?? Colors.purple.shade200);
    canvas.drawCircle(Offset(fx2, fy2), fr2, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx2 - fr2, fy2), fr2 * 0.6, Paint()..color = fillColors['flower2'] ?? Colors.purple.shade200);
    canvas.drawCircle(Offset(fx2 - fr2, fy2), fr2 * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx2 + fr2, fy2), fr2 * 0.6, Paint()..color = fillColors['flower2'] ?? Colors.purple.shade200);
    canvas.drawCircle(Offset(fx2 + fr2, fy2), fr2 * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx2, fy2 - fr2), fr2 * 0.6, Paint()..color = fillColors['flower2'] ?? Colors.purple.shade200);
    canvas.drawCircle(Offset(fx2, fy2 - fr2), fr2 * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(fx2, fy2 + fr2), fr2 * 0.6, Paint()..color = fillColors['flower2'] ?? Colors.purple.shade200);
    canvas.drawCircle(Offset(fx2, fy2 + fr2), fr2 * 0.6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(Offset(fx2, fy2 + fr2), Offset(fx2, fy2 + fr2 * 3), Paint()..color = Colors.green..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
