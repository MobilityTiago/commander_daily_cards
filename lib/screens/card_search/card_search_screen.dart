import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import 'advanced_search_screen.dart';
import 'package:provider/provider.dart';
import '../../services/card_service.dart';
import '../../models/cards/mtg_card.dart';
import '../../styles/colors.dart';
import '../../widgets/card_badges_overlay.dart';
import '../../widgets/flip_animated_image.dart';
import '../../widgets/card_zoom_view.dart';

class CardSearchScreen extends StatefulWidget {
  const CardSearchScreen({super.key});

  @override
  State<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends State<CardSearchScreen> {
  List<MTGCard> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _flippedCardIds = <String>{};
  bool _lockToSelectedCommander = false;
  double _searchControlsVisibility = 1.0;
  CardService? _cardService;
  List<String> _lastCommanderIds = const [];

  static const double _collapseDistance = 180.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextCardService = context.read<CardService>();
    if (!identical(_cardService, nextCardService)) {
      _cardService?.removeListener(_handleCommanderSelectionChanged);
      _cardService = nextCardService;
      _cardService?.addListener(_handleCommanderSelectionChanged);
      _syncCommanderLockFromSelection();
    }
  }

  @override
  void dispose() {
    _cardService?.removeListener(_handleCommanderSelectionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleCommanderSelectionChanged() {
    if (!mounted) return;
    _syncCommanderLockFromSelection(notify: true);
  }

  void _syncCommanderLockFromSelection({bool notify = false}) {
    final cardService = _cardService;
    if (cardService == null) return;

    final commanderIds = cardService.selectedCommanders
        .map((card) => card.id)
        .toList(growable: false);
    if (_sameStringLists(_lastCommanderIds, commanderIds)) {
      return;
    }

    _lastCommanderIds = commanderIds;
    final shouldRefresh =
        _searchController.text.trim().isNotEmpty || _searchResults.isNotEmpty;

    void apply() {
      _lockToSelectedCommander = commanderIds.isNotEmpty;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }

    if (shouldRefresh) {
      _performSearch(_searchController.text);
    }
  }

  bool _sameStringLists(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _matchesSelectedCommanderIdentity(
    MTGCard card,
    List<String> commanderIdentity,
  ) {
    if (commanderIdentity.isEmpty) return true;
    final allowedColors = commanderIdentity.toSet();
    final cardIdentity = card.colorIdentity ?? const <String>[];
    return cardIdentity.every(allowedColors.contains);
  }

  bool _isFlipped(MTGCard card) => _flippedCardIds.contains(card.id);

  void _toggleFlipped(MTGCard card) {
    if (!card.hasDoubleFacedImages) return;
    setState(() {
      if (!_flippedCardIds.add(card.id)) {
        _flippedCardIds.remove(card.id);
      }
    });
  }

  String? _displayImageUrl(MTGCard card) {
    if (!card.hasDoubleFacedImages) {
      return card.mainFaceImageUrl;
    }

    if (_isFlipped(card)) {
      return card.backFaceImageUrl ?? card.mainFaceImageUrl;
    }

    return card.mainFaceImageUrl ?? card.backFaceImageUrl;
  }

  void _performSearch(String query) {
    final cardService = context.read<CardService>();
    final results = cardService.searchCards(query);
    final filteredResults =
        _lockToSelectedCommander && cardService.selectedCommanders.isNotEmpty
            ? results
                .where(
                  (card) => _matchesSelectedCommanderIdentity(
                    card,
                    cardService.selectedCommanderIdentity,
                  ),
                )
                .toList()
            : results;

    setState(() {
      _searchResults = filteredResults;
    });
  }

  void _handleGridScroll(ScrollUpdateNotification notification) {
    final pixels = notification.metrics.pixels;
    if (pixels <= 0) {
      if (_searchControlsVisibility != 1.0) {
        setState(() {
          _searchControlsVisibility = 1.0;
        });
      }
      return;
    }

    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return;

    final next = (_searchControlsVisibility - (delta / _collapseDistance))
        .clamp(0.0, 1.0);
    if ((next - _searchControlsVisibility).abs() < 0.001) return;

    setState(() {
      _searchControlsVisibility = next;
    });
  }

  Widget _buildSearchControls() {
    return Padding(
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
                  backgroundColor:
                      Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.search, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<CardService>(
            builder: (context, cardService, _) {
              final hasCommander = cardService.selectedCommanders.isNotEmpty;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lock to selected commander'),
                subtitle: Text(
                  hasCommander
                      ? cardService.selectedCommanderNames
                      : 'No commander selected on the Daily page',
                ),
                value: _lockToSelectedCommander && hasCommander,
                onChanged: hasCommander
                    ? (selected) {
                        setState(() {
                          _lockToSelectedCommander = selected;
                        });
                        _performSearch(_searchController.text);
                      }
                    : null,
              );
            },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final easedVisibility = Curves.easeOut.transform(_searchControlsVisibility);

    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'Search Cards',
      ),
      body: Column(
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _searchControlsVisibility,
              child: Opacity(
                opacity: easedVisibility,
                child: IgnorePointer(
                  ignoring: _searchControlsVisibility < 0.05,
                  child: _buildSearchControls(),
                ),
              ),
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                _handleGridScroll(notification);
                return false;
              },
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
                  final imageUrl = _displayImageUrl(card);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        InkWell(
                          onTap: () {
                            if (imageUrl != null) {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (context, _, __) => CardZoomView(
                                    cards: _searchResults,
                                    initialIndex: index,
                                  ),
                                  transitionsBuilder:
                                      (context, animation, _, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            }
                          },
                          child: FlipAnimatedImage(
                            imageUrl: imageUrl,
                            isFlipped: _isFlipped(card),
                            fit: BoxFit.cover,
                            placeholder: Image.asset(
                              'assets/images/Magic_card_back.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        CardBadgesOverlay(
                          hasDoubleFacedImages: card.hasDoubleFacedImages,
                          isBanned: card.legalities['commander'] == 'banned',
                          isGameChanger: card.gameChanger,
                          onDoubleFacedTap: () => _toggleFlipped(card),
                          isDoubleFacedFlipped: _isFlipped(card),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
