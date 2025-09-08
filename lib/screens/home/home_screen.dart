import 'package:commander_deck/models/cards/mtg_card.dart';
import 'package:commander_deck/screens/navigation/navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/card_service.dart';
import '../../models/filters/filter_settings.dart';
import '../../widgets/card_suggestion_section.dart';
import 'filter_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bar.dart';


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
      final nonLandFilters = context.read<SpellFilterSettings>();
      final landFilters = context.read<LandFilterSettings>();
      cardService.loadInitialData(nonLandFilters, landFilters);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       drawer: const AppDrawer(currentPage: NavigationScreen.routeDaily),
      appBar: CommanderAppBar(
        title: 'Commander\'s Deck',
        showFilterButton: true,
        showRefreshButton: true,
        onFilterPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FilterScreen(),
            ),
          );
        },
        onRefreshPressed: () async {
          final cardService = context.read<CardService>();
          if (!cardService.isLoading) {
            final nonLandFilters = context.read<SpellFilterSettings>();
            final landFilters = context.read<LandFilterSettings>();
            await cardService.refreshDailyCards(nonLandFilters, landFilters);
          }
        },
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
              final nonLandFilters = context.read<SpellFilterSettings>();
              final landFilters = context.read<LandFilterSettings>();
              await cardService.refreshDailyCards(nonLandFilters, landFilters);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                                    // Header Card
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxWidth/1.5, // Make height equal to width
                          child: Stack(
                            children: [
                              // Background Image
                              Positioned.fill(
                          child: Consumer<CardService>(
                            builder: (context, cardService, child) {
                              final cards = [
                                cardService.dailyRegularCard,
                                cardService.dailyGameChangerCard,
                                cardService.dailyRegularLand,
                                cardService.dailyGameChangerLand,
                              ].whereType<MTGCard>().toList();

                              if (cards.isEmpty) return const SizedBox.shrink();

                              final randomCard = cards[DateTime.now().millisecond % cards.length];
                              
                              return ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.5),
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.darken,
                                child: Image.network(
                                  randomCard.imageUris?.artCrop ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        // Text Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Suggestions for',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat.yMMMMd().format(DateTime.now()),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    const Spacer(), // Push artist credit to bottom
                                    Consumer<CardService>(
                                builder: (context, cardService, child) {
                                  final cards = [
                                    cardService.dailyRegularCard,
                                    cardService.dailyGameChangerCard,
                                    cardService.dailyRegularLand,
                                    cardService.dailyGameChangerLand,
                                  ].whereType<MTGCard>().toList();

                                  if (cards.isEmpty) return const SizedBox.shrink();

                                  final randomCard = cards[DateTime.now().millisecond % cards.length];
                                  
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Illustrated by ${randomCard.artist ?? 'Unknown Artist'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  );
                                },
                              ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Non-Land Cards Section Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Text(
                      'Spells',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),

                // Regular Card Section
                  CardSuggestionSection(
                    card: cardService.dailyRegularCard,
                    accentColor: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  // Game Changer Card Section
                  CardSuggestionSection(
                    card: cardService.dailyGameChangerCard,
                    accentColor: Colors.orange,
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Text(
                      'Lands',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Regular Land Section
                  CardSuggestionSection(
                    card: cardService.dailyRegularLand,
                    accentColor: Colors.green,
                  ),
                  const SizedBox(height: 16),

                  // Game Changer Land Section
                  CardSuggestionSection(
                    card: cardService.dailyGameChangerLand,
                    accentColor: Colors.purple,
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