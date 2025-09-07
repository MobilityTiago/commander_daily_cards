import 'package:commander_deck/screens/navigation/navigation_screen.dart';
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
        home: const NavigationScreen(currentRoute: '/daily'),
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => NavigationScreen(
              currentRoute: settings.name ?? '/daily',
            ),
          );
        },
      ),
    );
  }
}