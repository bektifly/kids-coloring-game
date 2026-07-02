import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';

class ColoringGame extends FlameGame with TapDetector {
  late Color selectedColor;
  final Map<String, Color> fillColors = {};

  ColoringGame({required this.selectedColor});

  void selectColor(Color color) {
    selectedColor = color;
  }

  void fillRegion(String regionId, Color color) {
    fillColors[regionId] = color;
  }

  @override
  Future<void> onLoad() async {
    // Add coloring regions
    final regions = [
      // Sky
      RegionComponent(
        id: 'sky',
        position: Vector2(0, 0),
        size: Vector2(400, 200),
        fillColor: Colors.lightBlue.shade100,
      ),
      // Grass
      RegionComponent(
        id: 'grass',
        position: Vector2(0, 200),
        size: Vector2(400, 200),
        fillColor: Colors.lightGreen.shade200,
      ),
      // Sun
      RegionComponent(
        id: 'sun',
        position: Vector2(300, 20),
        size: Vector2(80, 80),
        fillColor: Colors.amber.shade200,
      ),
      // Flower 1
      RegionComponent(
        id: 'flower1',
        position: Vector2(50, 250),
        size: Vector2(60, 60),
        fillColor: Colors.pink.shade200,
      ),
      // Flower 2
      RegionComponent(
        id: 'flower2',
        position: Vector2(200, 250),
        size: Vector2(60, 60),
        fillColor: Colors.purple.shade200,
      ),
    ];

    for (var region in regions) {
      add(region);
    }

    // Add border outlines
    final borders = [
      BorderComponent(
        position: Vector2(0, 0),
        size: Vector2(400, 200),
      ),
      BorderComponent(
        position: Vector2(0, 200),
        size: Vector2(400, 200),
      ),
      BorderComponent(
        position: Vector2(300, 20),
        size: Vector2(80, 80),
      ),
      BorderComponent(
        position: Vector2(50, 250),
        size: Vector2(60, 60),
      ),
      BorderComponent(
        position: Vector2(200, 250),
        size: Vector2(60, 60),
      ),
    ];

    for (var border in borders) {
      add(border);
    }
  }

  @override
  void onTap(TapEvent event) {
    // Find which region was tapped
    for (final component in children) {
      if (component is RegionComponent && component.containsPosition(event.position)) {
        component.fillColor = selectedColor;
        fillRegions.add(component.id);
        break;
      }
    }
  }

  final List<String> fillRegions = [];
}

class RegionComponent extends PositionComponent with TapDetector {
  String id;
  Color fillColor;
  final Paint _paint = Paint()..isAntiAlias = true;

  RegionComponent({
    required this.id,
    required Vector2 position,
    required Vector2 size,
    required this.fillColor,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    _paint.color = fillColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      _paint,
    );
  }

  @override
  bool containsPosition(Vector2 position) {
    return super.containsPosition(position);
  }
}

class BorderComponent extends PositionComponent {
  final Paint _paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  BorderComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      _paint,
    );
  }
}
