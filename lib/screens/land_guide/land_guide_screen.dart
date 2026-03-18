import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';
import '../../services/symbol_service.dart';
import '../../styles/colors.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/card_zoom_view.dart';

class LandGuideScreen extends StatefulWidget {
  const LandGuideScreen({super.key});

  @override
  State<LandGuideScreen> createState() => _LandGuideScreenState();
}

class _LandGuideScreenState extends State<LandGuideScreen> {
  final Set<String> _selectedDualPairs = {};
  final Set<String> _selectedDualFamilies = {};
  final Set<String> _selectedTriFamilies = {};
  final Set<String> _selectedMultiFamilies = {};
  final Set<String> _selectedMonoFamilies = {};
  final Set<String> _selectedColorlessFamilies = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: const CommanderAppBar(
          title: 'Land Guide',
        ),
        body: Consumer<CardService>(
          builder: (context, cardService, _) {
            if (cardService.isLoading && cardService.allCards.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final lands = _uniqueLands(cardService.allCards)
              ..sort((a, b) => a.name.compareTo(b.name));

            final dualLands = lands
                .where((card) => _coloredProducedMana(card).length == 2)
                .toList();
            final triLands = lands
                .where((card) => _coloredProducedMana(card).length == 3)
                .toList();
            final multiLands = lands
                .where((card) => _coloredProducedMana(card).length >= 4)
                .toList();
            final monoLands = lands
                .where((card) => _coloredProducedMana(card).length == 1)
                .toList();
            final colorlessLands = lands
                .where((card) => _coloredProducedMana(card).isEmpty)
                .toList();

            final filteredDualLands = _filterByFamilies(
              _selectedDualPairs.isEmpty
                  ? dualLands
                  : dualLands
                      .where(
                        (card) => _selectedDualPairs.contains(
                          _manaPairKey(_coloredProducedMana(card)),
                        ),
                      )
                      .toList(),
              _selectedDualFamilies,
            );
            final filteredTriLands = _filterByFamilies(
              triLands,
              _selectedTriFamilies,
            );
            final filteredMultiLands = _filterByFamilies(
              multiLands,
              _selectedMultiFamilies,
            );
            final filteredMonoLands = _filterByFamilies(
              monoLands,
              _selectedMonoFamilies,
            );
            final filteredColorlessLands = _filterByFamilies(
              colorlessLands,
              _selectedColorlessFamilies,
            );

            return Column(
              children: [
                Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const TabBar(
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: AppColors.red,
                    tabs: [
                      Tab(text: 'Dual Lands'),
                      Tab(text: 'Tri Lands'),
                      Tab(text: 'Multi Lands'),
                      Tab(text: 'Mono Lands'),
                      Tab(text: 'Colorless Lands'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DualLandTab(
                        lands: filteredDualLands,
                        allLands: dualLands,
                        selectedPairs: _selectedDualPairs,
                        selectedFamilies: _selectedDualFamilies,
                        onTogglePair: (pairKey) {
                          setState(() {
                            if (_selectedDualPairs.contains(pairKey)) {
                              _selectedDualPairs.remove(pairKey);
                            } else {
                              _selectedDualPairs.add(pairKey);
                            }
                          });
                        },
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleFamily(_selectedDualFamilies, familyKey);
                          });
                        },
                      ),
                      _LandGridTab(
                        title: 'Tri-color lands',
                        subtitle:
                            '${triLands.length} lands that produce exactly three colors',
                        lands: filteredTriLands,
                        allLands: triLands,
                        selectedFamilies: _selectedTriFamilies,
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleFamily(_selectedTriFamilies, familyKey);
                          });
                        },
                      ),
                      _LandGridTab(
                        title: 'Multi-color lands',
                        subtitle:
                            '${multiLands.length} lands that produce four or five colors',
                        lands: filteredMultiLands,
                        allLands: multiLands,
                        selectedFamilies: _selectedMultiFamilies,
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleFamily(_selectedMultiFamilies, familyKey);
                          });
                        },
                      ),
                      _LandGridTab(
                        title: 'Mono-color lands',
                        subtitle:
                            '${monoLands.length} lands that produce exactly one color',
                        lands: filteredMonoLands,
                        allLands: monoLands,
                        selectedFamilies: _selectedMonoFamilies,
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleFamily(_selectedMonoFamilies, familyKey);
                          });
                        },
                      ),
                      _LandGridTab(
                        title: 'Colorless lands',
                        subtitle:
                            '${colorlessLands.length} lands with no colored mana production',
                        lands: filteredColorlessLands,
                        allLands: colorlessLands,
                        selectedFamilies: _selectedColorlessFamilies,
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleFamily(
                                _selectedColorlessFamilies, familyKey);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleFamily(Set<String> selectedFamilies, String familyKey) {
    if (selectedFamilies.contains(familyKey)) {
      selectedFamilies.remove(familyKey);
    } else {
      selectedFamilies.add(familyKey);
    }
  }
}

class _DualLandTab extends StatelessWidget {
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final Set<String> selectedPairs;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onTogglePair;
  final ValueChanged<String> onToggleFamily;

  const _DualLandTab({
    required this.lands,
    required this.allLands,
    required this.selectedPairs,
    required this.selectedFamilies,
    required this.onTogglePair,
    required this.onToggleFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            '${lands.length} dual lands',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dualColorPairs.map((pair) {
              final pairKey = _manaPairKey(pair);
              final isSelected = selectedPairs.contains(pairKey);
              return FilterChip(
                selected: isSelected,
                showCheckmark: false,
                selectedColor: AppColors.darkRed,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(
                  color: isSelected ? AppColors.red : Colors.white24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                label: _ManaPairLabel(symbols: pair),
                onSelected: (_) => onTogglePair(pairKey),
              );
            }).toList(),
          ),
        ),
        _LandFamilyFilters(
          lands: allLands,
          selectedFamilies: selectedFamilies,
          onToggleFamily: onToggleFamily,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No dual lands match the selected color pairs.',
          ),
        ),
      ],
    );
  }
}

class _LandGridTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onToggleFamily;

  const _LandGridTab({
    required this.title,
    required this.subtitle,
    required this.lands,
    required this.allLands,
    required this.selectedFamilies,
    required this.onToggleFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        _LandFamilyFilters(
          lands: allLands,
          selectedFamilies: selectedFamilies,
          onToggleFamily: onToggleFamily,
        ),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No lands found in this category.',
          ),
        ),
      ],
    );
  }
}

class _LandFamilyFilters extends StatelessWidget {
  final List<MTGCard> lands;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onToggleFamily;

  const _LandFamilyFilters({
    required this.lands,
    required this.selectedFamilies,
    required this.onToggleFamily,
  });

  @override
  Widget build(BuildContext context) {
    final availableFamilies =
        _landFamilies.where((family) => lands.any(family.matches)).toList();
    if (availableFamilies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: availableFamilies.map((family) {
          final isSelected = selectedFamilies.contains(family.key);
          return FilterChip(
            label: Text(family.label),
            selected: isSelected,
            selectedColor: AppColors.darkRed,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(
              color: isSelected ? AppColors.red : Colors.white24,
            ),
            onSelected: (_) => onToggleFamily(family.key),
          );
        }).toList(),
      ),
    );
  }
}

class _LandGrid extends StatelessWidget {
  final List<MTGCard> lands;
  final String emptyMessage;

  const _LandGrid({
    required this.lands,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (lands.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: lands.length,
      itemBuilder: (context, index) {
        return _LandCardTile(
          card: lands[index],
          cards: lands,
          initialIndex: index,
        );
      },
    );
  }
}

class _LandCardTile extends StatelessWidget {
  final MTGCard card;
  final List<MTGCard> cards;
  final int initialIndex;

  const _LandCardTile({
    required this.card,
    required this.cards,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = card.mainFaceImageUrl;
    final manaSymbols = _producedManaSymbols(card);

    return Card(
      color: AppColors.lightGrey,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: imageUrl == null
            ? null
            : () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (context, _, __) => CardZoomView(
                      cards: cards,
                      initialIndex: initialIndex,
                    ),
                    transitionsBuilder: (context, animation, _, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.landscape,
                        color: Colors.white54,
                        size: 36,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.typeLine ?? 'Land',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (manaSymbols.isEmpty)
                    const Text(
                      'No colored mana',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: manaSymbols
                          .map((symbol) =>
                              _ManaSymbolToken(symbol: symbol, size: 18))
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManaPairLabel extends StatelessWidget {
  final List<String> symbols;

  const _ManaPairLabel({required this.symbols});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: symbols
          .map(
            (symbol) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _ManaSymbolToken(symbol: symbol, size: 18),
            ),
          )
          .toList(),
    );
  }
}

class _ManaSymbolToken extends StatelessWidget {
  final String symbol;
  final double size;

  const _ManaSymbolToken({
    required this.symbol,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final symbolService = context.watch<SymbolService>();
    final token = '{$symbol}';
    final svgData = symbolService.svgDataByToken(token);

    if (svgData == null || svgData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        symbolService.requestRefreshOnMiss(token);
      });
    }

    if (svgData != null && svgData.isNotEmpty) {
      return SvgPicture.string(
        svgData,
        width: size,
        height: size,
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        border: Border.all(color: Colors.white24),
        shape: BoxShape.circle,
      ),
      child: Text(
        symbol,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const List<List<String>> _dualColorPairs = [
  ['W', 'U'],
  ['W', 'B'],
  ['U', 'B'],
  ['U', 'R'],
  ['B', 'R'],
  ['B', 'G'],
  ['R', 'G'],
  ['R', 'W'],
  ['G', 'W'],
  ['G', 'U'],
];

List<MTGCard> _uniqueLands(List<MTGCard> cards) {
  final uniqueByName = <String, MTGCard>{};
  for (final card in cards) {
    if (!_isLand(card)) continue;
    uniqueByName.putIfAbsent(card.name.toLowerCase(), () => card);
  }
  return uniqueByName.values.toList();
}

List<MTGCard> _filterByFamilies(List<MTGCard> lands, Set<String> familyKeys) {
  if (familyKeys.isEmpty) return lands;
  final selectedFamilies =
      _landFamilies.where((family) => familyKeys.contains(family.key)).toList();
  return lands
      .where((card) => selectedFamilies.any((family) => family.matches(card)))
      .toList();
}

bool _isLand(MTGCard card) {
  return card.combinedTypeLine.toLowerCase().contains('land');
}

List<String> _producedManaSymbols(MTGCard card) {
  final produced = <String>{...(card.producedMana ?? const <String>[])};
  final oracle = card.normalizedCombinedOracleText;

  if (_addsAnyColor(oracle)) {
    produced.addAll(_wubrgOrder);
  }

  final addLineMatches = RegExp(r'add[^\n]*').allMatches(oracle);
  for (final match in addLineMatches) {
    final line = match.group(0) ?? '';
    for (final manaMatch in RegExp(r'\{([wubrgc])\}').allMatches(line)) {
      final symbol = manaMatch.group(1)?.toUpperCase();
      if (symbol != null) {
        produced.add(symbol);
      }
    }
  }

  return _sortManaSymbols(produced.toList());
}

List<String> _coloredProducedMana(MTGCard card) {
  return _producedManaSymbols(card)
      .where((symbol) => _wubrgOrder.contains(symbol))
      .toList();
}

String _manaPairKey(List<String> symbols) {
  return _sortManaSymbols(symbols).join();
}

List<String> _sortManaSymbols(List<String> symbols) {
  final unique = <String>{...symbols};
  return [
    ..._wubrgOrder.where(unique.contains),
    ...unique.where((symbol) => !_wubrgOrder.contains(symbol)).toList()..sort(),
  ];
}

const List<String> _wubrgOrder = ['W', 'U', 'B', 'R', 'G'];

bool _addsAnyColor(String oracle) {
  return oracle.contains('add one mana of any color') ||
      oracle.contains('add one mana of any one color') ||
      oracle.contains('add one mana of any type') ||
      oracle.contains(
          "add one mana of any color in your commander's color identity") ||
      oracle.contains('add one mana of any color among') ||
      oracle.contains('add an amount of') &&
          oracle.contains('in any combination of colors');
}

class _LandFamily {
  final String key;
  final String label;
  final bool Function(MTGCard card) matches;

  const _LandFamily({
    required this.key,
    required this.label,
    required this.matches,
  });
}

final List<_LandFamily> _landFamilies = [
  _LandFamily(
    key: 'fetch',
    label: 'Fetch',
    matches: (card) {
      final oracle = card.normalizedCombinedOracleText;
      return oracle.contains('search your library for') &&
          oracle.contains('land card');
    },
  ),
  _LandFamily(
    key: 'shock',
    label: 'Shock',
    matches: (card) {
      final oracle = card.normalizedCombinedOracleText;
      return oracle.contains('enters the battlefield') &&
          oracle.contains('pay 2 life');
    },
  ),
  _LandFamily(
    key: 'check',
    label: 'Check',
    matches: (card) => card.normalizedCombinedOracleText
        .contains('enters the battlefield tapped unless you control'),
  ),
  _LandFamily(
    key: 'pain',
    label: 'Pain',
    matches: (card) =>
        card.normalizedCombinedOracleText.contains('deals 1 damage to you'),
  ),
  _LandFamily(
    key: 'fast',
    label: 'Fast',
    matches: (card) => card.normalizedCombinedOracleText
        .contains('if you control two or fewer other lands'),
  ),
  _LandFamily(
    key: 'slow',
    label: 'Slow',
    matches: (card) => card.normalizedCombinedOracleText
        .contains('if you control two or more other lands'),
  ),
  _LandFamily(
    key: 'scry',
    label: 'Scry',
    matches: (card) => card.normalizedCombinedOracleText.contains('scry 1'),
  ),
  _LandFamily(
    key: 'gain',
    label: 'Gain',
    matches: (card) =>
        card.normalizedCombinedOracleText.contains('you gain 1 life'),
  ),
  _LandFamily(
    key: 'bounce',
    label: 'Bounce',
    matches: (card) => card.normalizedCombinedOracleText
        .contains("return a land you control to its owner's hand"),
  ),
  _LandFamily(
    key: 'cycle',
    label: 'Cycling',
    matches: (card) => card.normalizedCombinedOracleText.contains('cycling'),
  ),
  _LandFamily(
    key: 'manland',
    label: 'Manland',
    matches: (card) {
      final oracle = card.normalizedCombinedOracleText;
      return oracle.contains('becomes a ') && oracle.contains(' creature');
    },
  ),
  _LandFamily(
    key: 'triome',
    label: 'Triome',
    matches: (card) => _basicLandTypeCount(card.combinedTypeLine) >= 3,
  ),
  _LandFamily(
    key: 'fivecolor',
    label: 'Five-Color',
    matches: (card) => _coloredProducedMana(card).length >= 5,
  ),
  _LandFamily(
    key: 'utility',
    label: 'Utility',
    matches: (card) {
      final oracle = card.normalizedCombinedOracleText;
      return oracle.contains('draw a card') ||
          oracle.contains('destroy') ||
          oracle.contains('counter target') ||
          oracle.contains('exile target') ||
          oracle.contains('return target') ||
          oracle.contains('tap target');
    },
  ),
  _LandFamily(
    key: 'sacrifice',
    label: 'Sacrifice',
    matches: (card) => card.normalizedCombinedOracleText.contains('sacrifice'),
  ),
];

int _basicLandTypeCount(String typeLine) {
  final lower = typeLine.toLowerCase();
  var count = 0;
  for (final type in const [
    'plains',
    'island',
    'swamp',
    'mountain',
    'forest'
  ]) {
    if (lower.contains(type)) count++;
  }
  return count;
}
