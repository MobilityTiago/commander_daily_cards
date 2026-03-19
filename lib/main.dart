import 'package:commander_deck/screens/acknowledgements/acknowledgements_screen.dart';
import 'package:commander_deck/screens/card_pick/card_pick_screen.dart';
import 'package:commander_deck/screens/navigation/navigation_screen.dart';
import 'package:commander_deck/screens/preferences/user_preferences_screen.dart';
import 'package:commander_deck/screens/support/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/card_service.dart';
import 'services/set_service.dart';
import 'services/symbol_service.dart';
import 'services/user_preferences_service.dart';
import 'models/filters/filter_settings.dart';
import 'styles/colors.dart';

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
        ChangeNotifierProvider(create: (_) => SetService()),
        ChangeNotifierProvider(create: (_) => SymbolService()..loadSymbols()),
        ChangeNotifierProvider(create: (_) => UserPreferencesService()),
        ChangeNotifierProvider(create: (_) => SpellFilterSettings()),
        ChangeNotifierProvider(create: (_) => LandFilterSettings()),
      ],
      child: MaterialApp(
        title: 'Command',
        theme: AppTheme.theme(),
        darkTheme: AppTheme.theme(),
        themeMode: ThemeMode.dark,
        home: const NavigationScreen(initialRoute: NavigationScreen.routeDaily),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case NavigationScreen.routeDaily:
            case NavigationScreen.routeSearch:
            case NavigationScreen.routeLandGuide:
            case NavigationScreen.routeBrackets:
            case NavigationScreen.routeSites:
            case NavigationScreen.routeMore:
              return MaterialPageRoute(
                builder: (context) => NavigationScreen(
                  initialRoute: settings.name ?? NavigationScreen.routeDaily,
                ),
              );
            case NavigationScreen.routeSupport:
              return MaterialPageRoute(
                builder: (context) => const SupportScreen(),
              );
            case NavigationScreen.routeAcknowledgements:
              return MaterialPageRoute(
                builder: (context) => const AcknowledgementsScreen(),
              );
            case NavigationScreen.routeCardPick:
              return MaterialPageRoute(
                builder: (context) => const CardPickScreen(),
              );
            case NavigationScreen.routeUserPreferences:
              return MaterialPageRoute(
                builder: (context) => const UserPreferencesScreen(),
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
