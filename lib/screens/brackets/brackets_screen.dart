import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
          const _BracketsGuideTab(),

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

class _BracketGuideItem {
  final String title;
  final String turns;
  final List<String> expectations;

  const _BracketGuideItem({
    required this.title,
    required this.turns,
    required this.expectations,
  });
}

class _BracketsGuideTab extends StatelessWidget {
  const _BracketsGuideTab();

  static final Uri _articleUrl = Uri.parse(
    'https://magic.wizards.com/en/news/announcements/commander-brackets-beta-update-october-21-2025',
  );

  static const List<_BracketGuideItem> _items = [
    _BracketGuideItem(
      title: 'Bracket 1: Exhibition',
      turns: 'Expected game pace: at least 9 turns before win/loss.',
      expectations: [
        'Theme and expression are prioritized over power.',
        'Rule-zero flexibility is expected for unusual choices.',
        'Win conditions are thematic or intentionally suboptimal.',
      ],
    ),
    _BracketGuideItem(
      title: 'Bracket 2: Core',
      turns: 'Expected game pace: at least 8 turns before win/loss.',
      expectations: [
        'Decks are straightforward and mostly unoptimized.',
        'Wins are incremental, visible, and disruptable.',
        'Social, low-pressure gameplay is emphasized.',
      ],
    ),
    _BracketGuideItem(
      title: 'Bracket 3: Upgraded',
      turns: 'Expected game pace: at least 6 turns before win/loss.',
      expectations: [
        'Higher card quality and stronger synergy.',
        'Game Changers tend to be engines or game-ending effects.',
        'One big turn wins become common from accrued resources.',
      ],
    ),
    _BracketGuideItem(
      title: 'Bracket 4: Optimized',
      turns: 'Expected game pace: at least 4 turns before win/loss.',
      expectations: [
        'Fast, lethal, consistent decks, below dedicated cEDH.',
        'Efficient disruption, tutors, and explosive turns are common.',
        'Game Changers often include fast mana and snowball tools.',
      ],
    ),
    _BracketGuideItem(
      title: 'Bracket 5: cEDH',
      turns: 'Expected game pace: games can end on any turn.',
      expectations: [
        'Metagame-tuned competitive decks and tight play patterns.',
        'Win lines prioritize maximum efficiency and consistency.',
        'Gameplay is high-skill and victory-focused.',
      ],
    ),
  ];

  Future<void> _openArticle(BuildContext context) async {
    final ok =
        await launchUrl(_articleUrl, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open Commander Brackets page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        const Text(
          'Commander Brackets Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Intent and expected game length are the primary signals for bracket alignment.',
          style: TextStyle(color: AppColors.darkGrey),
        ),
        const SizedBox(height: 12),
        ..._items.map(
          (item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.turns,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...item.expectations.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $line'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _openArticle(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Commander Brackets'),
          ),
        ),
      ],
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

  static const Map<String, int> _colorOrder = {
    'W': 0,
    'U': 1,
    'B': 2,
    'R': 3,
    'G': 4,
  };

  List<int> _normalizedColorRanks(MTGCard card) {
    final symbols = (card.colorIdentity ?? [])
        .map((c) => c.toUpperCase())
        .where((c) => _colorOrder.containsKey(c))
        .toSet()
        .toList()
      ..sort((a, b) => _colorOrder[a]!.compareTo(_colorOrder[b]!));

    return symbols.map((s) => _colorOrder[s]!).toList(growable: false);
  }

  int _compareNormalizedColors(List<int> a, List<int> b) {
    // Colorless first, then mono, then multicolor combinations.
    final lengthCmp = a.length.compareTo(b.length);
    if (lengthCmp != 0) return lengthCmp;

    // For same color count, compare in normalized WUBRG sequence.
    final minLen = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < minLen; i++) {
      final rankCmp = a[i].compareTo(b[i]);
      if (rankCmp != 0) return rankCmp;
    }

    return 0;
  }

  int _compareByColorThenName(MTGCard a, MTGCard b) {
    final colorCmp = _compareNormalizedColors(
        _normalizedColorRanks(a), _normalizedColorRanks(b));
    if (colorCmp != 0) return colorCmp;

    final nameCmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCmp != 0) return nameCmp;

    return a.id.compareTo(b.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CardService>(
      builder: (context, cardService, _) {
        if (cardService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final cards = [...getCards(cardService)]..sort(_compareByColorThenName);

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
                subtitle:
                    const Text('Exclude Conspiracy cards from banned list'),
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
                        final imageUrl = card.mainFaceImageUrl;
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
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
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
                              if (card.hasDoubleFacedImages)
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.purple
                                          .withAlpha((0.85 * 255).round()),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '↻',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
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
                                      color: AppColors.gameChangerOrange,
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
