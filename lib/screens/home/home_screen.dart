import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/card_service.dart';
import '../../models/filters/filter_settings.dart';
import '../../widgets/card_suggestion_section.dart';
import 'filter_screen.dart';
import '../../widgets/app_bar.dart';


class HomeScreen extends StatefulWidget { 
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _suggestionPageController;
  int _suggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _suggestionPageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardService = context.read<CardService>();
      final nonLandFilters = context.read<SpellFilterSettings>();
      final landFilters = context.read<LandFilterSettings>();
      cardService.loadInitialData(nonLandFilters, landFilters);
    });
  }

  @override
  void dispose() {
    _suggestionPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          final dateText = DateFormat.yMMMMd().format(DateTime.now());
          final suggestions = cardService.dailySuggestionCards;
          final selectedAppBarCard = cardService.dailyAppBarCard;
          final selectedIndex = selectedAppBarCard != null
              ? suggestions.indexWhere((c) => c.id == selectedAppBarCard.id)
              : -1;
          final effectiveIndex = selectedIndex >= 0 ? selectedIndex : 0;

          // Keep the page view in sync with the current app bar card selection.
          if (_suggestionIndex != effectiveIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _suggestionIndex = effectiveIndex);
              if (_suggestionPageController.hasClients &&
                  effectiveIndex < (suggestions.isEmpty ? 1 : suggestions.length)) {
                _suggestionPageController.jumpToPage(effectiveIndex);
              }
            });
          }

          final backgroundCard = selectedAppBarCard ??
              (suggestions.isNotEmpty
                  ? suggestions[effectiveIndex.clamp(0, suggestions.length - 1)]
                  : (cardService.dailyRegularCard ??
                      cardService.dailyGameChangerCard ??
                      cardService.dailyRegularLand ??
                      cardService.dailyGameChangerLand));

          return RefreshIndicator(
            onRefresh: () async {
              final nonLandFilters = context.read<SpellFilterSettings>();
              final landFilters = context.read<LandFilterSettings>();
              await cardService.refreshDailyCards(nonLandFilters, landFilters);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: 280,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text("Commander's Deck"),
                  actions: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FilterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.filter_alt),
                    ),
                  ],
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxExtent = 280.0;
                      final statusBar = MediaQuery.of(context).padding.top;
                      final minExtent = kToolbarHeight + statusBar;
                      final t = ((constraints.maxHeight - minExtent) /
                              (maxExtent - minExtent))
                          .clamp(0.0, 1.0);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _suggestionPageController,
                            itemCount: suggestions.isEmpty ? 1 : suggestions.length,
                            onPageChanged: (index) {
                              final suggestionCard = suggestions.isNotEmpty
                                  ? suggestions[index]
                                  : null;

                              if (suggestionCard != null) {
                                cardService.setDailyAppBarCard(suggestionCard);
                              }

                              setState(() {
                                _suggestionIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final suggestionCard = suggestions.isNotEmpty
                                  ? suggestions[index]
                                  : backgroundCard;

                              return AppBarBackground(
                                imageUrl: suggestionCard?.imageUris?.artCrop,
                              );
                            },
                          ),
                          Opacity(
                            opacity: t,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    'Suggestions for $dateText',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Illustrated by ${backgroundCard?.artist ?? 'Unknown Artist'}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}