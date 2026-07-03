import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const _freeTemplateLimit = 20;
const _premiumProductId = 'premium_unlock';

bool get _isPremium => _premiumUnlocked;
bool _premiumUnlocked = false;

Future<void> _initPremiumState() async {
  final prefs = await SharedPreferences.getInstance();
  _premiumUnlocked = prefs.getBool('premium_unlocked') ?? false;
}

Future<void> _setPremiumUnlocked(bool value) async {
  _premiumUnlocked = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('premium_unlocked', value);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initPremiumState();
    await MobileAds.instance.initialize();
    await InAppPurchase.instance.restorePurchases();
  } catch (e) {
    debugPrint('Init error: $e');
  }
  runApp(const ColoringWorld());
}

class ColoringWorld extends StatelessWidget {
  const ColoringWorld({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coloring World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final List<Category> categories = [
    Category('Animals', Icons.pets, Colors.orange),
    Category('Nature', Icons.landscape, Colors.green),
    Category('Vehicles', Icons.directions_car, Colors.blue),
    Category('Fantasy', Icons.auto_fix_high, Colors.purple),
  ];

  BannerAd? _bannerAd;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111'),
      size: AdSize.fullBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (_, __) => _bannerReady = false,
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎨 Coloring World', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () async {
                      if (!_isPremium) {
                        await _showInterstitial();
                      }
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TemplateScreen(category: cat)),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cat.color, cat.color.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cat.icon, size: 60, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(cat.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_bannerReady && _bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Future<void> _showInterstitial() async {
    // Placeholder wiring: actual load/show depends on your AdMob unit ID
  }
}

class Category {
  final String name;
  final IconData icon;
  final Color color;
  Category(this.name, this.icon, this.color);
}

class TemplateScreen extends StatelessWidget {
  final Category category;
  const TemplateScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final templates = _getTemplates(category.name);
    final visibleTemplates = _isPremium
        ? templates
        : templates.take(_freeTemplateLimit).toList();
    final premiumStart = _freeTemplateLimit;
    return Scaffold(
      appBar: AppBar(
        title: Text('${category.name} Templates'),
        backgroundColor: category.color,
        actions: [
          if (!_isPremium)
            IconButton(
              icon: const Text('👑', style: TextStyle(fontSize: 20)),
              onPressed: () => _showPremiumDialog(context),
            )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: visibleTemplates.length + (_isPremium ? 0 : (templates.length > premiumStart ? 1 : 0)),
        itemBuilder: (context, index) {
          if (!_isPremium && index == visibleTemplates.length) {
            return _PremiumUpgradeCard(onTap: () => _showPremiumDialog(context));
          }
          final tpl = visibleTemplates[index];
          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ColoringScreen(
                    template: tpl,
                    categoryName: category.name,
                  )),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: const Size(double.infinity, double.infinity),
                        painter: TemplatePreviewPainter(tpl),
                      ),
                    ),
                    Text(tpl.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Template> _getTemplates(String category) {
    switch (category) {
      case 'Animals':
        return [
          Template('Cat', _drawCat), Template('Dog', _drawDog), Template('Fish', _drawFish),
          Template('Bird', _drawBird), Template('Rabbit', _drawRabbit), Template('Butterfly', _drawButterfly),
          Template('Elephant', _drawElephant), Template('Giraffe', _drawGiraffe), Template('Panda', _drawPanda),
          Template('Tiger', _drawTiger), Template('Lion', _drawLion), Template('Fox', _drawFox),
          Template('Bear', _drawBear), Template('Horse', _drawHorse), Template('Deer', _drawDeer),
          Template('Frog', _drawFrog), Template('Turtle', _drawTurtle), Template('Duck', _drawDuck),
          Template('Penguin', _drawPenguin), Template('Owl', _drawOwl), Template('Hedgehog', _drawHedgehog),
          Template('Koala', _drawKoala), Template('Pig', _drawPig), Template('Cow', _drawCow),
          Template('Sheep', _drawSheep),
        ];
      case 'Nature':
        return [
          Template('Tree', _drawTree), Template('Flower', _drawFlower), Template('Mountain', _drawMountain),
          Template('Sunset', _drawSunset), Template('House', _drawHouse), Template('Boat', _drawBoat),
          Template('Rainbow', _drawRainbow), Template('River', _drawRiver), Template('Volcano', _drawVolcano),
          Template('Cloud', _drawCloud), Template('Leaf', _drawLeaf), Template('Cactus', _drawCactus),
          Template('Sun', _drawSun), Template('Moon', _drawMoon), Template('Star', _drawStar),
          Template('Palm', _drawPalm), Template('Mushroom', _drawMushroom), Template('Bush', _drawBush),
          Template('Bridge', _drawBridge), Template('Windmill', _drawWindmill), Template('Lighthouse', _drawLighthouse),
          Template('Igloo', _drawIgloo), Template('Waterfall', _drawWaterfall), Template('Cave', _drawCave),
          Template('Daisy', _drawDaisy),
        ];
      case 'Vehicles':
        return [
          Template('Car', _drawCar), Template('Bus', _drawBus), Template('Rocket', _drawRocket),
          Template('Train', _drawTrain), Template('Bike', _drawBike), Template('Plane', _drawPlane),
          Template('Helicopter', _drawHelicopter), Template('Ship', _drawShip), Template('Tractor', _drawTractor),
          Template('Motorcycle', _drawMotorcycle), Template('Submarine', _drawSubmarine), Template('HotAirBalloon', _drawHotAirBalloon),
          Template('Van', _drawVan), Template('Taxi', _drawTaxi), Template('FireTruck', _drawFireTruck),
          Template('Ambulance', _drawAmbulance), Template('Crane', _drawCrane), Template('Bulldozer', _drawBulldozer),
          Template('Boat', _drawBoat), Template('Skateboard', _drawSkateboard), Template('RollerSkate', _drawRollerSkate),
          Template('Scooter', _drawScooter), Template('Tram', _drawTram), Template('Sailboat', _drawSailboat),
          Template('Jet', _drawJet),
        ];
      case 'Fantasy':
        return [
          Template('Castle', _drawCastle), Template('Dragon', _drawDragon), Template('Unicorn', _drawUnicorn),
          Template('Star', _drawStar), Template('Crown', _drawCrown), Template('Treasure', _drawTreasure),
          Template('Wand', _drawWand), Template('Fairy', _drawFairy), Template('Mermaid', _drawMermaid),
          Template('Wizard', _drawWizard), Template('Phoenix', _drawPhoenix), Template('RainbowBridge', _drawRainbowBridge),
          Template('Princess', _drawPrincess), Template('Knight', _drawKnight), Template('FairyHouse', _drawFairyHouse),
          Template('MagicTree', _drawMagicTree), Template('Crystal', _drawCrystal), Template('DragonEgg', _drawDragonEgg),
          Template('Potion', _drawPotion), Template('SpellBook', _drawSpellBook), Template('Wings', _drawWings),
          Template('MythicCat', _drawMythicCat), Template('Ghost', _drawGhost), Template('Zombie', _drawZombie),
          Template('Robot', _drawRobot),
        ];
      default:
        return [Template('Blank', _drawBlank)];
    }
  }

  void _drawCat(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    final path = Path();
    path.moveTo(w * 0.32, h * 0.2); path.lineTo(w * 0.38, h * 0.08); path.lineTo(w * 0.45, h * 0.22);
    path.moveTo(w * 0.68, h * 0.2); path.lineTo(w * 0.62, h * 0.08); path.lineTo(w * 0.55, h * 0.22);
    canvas.drawPath(path, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.35), paint);
    final tail = Path()..moveTo(w * 0.7, h * 0.6)..quadraticBezierTo(w * 0.9, h * 0.4, w * 0.85, h * 0.25);
    canvas.drawPath(tail, paint);
    canvas.drawCircle(Offset(w * 0.43, h * 0.32), w * 0.03, paint);
    canvas.drawCircle(Offset(w * 0.57, h * 0.32), w * 0.03, paint);
  }

  void _drawDog(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.2, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.18, h * 0.25), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.62, h * 0.25, w * 0.18, h * 0.25), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.5, w * 0.4, h * 0.3), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.04, paint);
  }

  void _drawFish(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.5, h * 0.5), paint);
    final tail = Path()..moveTo(w * 0.7, h * 0.5)..lineTo(w * 0.95, h * 0.3)..lineTo(w * 0.95, h * 0.7)..close();
    canvas.drawPath(tail, paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.4), w * 0.04, paint);
  }

  void _drawBird(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.15, paint);
    final wing = Path()..moveTo(w * 0.4, h * 0.4)..quadraticBezierTo(w * 0.7, h * 0.2, w * 0.9, h * 0.4);
    canvas.drawPath(wing, paint);
    final beak = Path()..moveTo(w * 0.6, h * 0.4)..lineTo(w * 0.75, h * 0.38)..lineTo(w * 0.6, h * 0.36)..close();
    canvas.drawPath(beak, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.5, h * 0.8), paint);
  }

  void _drawRabbit(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.2, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.05, w * 0.1, h * 0.3), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.55, h * 0.05, w * 0.1, h * 0.3), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawButterfly(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.08, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.5, h * 0.75), paint);
    final left = Path()..moveTo(w * 0.5, h * 0.4)..quadraticBezierTo(w * 0.15, h * 0.2, w * 0.2, h * 0.5)..quadraticBezierTo(w * 0.4, h * 0.5, w * 0.5, h * 0.4);
    final right = Path()..moveTo(w * 0.5, h * 0.4)..quadraticBezierTo(w * 0.85, h * 0.2, w * 0.8, h * 0.5)..quadraticBezierTo(w * 0.6, h * 0.5, w * 0.5, h * 0.4);
    canvas.drawPath(left, paint); canvas.drawPath(right, paint);
  }

  void _drawTree(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h * 0.45), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.25, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.15, paint);
  }

  void _drawFlower(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final cx = w * 0.5, cy = h * 0.4;
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72) * pi / 180;
      final px = cx + cos(angle) * w * 0.18;
      final py = cy + sin(angle) * w * 0.18;
      canvas.drawCircle(Offset(px, py), w * 0.1, paint);
    }
    canvas.drawCircle(Offset(cx, cy), w * 0.08, paint);
    canvas.drawLine(Offset(cx, cy + w * 0.1), Offset(cx, h * 0.85), paint);
  }

  void _drawMountain(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.1, h * 0.8)..lineTo(w * 0.5, h * 0.2)..lineTo(w * 0.9, h * 0.8)..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), paint);
  }

  void _drawSunset(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.18, paint);
    final path = Path()..moveTo(0, h * 0.7)..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.5, h * 0.7)..quadraticBezierTo(w * 0.7, h * 0.55, w, h * 0.7)..lineTo(w, h)..lineTo(0, h)..close();
    canvas.drawPath(path, paint);
  }

  void _drawHouse(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.4, w * 0.5, h * 0.4), paint);
    final roof = Path()..moveTo(w * 0.2, h * 0.4)..lineTo(w * 0.5, h * 0.15)..lineTo(w * 0.8, h * 0.4)..close();
    canvas.drawPath(roof, paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.55, w * 0.15, h * 0.25), paint);
  }

  void _drawBoat(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final hull = Path()..moveTo(w * 0.2, h * 0.6)..lineTo(w * 0.8, h * 0.6)..lineTo(w * 0.75, h * 0.8)..lineTo(w * 0.25, h * 0.8)..close();
    canvas.drawPath(hull, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.5, h * 0.25), paint);
    final sail = Path()..moveTo(w * 0.5, h * 0.25)..lineTo(w * 0.75, h * 0.5)..lineTo(w * 0.5, h * 0.5)..close();
    canvas.drawPath(sail, paint);
  }

  void _drawCar(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.45, w * 0.7, h * 0.25), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.25, w * 0.4, h * 0.25), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.08, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.08, paint);
  }

  void _drawBus(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.3, w * 0.8, h * 0.4), paint);
    canvas.drawCircle(Offset(w * 0.25, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.72), w * 0.07, paint);
  }

  void _drawRocket(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final body = Path()..moveTo(w * 0.5, h * 0.1)..quadraticBezierTo(w * 0.7, h * 0.4, w * 0.6, h * 0.7)..lineTo(w * 0.4, h * 0.7)..quadraticBezierTo(w * 0.3, h * 0.4, w * 0.5, h * 0.1);
    canvas.drawPath(body, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.08, paint);
  }

  void _drawTrain(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.4, w * 0.5, h * 0.3), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.5, w * 0.25, h * 0.2), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.07, paint);
  }

  void _drawBike(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.65), w * 0.15, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.65), w * 0.15, paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.65), Offset(w * 0.7, h * 0.65), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.65), paint);
  }

  void _drawPlane(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.6, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h * 0.15), paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.5), Offset(w * 0.3, h * 0.7), paint);
    canvas.drawLine(Offset(w * 0.7, h * 0.5), Offset(w * 0.7, h * 0.7), paint);
  }

  void _drawCastle(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.35, w * 0.5, h * 0.45), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.1, h * 0.15), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.2, w * 0.1, h * 0.15), paint);
  }

  void _drawDragon(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    final body = Path()..moveTo(w * 0.5, h * 0.5)..quadraticBezierTo(w * 0.8, h * 0.6, w * 0.9, h * 0.8)..quadraticBezierTo(w * 0.7, h * 0.7, w * 0.5, h * 0.6);
    canvas.drawPath(body, paint);
    canvas.drawCircle(Offset(w * 0.43, h * 0.32), w * 0.03, paint);
    canvas.drawCircle(Offset(w * 0.57, h * 0.32), w * 0.03, paint);
  }

  void _drawUnicorn(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.18, paint);
    canvas.drawLine(Offset(w * 0.55, h * 0.22), Offset(w * 0.65, h * 0.05), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawStar(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 144 - 90) * pi / 180;
      final x = w * 0.5 + cos(angle) * w * 0.3;
      final y = h * 0.5 + sin(angle) * w * 0.3;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCrown(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.2, h * 0.7)..lineTo(w * 0.2, h * 0.3)..lineTo(w * 0.35, h * 0.5)..lineTo(w * 0.5, h * 0.2)..lineTo(w * 0.65, h * 0.5)..lineTo(w * 0.8, h * 0.3)..lineTo(w * 0.8, h * 0.7)..close();
    canvas.drawPath(path, paint);
  }

  void _drawTreasure(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.25, h * 0.35, w * 0.5, h * 0.35), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.12, paint);
    canvas.drawLine(Offset(w * 0.15, h * 0.45), Offset(w * 0.0, h * 0.4), paint);
    canvas.drawLine(Offset(w * 0.85, h * 0.45), Offset(w, h * 0.4), paint);
  }

  void _drawElephant(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.2, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.35, w * 0.15, h * 0.15), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.65, h * 0.35, w * 0.15, h * 0.15), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.5, h * 0.85), paint);
  }

  void _drawGiraffe(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.12, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.37), Offset(w * 0.5, h * 0.7), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.3, h * 0.55), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.7, h * 0.5), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.35, h * 0.85), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.65, h * 0.85), paint);
  }

  void _drawPanda(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.3), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.3), w * 0.05, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawTiger(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.2, paint);
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;
      path.addOval(Rect.fromCircle(center: Offset(w * 0.5 + cos(angle) * w * 0.2, h * 0.35 + sin(angle) * w * 0.2), radius: w * 0.025));
    }
    canvas.drawPath(path, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawLion(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.25, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawFox(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.18, paint);
    final leftEar = Path()..moveTo(w * 0.32, h * 0.2)..lineTo(w * 0.38, h * 0.05)..lineTo(w * 0.45, h * 0.25);
    final rightEar = Path()..moveTo(w * 0.68, h * 0.2)..lineTo(w * 0.62, h * 0.05)..lineTo(w * 0.55, h * 0.25);
    canvas.drawPath(leftEar, paint);
    canvas.drawPath(rightEar, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawRainbow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    for (int i = 0; i < 5; i++) {
      canvas.drawArc(Rect.fromLTWH(w * 0.1 + i * 4, h * 0.3 + i * 4, w * 0.8 - i * 8, h * 0.5 - i * 8), pi, pi, false, paint);
    }
  }

  void _drawRiver(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(0, h * 0.3)..quadraticBezierTo(w * 0.3, h * 0.5, w * 0.5, h * 0.3)..quadraticBezierTo(w * 0.7, h * 0.1, w, h * 0.3)..lineTo(w, h * 0.6)..quadraticBezierTo(w * 0.7, h * 0.4, w * 0.5, h * 0.6)..quadraticBezierTo(w * 0.3, h * 0.8, 0, h * 0.6)..close();
    canvas.drawPath(path, paint);
  }

  void _drawVolcano(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.2, h * 0.8)..lineTo(w * 0.5, h * 0.2)..lineTo(w * 0.8, h * 0.8)..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.2), w * 0.08, paint);
  }

  void _drawCloud(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.5), w * 0.15, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.2, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.5), w * 0.15, paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.6), Offset(w * 0.7, h * 0.6), paint);
  }

  void _drawLeaf(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.5, h * 0.8)..quadraticBezierTo(w * 0.2, h * 0.5, w * 0.5, h * 0.2)..quadraticBezierTo(w * 0.8, h * 0.5, w * 0.5, h * 0.8);
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h * 0.4), paint);
  }

  void _drawCactus(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.3, w * 0.2, h * 0.5), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.2, h * 0.15), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.5, w * 0.2, h * 0.15), paint);
  }

  void _drawHelicopter(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.4, w * 0.4, h * 0.25), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h * 0.15), paint);
    canvas.drawLine(Offset(w * 0.1, h * 0.15), Offset(w * 0.9, h * 0.15), paint);
  }

  void _drawShip(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final hull = Path()..moveTo(w * 0.15, h * 0.6)..lineTo(w * 0.85, h * 0.6)..lineTo(w * 0.75, h * 0.8)..lineTo(w * 0.25, h * 0.8)..close();
    canvas.drawPath(hull, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.5, h * 0.2), paint);
    final sail = Path()..moveTo(w * 0.5, h * 0.2)..lineTo(w * 0.7, h * 0.45)..lineTo(w * 0.5, h * 0.45)..close();
    canvas.drawPath(sail, paint);
  }

  void _drawTractor(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.5, w * 0.5, h * 0.2), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.55, w * 0.15, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.72), w * 0.08, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.1, paint);
  }

  void _drawMotorcycle(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.65), w * 0.12, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.65), w * 0.12, paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.65), Offset(w * 0.7, h * 0.65), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.45), Offset(w * 0.5, h * 0.65), paint);
  }

  void _drawSubmarine(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.6, h * 0.3), paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.55), w * 0.08, paint);
    canvas.drawLine(Offset(w * 0.6, h * 0.55), Offset(w * 0.8, h * 0.45), paint);
  }

  void _drawHotAirBalloon(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.25, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.5, h * 0.75), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.75, w * 0.2, h * 0.1), paint);
  }

  void _drawWand(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.3, h * 0.8), Offset(w * 0.6, h * 0.2), paint);
    
  }

  void _drawFairy(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.15, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.3, h * 0.3), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.7, h * 0.1), paint);
  }

  void _drawMermaid(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.15, paint);
    final body = Path()..moveTo(w * 0.5, h * 0.45)..quadraticBezierTo(w * 0.3, h * 0.6, w * 0.4, h * 0.8)..lineTo(w * 0.6, h * 0.8)..quadraticBezierTo(w * 0.7, h * 0.6, w * 0.5, h * 0.45);
    canvas.drawPath(body, paint);
  }

  void _drawWizard(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.15, paint);
    final hat = Path()..moveTo(w * 0.35, h * 0.35)..lineTo(w * 0.5, h * 0.05)..lineTo(w * 0.65, h * 0.35)..close();
    canvas.drawPath(hat, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.85), paint);
  }

  void _drawPhoenix(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.15, paint);
    final wing = Path()..moveTo(w * 0.4, h * 0.4)..quadraticBezierTo(w * 0.1, h * 0.2, w * 0.2, h * 0.5)..quadraticBezierTo(w * 0.4, h * 0.5, w * 0.5, h * 0.4);
    canvas.drawPath(wing, paint);
    final tail = Path()..moveTo(w * 0.5, h * 0.55)..quadraticBezierTo(w * 0.8, h * 0.7, w * 0.9, h * 0.9)..quadraticBezierTo(w * 0.7, h * 0.8, w * 0.5, h * 0.6);
    canvas.drawPath(tail, paint);
  }

  void _drawRainbowBridge(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.1, h * 0.8)..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.9, h * 0.8);
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(w * 0.1, h * 0.8), Offset(w * 0.9, h * 0.8), paint);
  }

  void _drawBlank(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), paint);
    final text = TextPainter(text: const TextSpan(text: 'Blank Canvas', style: TextStyle(fontSize: 20, color: Colors.grey)), textDirection: TextDirection.ltr);
    text.layout();
    text.paint(canvas, Offset((size.width - text.width) / 2, (size.height - text.height) / 2));
  }
}

class TemplatePreviewPainter extends CustomPainter {
  final Template template;
  const TemplatePreviewPainter(this.template);
  @override
  void paint(Canvas canvas, Size size) => template.draw(canvas, size);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Template {
  final String name;
  final void Function(Canvas, Size) draw;
  const Template(this.name, this.draw);
}

class ColoringScreen extends StatefulWidget {
  final Template template;
  final String categoryName;
  const ColoringScreen({super.key, required this.template, required this.categoryName});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  Color selectedColor = Colors.red;
  double brushSize = 8;
  final List<Color> colors = const [
    Colors.red, Colors.blue, Colors.green, Colors.yellow,
    Colors.orange, Colors.purple, Colors.pink, Colors.brown,
    Colors.black, Colors.white, Colors.grey, Colors.teal,
  ];

  final List<Map<String, dynamic>> strokes = [];
  final List<Offset> currentStroke = [];
  DateTime? startTime;
  bool finished = false;
  int score = 0;
  int stars = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _sparkleVisible = false;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playSound(String path) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$path'));
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  Future<void> _selectColor(Color color) async {
    final names = <Color, String>{
      Colors.red: 'red', Colors.blue: 'blue', Colors.green: 'green',
      Colors.yellow: 'yellow', Colors.orange: 'orange', Colors.purple: 'purple',
      Colors.pink: 'pink', Colors.brown: 'brown', Colors.black: 'black',
      Colors.white: 'white', Colors.grey: 'grey', Colors.teal: 'teal',
    };
    setState(() {
      selectedColor = color;
      _sparkleVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _sparkleVisible = false);
    });
    try {
      await _playSound('pop.wav');
      final name = names[color];
      if (name != null) await _playSound('color_$name.wav');
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  Future<void> _finishColoring() async {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime!);
    final timeScore = duration.inSeconds < 30 ? 30 : duration.inSeconds < 60 ? 20 : 10;
    score = timeScore + 30;
    setState(() => finished = true);
    final prefs = await SharedPreferences.getInstance();
    final key = 'leaderboard_${widget.categoryName}_${widget.template.name}';
    final existing = prefs.getStringList(key) ?? [];
    existing.add('$score|${DateTime.now().toIso8601String()}');
    await prefs.setStringList(key, existing);
    stars = score >= 80 ? 3 : score >= 50 ? 2 : 1;
    try {
      await _playSound('great_job.wav');
      Future.delayed(const Duration(milliseconds: 600), () async {
        await _playSound('excellent.wav');
      });
      Future.delayed(const Duration(milliseconds: 1200), () async {
        await _playSound('amazing.wav');
      });
      Future.delayed(const Duration(milliseconds: 1800), () async {
        await _playSound('congratulations.wav');
      });
    } catch (e) {
      debugPrint('Sound error: $e');
    }
    if (!mounted) return;
    await _showRewardedOnFinish(context);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResultDialog(
        score: score,
        stars: stars,
        template: widget.template.name,
        categoryName: widget.categoryName,
        usedColors: const [Colors.red, Colors.blue],
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!finished)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.black87),
              onPressed: () {
                setState(() {
                  if (strokes.isNotEmpty) strokes.removeLast();
                });
              },
            ),
          if (!finished)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() => strokes.clear());
              },
            ),
          if (!finished)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: _finishColoring,
            )
        ],
      ),
      body: finished
          ? Center(child: Text('Score: $score', style: const TextStyle(fontSize: 32)))
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onPanStart: (details) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          setState(() {
                            currentStroke.clear();
                            currentStroke.add(details.localPosition);
                          });
                        },
                        onPanUpdate: (details) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          setState(() {
                            currentStroke.add(details.localPosition);
                          });
                        },
                        onPanEnd: (details) {
                          setState(() {
                            strokes.add({
                              'points': List<Offset>.from(currentStroke),
                              'color': selectedColor,
                              'width': brushSize,
                            });
                            currentStroke.clear();
                          });
                        },
                        child: CustomPaint(
                          painter: DrawingPainter(widget.template, strokes, currentStroke, selectedColor, brushSize),
                          child: Container(),
                        ),
                      ),
                    ),
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 8)],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: colors.map((color) {
                              return GestureDetector(
                                onTap: () => _selectColor(color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColor == color ? Colors.black : Colors.grey.shade300,
                                      width: selectedColor == color ? 3 : 1,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          Slider(
                            value: brushSize,
                            min: 4,
                            max: 24,
                            divisions: 10,
                            label: '${brushSize.round()}',
                            onChanged: (v) => setState(() => brushSize = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_sparkleVisible)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: SparkleOverlay(),
                    ),
                  ),
              ],
            ),
    );
  }
}

class SparkleOverlay extends StatelessWidget {
  const SparkleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('✨', style: TextStyle(fontSize: 72)),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final Template template;
  final List<Map<String, dynamic>> strokes;
  final List<Offset> currentStroke;
  final Color selectedColor;
  final double brushSize;

  DrawingPainter(this.template, this.strokes, this.currentStroke, this.selectedColor, this.brushSize);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    final recorder = ui.PictureRecorder();
    final tempCanvas = Canvas(recorder);
    template.draw(tempCanvas, size);
    final picture = recorder.endRecording();
    canvas.drawPicture(picture);

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke['points'], stroke['color'], stroke['width']);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, selectedColor, brushSize);
    }

    canvas.drawCircle(Offset(24, size.height - 24), 18, Paint()..color = selectedColor);
    canvas.drawCircle(Offset(24, size.height - 24), 18, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ResultDialog extends StatelessWidget {
  final int score;
  final int stars;
  final String template;
  final String categoryName;
  final List<Color> usedColors;
  final Duration duration;
  const ResultDialog({
    super.key,
    required this.score,
    required this.stars,
    required this.template,
    required this.categoryName,
    required this.usedColors,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 Congratulations!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Template: $template', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Icon(Icons.star, color: i < stars ? Colors.amber : Colors.grey, size: 36);
            }),
          ),
          const SizedBox(height: 12),
          Text('Score: $score/100',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.purple)),
          const SizedBox(height: 12),
          Text('Time: ${duration.inMinutes}m ${duration.inSeconds % 60}s'),
          const SizedBox(height: 8),
          const Text('🌟 Amazing work!'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                (route) => false),
          child: const Text('Leaderboard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Map<String, List<Map<String, dynamic>>> _leaderboard = {};

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, List<Map<String, dynamic>>>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('leaderboard_')) {
        final entries = prefs.getStringList(key) ?? [];
        final parsed = entries.map((e) {
          final parts = e.split('|');
          return {'score': int.parse(parts[0]), 'date': parts[1]};
        }).toList();
        parsed.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        data[key.substring(12)] = parsed.take(10).toList();
      }
    }
    setState(() => _leaderboard = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        backgroundColor: Colors.amber,
      ),
      body: _leaderboard.isEmpty
          ? const Center(child: Text('No scores yet. Start coloring!'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _leaderboard.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(entry.key.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    children: entry.value.map((scoreData) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Text('${scoreData['score']}'),
                        ),
                        title: Text('Score: ${scoreData['score']}/100'),
                        subtitle: Text(scoreData['date'].toString().split('T').first),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

  // Animals extras
  void _drawBear(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.2, paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.32), w * 0.08, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.32), w * 0.08, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.32), w * 0.05, paint);
  }

  void _drawHorse(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.25, w * 0.3, h * 0.25), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.8), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.3, h * 0.65), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.65), Offset(w * 0.7, h * 0.6), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.35, h * 0.9), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.65, h * 0.9), paint);
  }

  void _drawDeer(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.12, paint);
    canvas.drawLine(Offset(w * 0.45, h * 0.22), Offset(w * 0.4, h * 0.08), paint);
    canvas.drawLine(Offset(w * 0.55, h * 0.22), Offset(w * 0.6, h * 0.08), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.42), Offset(w * 0.5, h * 0.75), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.55, w * 0.3, h * 0.25), paint);
  }

  void _drawFrog(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.25, h * 0.35, w * 0.5, h * 0.3), paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.3), w * 0.08, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.3), w * 0.08, paint);
    canvas.drawLine(Offset(w * 0.35, h * 0.65), Offset(w * 0.3, h * 0.85), paint);
    canvas.drawLine(Offset(w * 0.65, h * 0.65), Offset(w * 0.7, h * 0.85), paint);
  }

  void _drawTurtle(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.6, h * 0.35), paint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.45), w * 0.1, paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.65), Offset(w * 0.25, h * 0.85), paint);
    canvas.drawLine(Offset(w * 0.7, h * 0.65), Offset(w * 0.75, h * 0.85), paint);
  }

  void _drawDuck(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.35, h * 0.35), w * 0.15, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.25), paint);
    canvas.drawLine(Offset(w * 0.2, h * 0.4), Offset(w * 0.1, h * 0.35), paint);
    canvas.drawLine(Offset(w * 0.7, h * 0.55), Offset(w * 0.85, h * 0.5), paint);
  }

  void _drawPenguin(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.4, h * 0.5), paint);
    canvas.drawCircle(Offset(w * 0.38, h * 0.28), w * 0.04, paint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.28), w * 0.04, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.4, w * 0.3, h * 0.25), paint);
  }

  void _drawOwl(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.3), w * 0.06, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.3), w * 0.06, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.3, h * 0.3), paint);
  }

  void _drawHedgehog(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.5, w * 0.4, h * 0.3), paint);
    for (int i = 0; i < 8; i++) {
      canvas.drawLine(Offset(w * 0.35 + i * 8, h * 0.5), Offset(w * 0.35 + i * 8, h * 0.3), paint);
    }
    canvas.drawCircle(Offset(w * 0.75, h * 0.6), w * 0.06, paint);
  }

  void _drawKoala(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.28), w * 0.08, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.28), w * 0.08, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawPig(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.2, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.42, w * 0.3, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.38), w * 0.04, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.38), w * 0.04, paint);
  }

  void _drawCow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.6, h * 0.4), paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.35), w * 0.06, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.35), w * 0.06, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.4, h * 0.45, w * 0.2, h * 0.15), paint);
  }

  void _drawSheep(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.25, h * 0.35, w * 0.5, h * 0.35), paint);
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawCircle(Offset(w * 0.3 + i * 10, h * 0.4 + j * 10), w * 0.04, paint);
      }
    }
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.6, w * 0.3, h * 0.25), paint);
  }

  // Nature extras
  void _drawSun(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.15, paint);
    for (int i = 0; i < 8; i++) {
      final angle = i * 45 * pi / 180;
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5 + cos(angle) * w * 0.25, h * 0.5 + sin(angle) * h * 0.25), paint);
    }
  }

  void _drawMoon(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawArc(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), 0, pi, false, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.35), w * 0.12, Paint()..color = Colors.white..blendMode = BlendMode.clear);
  }

  void _drawPalm(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h * 0.4), paint);
    for (int i = 0; i < 6; i++) {
      final angle = -30 + i * 15;
      final rad = angle * pi / 180;
      canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5 + cos(rad) * w * 0.2, h * 0.4 + sin(rad) * h * 0.2), paint);
    }
  }

  void _drawMushroom(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawArc(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.4), pi, pi, false, paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.6, w * 0.2, h * 0.2), paint);
  }

  void _drawBush(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.6), w * 0.15, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.18, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.6), w * 0.15, paint);
  }

  void _drawBridge(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.1, h * 0.6)..quadraticBezierTo(w * 0.5, h * 0.2, w * 0.9, h * 0.6);
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(w * 0.1, h * 0.6), Offset(w * 0.9, h * 0.6), paint);
  }

  void _drawWindmill(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.3, w * 0.1, h * 0.5), paint);
    final path = Path()..moveTo(w * 0.5, h * 0.3)..lineTo(w * 0.3, h * 0.1)..lineTo(w * 0.7, h * 0.1)..close();
    canvas.drawPath(path, paint);
  }

  void _drawLighthouse(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.2, w * 0.2, h * 0.6), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.08, paint);
  }

  void _drawIgloo(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.2, h * 0.8)..lineTo(w * 0.2, h * 0.4)..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.8, h * 0.4)..lineTo(w * 0.8, h * 0.8)..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.5, w * 0.2, h * 0.3), paint);
  }

  void _drawWaterfall(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.5, h * 0.1), Offset(w * 0.5, h * 0.8), paint);
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(Offset(w * 0.45 + i * 4, h * 0.3), Offset(w * 0.55 + i * 4, h * 0.35), paint);
    }
  }

  void _drawCave(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.2, h * 0.8)..quadraticBezierTo(w * 0.2, h * 0.3, w * 0.5, h * 0.3)..quadraticBezierTo(w * 0.8, h * 0.3, w * 0.8, h * 0.8)..close();
    canvas.drawPath(path, paint);
  }

  void _drawDaisy(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h * 0.4), paint);
    for (int i = 0; i < 8; i++) {
      final angle = i * 45 * pi / 180;
      canvas.drawOval(Rect.fromCircle(center: Offset(w * 0.5 + cos(angle) * w * 0.12, h * 0.4 + sin(angle) * h * 0.12), radius: w * 0.06), paint);
    }
  }

  // Vehicles extras
  void _drawVan(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.4, w * 0.7, h * 0.3), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.25, w * 0.25, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.07, paint);
  }

  void _drawTaxi(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.4, w * 0.7, h * 0.3), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.25, w * 0.5, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.07, paint);
  }

  void _drawFireTruck(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.35, w * 0.7, h * 0.35), paint);
    canvas.drawLine(Offset(w * 0.6, h * 0.35), Offset(w * 0.6, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.07, paint);
  }

  void _drawAmbulance(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.4, w * 0.7, h * 0.3), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.25, w * 0.25, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.72), w * 0.07, paint);
  }

  void _drawCrane(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.2, h * 0.8), Offset(w * 0.2, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.2, h * 0.2), Offset(w * 0.8, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.8, h * 0.2), Offset(w * 0.8, h * 0.4), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.7, w * 0.5, h * 0.1), paint);
  }

  void _drawBulldozer(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.5, w * 0.5, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.65, h * 0.55), Offset(w * 0.85, h * 0.45), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.72), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.55, h * 0.72), w * 0.07, paint);
  }

  void _drawSkateboard(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.55, w * 0.6, h * 0.1), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.6), w * 0.06, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.6), w * 0.06, paint);
  }

  void _drawRollerSkate(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.4, w * 0.3, h * 0.2), paint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.65), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.65), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.65), w * 0.05, paint);
  }

  void _drawScooter(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.3, h * 0.7), Offset(w * 0.5, h * 0.3), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.3), Offset(w * 0.7, h * 0.4), paint);
    canvas.drawCircle(Offset(w * 0.3, h * 0.7), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.7), w * 0.07, paint);
  }

  void _drawTram(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.4, w * 0.8, h * 0.25), paint);
    canvas.drawLine(Offset(w * 0.3, h * 0.4), Offset(w * 0.3, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h * 0.15), paint);
    canvas.drawCircle(Offset(w * 0.25, h * 0.67), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.67), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.67), w * 0.05, paint);
  }

  void _drawSailboat(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final hull = Path()..moveTo(w * 0.2, h * 0.65)..lineTo(w * 0.8, h * 0.65)..lineTo(w * 0.7, h * 0.85)..lineTo(w * 0.3, h * 0.85)..close();
    canvas.drawPath(hull, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.65), Offset(w * 0.5, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.7, h * 0.55), paint);
  }

  void _drawJet(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.4, w * 0.4, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h * 0.1), paint);
    canvas.drawLine(Offset(w * 0.2, h * 0.45), Offset(w * 0.05, h * 0.35), paint);
    canvas.drawLine(Offset(w * 0.8, h * 0.45), Offset(w * 0.95, h * 0.35), paint);
  }

  // Fantasy extras
  void _drawPrincess(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.15, paint);
    final path = Path()..moveTo(w * 0.35, h * 0.3)..lineTo(w * 0.3, h * 0.05)..lineTo(w * 0.7, h * 0.05)..lineTo(w * 0.65, h * 0.3)..close();
    canvas.drawPath(path, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.45, w * 0.3, h * 0.35), paint);
  }

  void _drawKnight(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.4, h * 0.35), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.55, w * 0.3, h * 0.3), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.5, h * 0.85), paint);
    canvas.drawLine(Offset(w * 0.35, h * 0.7), Offset(w * 0.65, h * 0.7), paint);
  }

  void _drawFairyHouse(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.6, h * 0.4), paint);
    final path = Path()..moveTo(w * 0.2, h * 0.4)..lineTo(w * 0.5, h * 0.15)..lineTo(w * 0.8, h * 0.4)..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.7), w * 0.08, paint);
  }

  void _drawMagicTree(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h * 0.4), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.25, paint);
    for (int i = 0; i < 5; i++) {
      final angle = i * 72 * pi / 180;
      canvas.drawLine(Offset(w * 0.5, h * 0.3), Offset(w * 0.5 + cos(angle) * w * 0.2, h * 0.3 + sin(angle) * h * 0.2), paint);
    }
  }

  void _drawCrystal(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.5, h * 0.15)..lineTo(w * 0.65, h * 0.4)..lineTo(w * 0.5, h * 0.85)..lineTo(w * 0.35, h * 0.4)..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.15), Offset(w * 0.5, h * 0.85), paint);
  }

  void _drawDragonEgg(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.6), paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.08, paint);
  }

  void _drawPotion(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.15, w * 0.2, h * 0.15), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.3, w * 0.4, h * 0.4), paint);
  }

  void _drawSpellBook(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.5, h * 0.8), paint);
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(Offset(w * 0.25, h * 0.3 + i * 10), Offset(w * 0.45, h * 0.3 + i * 10), paint);
      canvas.drawLine(Offset(w * 0.55, h * 0.3 + i * 10), Offset(w * 0.75, h * 0.3 + i * 10), paint);
    }
  }

  void _drawWings(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.1, paint);
    final left = Path()..moveTo(w * 0.45, h * 0.5)..quadraticBezierTo(w * 0.1, h * 0.2, w * 0.2, h * 0.6)..quadraticBezierTo(w * 0.4, h * 0.55, w * 0.45, h * 0.5);
    final right = Path()..moveTo(w * 0.55, h * 0.5)..quadraticBezierTo(w * 0.9, h * 0.2, w * 0.8, h * 0.6)..quadraticBezierTo(w * 0.6, h * 0.55, w * 0.55, h * 0.5);
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
  }

  void _drawMythicCat(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.18, paint);
    canvas.drawLine(Offset(w * 0.55, h * 0.22), Offset(w * 0.65, h * 0.05), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.55, w * 0.4, h * 0.3), paint);
  }

  void _drawGhost(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    final path = Path()..moveTo(w * 0.3, h * 0.2)..lineTo(w * 0.7, h * 0.2)..lineTo(w * 0.7, h * 0.7)..lineTo(w * 0.6, h * 0.6)..lineTo(w * 0.5, h * 0.7)..lineTo(w * 0.4, h * 0.6)..lineTo(w * 0.3, h * 0.7)..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.35), w * 0.04, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.35), w * 0.04, paint);
  }

  void _drawZombie(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.18, paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.35), paint);
    canvas.drawLine(Offset(w * 0.35, h * 0.35), Offset(w * 0.4, h * 0.4), paint);
    canvas.drawLine(Offset(w * 0.65, h * 0.35), Offset(w * 0.6, h * 0.4), paint);
  }

  void _drawRobot(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.15, w * 0.5, h * 0.35), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.3, h * 0.3), paint);
    canvas.drawCircle(Offset(w * 0.38, h * 0.28), w * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.28), w * 0.05, paint);
    canvas.drawLine(Offset(w * 0.45, h * 0.55), Offset(w * 0.55, h * 0.55), paint);
  }

class _PremiumUpgradeCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumUpgradeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.purple.shade50,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('👑', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text('Unlock Premium',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('300+ templates', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPremiumDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('👑 Premium'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Unlock all 300+ templates and remove ads.'),
          SizedBox(height: 12),
          Text('One-time purchase'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IAP placeholder — connect your product first')),
            );
          },
          child: const Text('Upgrade'),
        ),
      ],
    ),
  );
}

Future<void> _showRewardedOnFinish(BuildContext context) async {
  if (_isPremium) return;
  final product = await _findPremiumProduct();
  if (product != null && context.mounted) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Great Job!'),
        content: const Text('Watch a short video to unlock more templates?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Watch')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rewarded ad placeholder — connect AdMob unit first')),
      );
    }
  }
}

Future<ProductDetails?> _findPremiumProduct() async {
  try {
    final products = await InAppPurchase.instance.queryProductDetails({_premiumProductId});
    return products.productDetails.firstOrNull;
  } catch (_) {
    return null;
  }
}

Future<void> _purchasePremium(ProductDetails product) async {
  final purchaseParam = PurchaseParam(productDetails: product);
  final result = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  if (result == PurchaseStatus.purchased || result == PurchaseStatus.restored) {
    await _setPremiumUnlocked(true);
  }
}
