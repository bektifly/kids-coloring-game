# Kids Coloring Game - Flutter

## Structure
- lib/
  - main.dart (entry point)
  - screens/
    - home_screen.dart (category selection)
    - coloring_screen.dart (main coloring UI)
    - gallery_screen.dart (saved artworks)
  - widgets/
    - color_picker.dart
    - brush_tool.dart
    - save_button.dart
  - models/
    - coloring_page.dart (SVG/PNG outlines)
    - saved_art.dart
  - services/
    - firebase_auth.dart
    - admob_service.dart
    - storage_service.dart

## Assets
- assets/coloring-pages/ (SVG outlines)
- assets/brushes/ (brush textures)
- assets/palettes/ (color themes)

## Build
flutter pub get
flutter run
flutter build apk --release
