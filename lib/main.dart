import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/card_service.dart';
import 'models/filter_settings.dart';

void main() {
  runApp(const CommanderDailyCardsApp());
}

class CommanderDailyCardsApp extends StatelessWidget {
  const CommanderDailyCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardService()),
        ChangeNotifierProvider(create: (_) => FilterSettings()),
      ],
      child: MaterialApp(
        title: 'Commander Daily Cards',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}