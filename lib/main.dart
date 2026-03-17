import 'package:commander_deck/screens/acknowledgements/acknowledgements_screen.dart';
import 'package:commander_deck/screens/navigation/navigation_screen.dart';
import 'package:commander_deck/screens/support/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/card_service.dart';
import 'models/filters/filter_settings.dart';

void main() {
  runApp(const CommanderDeckApp());
}

class CommanderDeckApp extends StatelessWidget {
  const CommanderDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardService()),
        ChangeNotifierProvider(create: (_) => SpellFilterSettings()),
        ChangeNotifierProvider(create: (_) => LandFilterSettings()),
      ],
      child: MaterialApp(
        title: 'Commander''s Deck',
        home: const NavigationScreen(initialRoute: NavigationScreen.routeDaily),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case NavigationScreen.routeDaily:
            case NavigationScreen.routeSearch:
            case NavigationScreen.routeLandGuide:
            case NavigationScreen.routeMore:
              return MaterialPageRoute(
                builder: (context) => NavigationScreen(
                  initialRoute: settings.name ?? NavigationScreen.routeDaily,
                ),
              );
            case NavigationScreen.routeSupport:
              return MaterialPageRoute(
                builder: (context) => _NavigationWithOverlay(
                  overlay: const SupportScreen(),
                ),
              );
            case NavigationScreen.routeAcknowledgements:
              return MaterialPageRoute(
                builder: (context) => _NavigationWithOverlay(
                  overlay: const AcknowledgementsScreen(),
                ),
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const NavigationScreen(
                  initialRoute: NavigationScreen.routeDaily,
                ),
              );
          }
        },
      ),
    );
  }
}

class _NavigationWithOverlay extends StatefulWidget {
  final Widget overlay;

  const _NavigationWithOverlay({
    required this.overlay,
  });

  @override
  State<_NavigationWithOverlay> createState() => _NavigationWithOverlayState();
}

class _NavigationWithOverlayState extends State<_NavigationWithOverlay> {
  bool _pushedOverlay = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pushedOverlay) {
      _pushedOverlay = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => widget.overlay),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const NavigationScreen(initialRoute: NavigationScreen.routeMore);
  }
}
