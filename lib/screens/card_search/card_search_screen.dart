import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import 'advanced_search_screen.dart';
import 'package:provider/provider.dart';
import '../../services/card_service.dart';
import '../../models/cards/mtg_card.dart';
import '../../widgets/app_drawer.dart';


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
      drawer: const AppDrawer(currentPage: 'search'),
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
                const Text(
                  'Search for Commander cards',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF5F5F5),  // Changed to light grey
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter card name, oracle text, or any card property',
                  style: TextStyle(
                    color: Color(0xFF2A2A2A),  // Changed to dark grey
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
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                        ),
                        style: const TextStyle(color: Color(0xFFF5F5F5)),
                        onSubmitted: _performSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _performSearch(_searchController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D0000),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(color: Color(0xFFF5F5F5)),
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
                    foregroundColor: const Color(0xFF2A2A2A),
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final card = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: card.imageUris?.artCrop != null
                        ? Image.network(
                            card.imageUris!.artCrop!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image_not_supported),
                     title: Text(
                      card.name,
                      style: const TextStyle(color: Color(0xFF2A2A2A)),  // Changed to dark grey
                    ),
                    subtitle: Text(
                      card.typeLine ?? '',
                      style: const TextStyle(
                        color: Color(0xFF2A2A2A),  // Changed to dark grey
                      ),
                    ),
                    onTap: () {
                      // TODO: Navigate to card details
                    },
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