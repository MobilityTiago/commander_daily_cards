import 'package:commander_deck/screens/navigation/navigation_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import 'advanced_search_screen.dart';
import 'package:provider/provider.dart';
import '../../services/card_service.dart';
import '../../models/cards/mtg_card.dart';
import '../../widgets/app_drawer.dart';
import '../../styles/colors.dart';
import '../../widgets/card_zoom_view.dart';


class CardSearchScreen extends StatefulWidget {
  const CardSearchScreen({super.key});

  @override
  State<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends State<CardSearchScreen> {
  List<MTGCard> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final cardService = context.read<CardService>();
    setState(() {
      _searchResults = cardService.searchCards(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentPage: NavigationScreen.routeSearch),
      appBar: const CommanderAppBar(
        title: 'Search Cards',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Enter card name, oracle text, or any card property',
                  style: TextStyle(
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search cards...',
                          hintStyle: const TextStyle(color: AppColors.white),
                          prefixIcon: const Icon(Icons.search),
                          prefixIconColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.darkGrey,
                        ),
                        style: const TextStyle(color: AppColors.white),
                        onSubmitted: _performSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _performSearch(_searchController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(color: AppColors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AdvancedSearchScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('Advanced Search'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    foregroundColor: AppColors.darkGrey,
                    side: const BorderSide(color: AppColors.darkGrey),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.715, // Card aspect ratio
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final card = _searchResults[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      InkWell(
                        onTap: () {
                          if (card.imageUris?.normal != null) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                pageBuilder: (context, _, __) => CardZoomView(
                                  cards: _searchResults,
                                  initialIndex: index,
                                ),
                                transitionsBuilder: (context, animation, _, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          }
                        },
                        child: card.imageUris?.normal != null
                            ? Image.network(
                                card.imageUris!.normal!,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: AppColors.darkGrey,
                                ),
                              ),
                      ),
                      if (card.gameChanger)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,  // Reduced from 40
                            height: 20, // Reduced from 40
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(2),    // Reduced from 4
                                bottomRight: Radius.circular(8), // Reduced from 16
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'GC',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10, // Added to scale text with container
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}