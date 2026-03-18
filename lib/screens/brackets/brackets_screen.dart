import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cards/card_enums.dart';
import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';
import '../../styles/colors.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/card_zoom_view.dart';
import '../../widgets/mana_symbol_label.dart';

class BracketsScreen extends StatefulWidget {
  const BracketsScreen({super.key});

  @override
  State<BracketsScreen> createState() => _BracketsScreenState();
}

class _BracketsScreenState extends State<BracketsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final Set<MTGColor> _gameChangerColors = {};
  final Set<MTGColor> _bannedColors = {};
  bool _hideConspiracyCards = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MTGCard> _filterByColors(List<MTGCard> cards, Set<MTGColor> selected) {
    if (selected.isEmpty) return cards;
    final targetSymbols = selected.map((c) => c.symbol).toSet();
    return cards.where((card) {
      final identity =
          (card.colorIdentity ?? []).map((c) => c.toUpperCase()).toSet();
      return identity.every((c) => targetSymbols.contains(c));
    }).toList();
  }

  bool _isConspiracy(MTGCard card) {
    final typeLine = card.typeLine?.toLowerCase() ?? '';
    return typeLine.contains('conspiracy');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _BracketsAppBar(tabController: _tabController),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Brackets guide ──────────────────────────────────────
          const Center(
            child: Text('Brackets Guide screen - Coming Soon'),
          ),

          // ── Tab 2: Game Changers ───────────────────────────────────────
          _CardGridTab(
            selectedColors: _gameChangerColors,
            onColorToggled: (color, selected) {
              setState(() {
                selected
                    ? _gameChangerColors.add(color)
                    : _gameChangerColors.remove(color);
              });
            },
            getCards: (cs) =>
                _filterByColors(cs.allGameChangerCards, _gameChangerColors),
          ),

          // ── Tab 3: Banned ──────────────────────────────────────────────
          _CardGridTab(
            selectedColors: _bannedColors,
            onColorToggled: (color, selected) {
              setState(() {
                selected
                    ? _bannedColors.add(color)
                    : _bannedColors.remove(color);
              });
            },
            showConspiracyToggle: true,
            hideConspiracyCards: _hideConspiracyCards,
            onHideConspiracyChanged: (value) {
              setState(() {
                _hideConspiracyCards = value;
              });
            },
            getCards: (cs) {
              var cards = _filterByColors(cs.allBannedCards, _bannedColors);
              if (_hideConspiracyCards) {
                cards = cards.where((card) => !_isConspiracy(card)).toList();
              }
              return cards;
            },
          ),
        ],
      ),
    );
  }
}

/// Custom app bar that includes the shared card-art background plus a [TabBar].
class _BracketsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;

  const _BracketsAppBar({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Brackets',
        style: TextStyle(color: Colors.white),
      ),
      flexibleSpace: const AppBarBackground(),
      bottom: TabBar(
        controller: tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Brackets'),
          Tab(text: 'Game Changers'),
          Tab(text: 'Banned'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

/// Reusable card grid with a commander color identity filter strip on top.
///
/// [getCards] runs inside a [Consumer] so filtering is immediate on state change.
class _CardGridTab extends StatelessWidget {
  final Set<MTGColor> selectedColors;
  final void Function(MTGColor color, bool selected) onColorToggled;
  final List<MTGCard> Function(CardService) getCards;
  final bool showConspiracyToggle;
  final bool hideConspiracyCards;
  final ValueChanged<bool>? onHideConspiracyChanged;

  const _CardGridTab({
    required this.selectedColors,
    required this.onColorToggled,
    required this.getCards,
    this.showConspiracyToggle = false,
    this.hideConspiracyCards = true,
    this.onHideConspiracyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CardService>(
      builder: (context, cardService, _) {
        if (cardService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final cards = getCards(cardService);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Commander color identity filter ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: MTGColor.values.map((color) {
                  return FilterChip(
                    label: ManaSymbolLabel(color: color),
                    selected: selectedColors.contains(color),
                    onSelected: (s) => onColorToggled(color, s),
                  );
                }).toList(),
              ),
            ),
            if (showConspiracyToggle)
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('Hide Conspiracy Cards'),
                subtitle: const Text('Exclude Conspiracy cards from banned list'),
                value: hideConspiracyCards,
                onChanged: onHideConspiracyChanged,
              ),
            const Divider(height: 1),

            // ── Card grid ────────────────────────────────────────────────
            Expanded(
              child: cards.isEmpty
                  ? const Center(
                      child: Text(
                        'No cards match the selected colors.',
                        style: TextStyle(color: AppColors.darkGrey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.715,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
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
                                        pageBuilder: (ctx, _, __) =>
                                            CardZoomView(
                                          cards: cards,
                                          initialIndex: index,
                                        ),
                                        transitionsBuilder:
                                            (ctx, animation, _, child) =>
                                                FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
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
                              if (card.legalities['commander'] == 'banned')
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    width: 26,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'BAN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else if (card.gameChanger)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: AppColors.red,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'GC',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
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
        );
      },
    );
  }
}
