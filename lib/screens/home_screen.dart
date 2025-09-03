import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/card_service.dart';
import '../models/filter_settings.dart';
import '../widgets/card_suggestion_section.dart';
import 'filter_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardService = context.read<CardService>();
      final filterSettings = context.read<FilterSettings>();
      cardService.loadInitialData(filterSettings);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commander Daily Cards'),
        actions: [
          Consumer<CardService>(
            builder: (context, cardService, child) {
              return IconButton(
                onPressed: cardService.isLoading
                    ? null
                    : () async {
                        final filterSettings = context.read<FilterSettings>();
                        await cardService.refreshDailyCards(filterSettings);
                      },
                icon: const Icon(Icons.refresh),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FilterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Consumer<CardService>(
        builder: (context, cardService, child) {
          if (cardService.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading daily cards...'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final filterSettings = context.read<FilterSettings>();
              await cardService.refreshDailyCards(filterSettings);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Daily Commander Suggestions',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat.yMMMMEEEEd().format(DateTime.now()),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Regular Card Section
                  CardSuggestionSection(
                    title: 'Regular Card',
                    card: cardService.dailyRegularCard,
                    accentColor: Colors.blue,
                  ),
                  const SizedBox(height: 24),

                  // Game Changer Card Section
                  CardSuggestionSection(
                    title: 'Game Changer',
                    card: cardService.dailyGameChangerCard,
                    accentColor: Colors.orange,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}