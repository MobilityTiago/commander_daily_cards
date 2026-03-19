import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';
import '../../services/symbol_service.dart';
import '../../styles/colors.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/card_badges_overlay.dart';
import '../../widgets/collapsible_filter_section.dart';
import '../../widgets/flip_animated_image.dart';
import '../../widgets/card_zoom_view.dart';

class LandGuideScreen extends StatefulWidget {
  const LandGuideScreen({super.key});

  @override
  State<LandGuideScreen> createState() => _LandGuideScreenState();
}

class _LandGuideScreenState extends State<LandGuideScreen> {
  final Set<String> _selectedDualPairs = {};
  final Set<String> _selectedDualFamilies = {};
  final Set<String> _selectedTriCombos = {};
  final Set<String> _selectedTriFamilies = {};
  final Set<String> _selectedMultiFamilies = {};
  final Set<String> _selectedMonoColors = {};
  final Set<String> _selectedMonoFamilies = {};
  final Set<String> _selectedColorlessModes = {};
  final Set<String> _selectedColorlessFamilies = {};
  double _chipFiltersVisibility = 1.0;

  static const double _collapseDistance = 180.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<CardService>().ensureCardCatalogLoaded();
    });
  }

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
            final filteredTriLands = _selectedTriCombos.isEmpty
                ? triLands
                : triLands
                    .where(
                      (card) => _selectedTriCombos.contains(
                        _manaComboKey(_coloredProducedMana(card)),
                      ),
                    )
                    .toList();
            final triLandsWithFamilies = _filterByFamilies(
              filteredTriLands,
              _selectedTriFamilies,
            );
            final filteredMultiLands = _filterByFamilies(
              multiLands,
              _selectedMultiFamilies,
            );
            final filteredMonoLands = _selectedMonoColors.isEmpty
                ? monoLands
                : monoLands
                    .where(
                      (card) => _selectedMonoColors
                          .contains(_coloredProducedMana(card).first),
                    )
                    .toList();
            final monoLandsWithFamilies = _filterByFamilies(
              filteredMonoLands,
              _selectedMonoFamilies,
            );
            final filteredColorlessLands = _selectedColorlessModes.isEmpty
                ? colorlessLands
                : colorlessLands.where((card) {
                    final produced = _producedManaSymbols(card);
                    final hasColorless = produced.contains('C');
                    final hasNoMana = produced.isEmpty;
                    return (_selectedColorlessModes.contains('C') &&
                            hasColorless) ||
                        (_selectedColorlessModes.contains('NO_MANA') &&
                            hasNoMana);
                  }).toList();
            final colorlessLandsWithFamilies = _filterByFamilies(
              filteredColorlessLands,
              _selectedColorlessFamilies,
            );

            return Column(
              children: [
                Container(
                  color: AppColors.black,
                  child: const TabBar(
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(fontSize: 12),
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
                        showChipFilters: _chipFiltersVisibility > 0.001,
                        chipFiltersVisibility: _chipFiltersVisibility,
                        selectedPairs: _selectedDualPairs,
                        selectedFamilies: _selectedDualFamilies,
                        onGridScroll: _handleGridScroll,
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
                            _toggleSelection(_selectedDualFamilies, familyKey);
                          });
                        },
                      ),
                      _TriLandTab(
                        lands: triLandsWithFamilies,
                        allLands: triLands,
                        showChipFilters: _chipFiltersVisibility > 0.001,
                        chipFiltersVisibility: _chipFiltersVisibility,
                        selectedCombos: _selectedTriCombos,
                        selectedFamilies: _selectedTriFamilies,
                        onGridScroll: _handleGridScroll,
                        onToggleCombo: (comboKey) {
                          setState(() {
                            _toggleSelection(_selectedTriCombos, comboKey);
                          });
                        },
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleSelection(_selectedTriFamilies, familyKey);
                          });
                        },
                      ),
                      _LandGridTab(
                        lands: filteredMultiLands,
                        allLands: multiLands,
                        showChipFilters: _chipFiltersVisibility > 0.001,
                        chipFiltersVisibility: _chipFiltersVisibility,
                        selectedFamilies: _selectedMultiFamilies,
                        onGridScroll: _handleGridScroll,
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleSelection(_selectedMultiFamilies, familyKey);
                          });
                        },
                      ),
                      _MonoLandTab(
                        lands: monoLandsWithFamilies,
                        allLands: monoLands,
                        showChipFilters: _chipFiltersVisibility > 0.001,
                        chipFiltersVisibility: _chipFiltersVisibility,
                        selectedColors: _selectedMonoColors,
                        selectedFamilies: _selectedMonoFamilies,
                        onGridScroll: _handleGridScroll,
                        onToggleColor: (color) {
                          setState(() {
                            _toggleSelection(_selectedMonoColors, color);
                          });
                        },
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleSelection(_selectedMonoFamilies, familyKey);
                          });
                        },
                      ),
                      _ColorlessLandTab(
                        lands: colorlessLandsWithFamilies,
                        allLands: colorlessLands,
                        showChipFilters: _chipFiltersVisibility > 0.001,
                        chipFiltersVisibility: _chipFiltersVisibility,
                        selectedModes: _selectedColorlessModes,
                        selectedFamilies: _selectedColorlessFamilies,
                        onGridScroll: _handleGridScroll,
                        onToggleMode: (mode) {
                          setState(() {
                            _toggleSelection(_selectedColorlessModes, mode);
                          });
                        },
                        onToggleFamily: (familyKey) {
                          setState(() {
                            _toggleSelection(
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

  void _toggleSelection(Set<String> selectedValues, String value) {
    if (selectedValues.contains(value)) {
      selectedValues.remove(value);
    } else {
      selectedValues.add(value);
    }
  }

  void _handleGridScroll(ScrollUpdateNotification notification) {
    final pixels = notification.metrics.pixels;
    if (pixels <= 0) {
      if (_chipFiltersVisibility != 1.0) {
        setState(() {
          _chipFiltersVisibility = 1.0;
        });
      }
      return;
    }

    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return;

    final next =
        (_chipFiltersVisibility - (delta / _collapseDistance)).clamp(0.0, 1.0);
    if ((next - _chipFiltersVisibility).abs() < 0.001) return;

    setState(() {
      _chipFiltersVisibility = next;
    });
  }
}

class _TriLandTab extends StatelessWidget {
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final bool showChipFilters;
  final double chipFiltersVisibility;
  final Set<String> selectedCombos;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onToggleCombo;
  final ValueChanged<String> onToggleFamily;
  final ValueChanged<ScrollUpdateNotification> onGridScroll;

  const _TriLandTab({
    required this.lands,
    required this.allLands,
    required this.showChipFilters,
    required this.chipFiltersVisibility,
    required this.selectedCombos,
    required this.selectedFamilies,
    required this.onToggleCombo,
    required this.onToggleFamily,
    required this.onGridScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleFilterSection(
          visible: showChipFilters,
          visibility: chipFiltersVisibility,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _triColorCombos.map((combo) {
                    final key = _manaComboKey(combo);
                    return FilterChip(
                      label: _ManaPairLabel(symbols: combo),
                      showCheckmark: false,
                      selected: selectedCombos.contains(key),
                      onSelected: (_) => onToggleCombo(key),
                    );
                  }).toList(),
                ),
              ),
              const _ChipSectionDivider(),
              _LandFamilyFilters(
                lands: allLands,
                selectedFamilies: selectedFamilies,
                onToggleFamily: onToggleFamily,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No tri lands match the selected color combinations.',
            onUserScroll: onGridScroll,
          ),
        ),
      ],
    );
  }
}

class _DualLandTab extends StatelessWidget {
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final bool showChipFilters;
  final double chipFiltersVisibility;
  final Set<String> selectedPairs;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onTogglePair;
  final ValueChanged<String> onToggleFamily;
  final ValueChanged<ScrollUpdateNotification> onGridScroll;

  const _DualLandTab({
    required this.lands,
    required this.allLands,
    required this.showChipFilters,
    required this.chipFiltersVisibility,
    required this.selectedPairs,
    required this.selectedFamilies,
    required this.onTogglePair,
    required this.onToggleFamily,
    required this.onGridScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleFilterSection(
          visible: showChipFilters,
          visibility: chipFiltersVisibility,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dualColorPairs.map((pair) {
                    final pairKey = _manaPairKey(pair);
                    final isSelected = selectedPairs.contains(pairKey);
                    return FilterChip(
                      label: _ManaPairLabel(symbols: pair),
                      showCheckmark: false,
                      selected: isSelected,
                      onSelected: (_) => onTogglePair(pairKey),
                    );
                  }).toList(),
                ),
              ),
              const _ChipSectionDivider(),
              _LandFamilyFilters(
                lands: allLands,
                selectedFamilies: selectedFamilies,
                onToggleFamily: onToggleFamily,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No dual lands match the selected color pairs.',
            onUserScroll: onGridScroll,
          ),
        ),
      ],
    );
  }
}

class _LandGridTab extends StatelessWidget {
  final List<MTGCard> lands;
  final bool showChipFilters;
  final double chipFiltersVisibility;
  final List<MTGCard>? allLands;
  final Set<String>? selectedFamilies;
  final ValueChanged<String>? onToggleFamily;
  final ValueChanged<ScrollUpdateNotification> onGridScroll;

  const _LandGridTab({
    required this.lands,
    required this.showChipFilters,
    required this.chipFiltersVisibility,
    required this.onGridScroll,
    this.allLands,
    this.selectedFamilies,
    this.onToggleFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allLands != null &&
            selectedFamilies != null &&
            onToggleFamily != null)
          CollapsibleFilterSection(
            visible: showChipFilters,
            visibility: chipFiltersVisibility,
            child: _LandFamilyFilters(
              lands: allLands!,
              selectedFamilies: selectedFamilies!,
              onToggleFamily: onToggleFamily!,
            ),
          ),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No lands found in this category.',
            onUserScroll: onGridScroll,
          ),
        ),
      ],
    );
  }
}

class _MonoLandTab extends StatelessWidget {
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final bool showChipFilters;
  final double chipFiltersVisibility;
  final Set<String> selectedColors;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onToggleColor;
  final ValueChanged<String> onToggleFamily;
  final ValueChanged<ScrollUpdateNotification> onGridScroll;

  const _MonoLandTab({
    required this.lands,
    required this.allLands,
    required this.showChipFilters,
    required this.chipFiltersVisibility,
    required this.selectedColors,
    required this.selectedFamilies,
    required this.onToggleColor,
    required this.onToggleFamily,
    required this.onGridScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleFilterSection(
          visible: showChipFilters,
          visibility: chipFiltersVisibility,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _wubrgOrder.map((symbol) {
                    return FilterChip(
                      label: _ManaPairLabel(symbols: [symbol]),
                      showCheckmark: false,
                      selected: selectedColors.contains(symbol),
                      onSelected: (_) => onToggleColor(symbol),
                    );
                  }).toList(),
                ),
              ),
              const _ChipSectionDivider(),
              _LandFamilyFilters(
                lands: allLands,
                selectedFamilies: selectedFamilies,
                onToggleFamily: onToggleFamily,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No mono lands match the selected colors.',
            onUserScroll: onGridScroll,
          ),
        ),
      ],
    );
  }
}

class _ColorlessLandTab extends StatelessWidget {
  final List<MTGCard> lands;
  final List<MTGCard> allLands;
  final bool showChipFilters;
  final double chipFiltersVisibility;
  final Set<String> selectedModes;
  final Set<String> selectedFamilies;
  final ValueChanged<String> onToggleMode;
  final ValueChanged<String> onToggleFamily;
  final ValueChanged<ScrollUpdateNotification> onGridScroll;

  const _ColorlessLandTab({
    required this.lands,
    required this.allLands,
    required this.showChipFilters,
    required this.chipFiltersVisibility,
    required this.selectedModes,
    required this.selectedFamilies,
    required this.onToggleMode,
    required this.onToggleFamily,
    required this.onGridScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleFilterSection(
          visible: showChipFilters,
          visibility: chipFiltersVisibility,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: _ManaPairLabel(symbols: const ['C']),
                      showCheckmark: false,
                      selected: selectedModes.contains('C'),
                      onSelected: (_) => onToggleMode('C'),
                    ),
                    FilterChip(
                      label: const Text('No mana'),
                      showCheckmark: false,
                      selected: selectedModes.contains('NO_MANA'),
                      onSelected: (_) => onToggleMode('NO_MANA'),
                    ),
                  ],
                ),
              ),
              const _ChipSectionDivider(),
              _LandFamilyFilters(
                lands: allLands,
                selectedFamilies: selectedFamilies,
                onToggleFamily: onToggleFamily,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandGrid(
            lands: lands,
            emptyMessage: 'No lands match the selected colorless filters.',
            onUserScroll: onGridScroll,
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
            showCheckmark: false,
            selected: isSelected,
            onSelected: (_) => onToggleFamily(family.key),
          );
        }).toList(),
      ),
    );
  }
}

class _ChipSectionDivider extends StatelessWidget {
  const _ChipSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.16),
      ),
    );
  }
}

class _LandGrid extends StatelessWidget {
  final List<MTGCard> lands;
  final String emptyMessage;
  final ValueChanged<ScrollUpdateNotification>? onUserScroll;

  const _LandGrid({
    required this.lands,
    required this.emptyMessage,
    this.onUserScroll,
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

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        onUserScroll?.call(notification);
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.715,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: lands.length,
        itemBuilder: (context, index) {
          return _LandCardTile(
            key: ValueKey(lands[index].id),
            card: lands[index],
            cards: lands,
            initialIndex: index,
          );
        },
      ),
    );
  }
}

class _LandCardTile extends StatefulWidget {
  final MTGCard card;
  final List<MTGCard> cards;
  final int initialIndex;

  const _LandCardTile({
    super.key,
    required this.card,
    required this.cards,
    required this.initialIndex,
  });

  @override
  State<_LandCardTile> createState() => _LandCardTileState();
}

class _LandCardTileState extends State<_LandCardTile> {
  bool _isFlipped = false;

  @override
  void didUpdateWidget(covariant _LandCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id && _isFlipped) {
      _isFlipped = false;
    }
  }

  String? get _displayImageUrl {
    if (!widget.card.hasDoubleFacedImages) {
      return widget.card.mainFaceImageUrl;
    }

    if (_isFlipped) {
      return widget.card.backFaceImageUrl ?? widget.card.mainFaceImageUrl;
    }

    return widget.card.mainFaceImageUrl ?? widget.card.backFaceImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _displayImageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: imageUrl == null
                ? null
                : () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (context, _, __) => CardZoomView(
                          cards: widget.cards,
                          initialIndex: widget.initialIndex,
                        ),
                        transitionsBuilder: (context, animation, _, child) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                      ),
                    );
                  },
            child: imageUrl != null
                ? FlipAnimatedImage(
                    imageUrl: imageUrl,
                    isFlipped: _isFlipped,
                    fit: BoxFit.cover,
                    placeholder: Image.asset(
                      'assets/images/Magic_card_back.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/images/Magic_card_back.png',
                    fit: BoxFit.cover,
                  ),
          ),
          CardBadgesOverlay(
            hasDoubleFacedImages: widget.card.hasDoubleFacedImages,
            isBanned: widget.card.legalities['commander'] == 'banned',
            isGameChanger: widget.card.gameChanger,
            onDoubleFacedTap: () {
              if (!widget.card.hasDoubleFacedImages) return;
              setState(() {
                _isFlipped = !_isFlipped;
              });
            },
            isDoubleFacedFlipped: _isFlipped,
          ),
        ],
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

const List<List<String>> _triColorCombos = [
  ['W', 'U', 'B'],
  ['W', 'U', 'R'],
  ['W', 'U', 'G'],
  ['W', 'B', 'R'],
  ['W', 'B', 'G'],
  ['W', 'R', 'G'],
  ['U', 'B', 'R'],
  ['U', 'B', 'G'],
  ['U', 'R', 'G'],
  ['B', 'R', 'G'],
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

String _manaComboKey(List<String> symbols) {
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
