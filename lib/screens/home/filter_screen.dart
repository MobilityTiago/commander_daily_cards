import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/filters/filter_settings.dart';
import '../../models/cards/card_enums.dart';
import '../../services/card_service.dart';
import '../../services/user_preferences_service.dart';
import '../navigation/navigation_screen.dart';
import '../../widgets/mana_symbol_label.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen>
    with SingleTickerProviderStateMixin {
  static const String _persistedDailyFiltersKey = 'daily_filter_state';
  late TabController _tabController;
  SpellFilterSettings? _spellFilters;
  LandFilterSettings? _landFilters;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachFilterListeners();
      unawaited(_loadPersistedDailyFiltersIfEnabled());
    });
  }

  @override
  void dispose() {
    _spellFilters?.removeListener(_onAnyFilterChanged);
    _landFilters?.removeListener(_onAnyFilterChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _attachFilterListeners() {
    final nextSpell = context.read<SpellFilterSettings>();
    final nextLand = context.read<LandFilterSettings>();

    if (!identical(_spellFilters, nextSpell)) {
      _spellFilters?.removeListener(_onAnyFilterChanged);
      _spellFilters = nextSpell;
      _spellFilters?.addListener(_onAnyFilterChanged);
    }
    if (!identical(_landFilters, nextLand)) {
      _landFilters?.removeListener(_onAnyFilterChanged);
      _landFilters = nextLand;
      _landFilters?.addListener(_onAnyFilterChanged);
    }
  }

  void _onAnyFilterChanged() {
    unawaited(_saveDailyFiltersIfEnabled());
  }

  Future<void> _loadPersistedDailyFiltersIfEnabled() async {
    final prefsService = context.read<UserPreferencesService>();
    final spell = context.read<SpellFilterSettings>();
    final land = context.read<LandFilterSettings>();

    if (!prefsService.persistentFiltersEnabled) {
      await _clearPersistedDailyFilters();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_persistedDailyFiltersKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final spellMap = decoded['spell'] as Map<String, dynamic>?;
      if (spellMap != null) {
        final desiredTypes =
            (spellMap['selectedCardTypes'] as List? ?? const [])
                .whereType<String>()
                .toSet();
        for (final type
            in CardType.values.where((t) => t.displayName != 'Land')) {
          final shouldContain = desiredTypes.contains(type.displayName);
          if (spell.selectedCardTypes.contains(type) != shouldContain) {
            spell.toggleCardType(type);
          }
        }

        final desiredColors = (spellMap['selectedColors'] as List? ?? const [])
            .whereType<String>()
            .toSet();
        for (final color in MTGColor.values) {
          final shouldContain = desiredColors.contains(color.symbol);
          if (spell.selectedColors.contains(color) != shouldContain) {
            spell.toggleColor(color);
          }
        }

        final desiredExclusive =
            spellMap['exclusiveColorMatch'] as bool? ?? false;
        if (spell.exclusiveColorMatch != desiredExclusive) {
          spell.toggleColorMatchMode();
        }

        final desiredMin = (spellMap['minCMC'] as num?)?.toDouble() ?? 0;
        final desiredMax = (spellMap['maxCMC'] as num?)?.toDouble() ?? 15;
        if (spell.minCMC != desiredMin) spell.setMinCMC(desiredMin);
        if (spell.maxCMC != desiredMax) spell.setMaxCMC(desiredMax);

        spell.setKeywords(spellMap['keywords'] as String? ?? '');

        final desiredRarities =
            (spellMap['selectedRarities'] as List? ?? const [])
                .whereType<String>()
                .map((e) => e.toLowerCase())
                .toSet();
        for (final rarity in const ['common', 'uncommon', 'rare', 'mythic']) {
          final shouldContain = desiredRarities.contains(rarity);
          if (spell.selectedRarities.contains(rarity) != shouldContain) {
            spell.toggleRarity(rarity);
          }
        }
      }

      final landMap = decoded['land'] as Map<String, dynamic>?;
      if (landMap != null) {
        final desiredProduced = (landMap['producedMana'] as List? ?? const [])
            .whereType<String>()
            .toSet();
        for (final color in MTGColor.values) {
          final shouldContain = desiredProduced.contains(color.symbol);
          if (land.producedMana.contains(color) != shouldContain) {
            land.toggleProducedMana(color);
          }
        }

        final desiredLandTypes =
            (landMap['selectedLandTypes'] as List? ?? const [])
                .whereType<String>()
                .toSet();
        for (final landType in land.landTypes) {
          final shouldContain = desiredLandTypes.contains(landType);
          if (land.selectedLandTypes.contains(landType) != shouldContain) {
            land.toggleLandType(landType);
          }
        }

        final fetchLands = landMap['fetchLands'] as bool? ?? true;
        if (land.fetchLands != fetchLands) land.toggleFetchLands();
        final shockLands = landMap['shockLands'] as bool? ?? true;
        if (land.shockLands != shockLands) land.toggleShockLands();
        final dualLands = landMap['dualLands'] as bool? ?? true;
        if (land.dualLands != dualLands) land.toggleDualLands();
        final utilityLands = landMap['utilityLands'] as bool? ?? true;
        if (land.utilityLands != utilityLands) land.toggleUtilityLands();

        land.setKeywords(landMap['keywords'] as String? ?? '');
      }
    } catch (_) {
      // Ignore invalid persisted filter state.
    }
  }

  Future<void> _saveDailyFiltersIfEnabled() async {
    final prefsService = context.read<UserPreferencesService>();
    if (!prefsService.persistentFiltersEnabled) {
      await _clearPersistedDailyFilters();
      return;
    }

    final spell = context.read<SpellFilterSettings>();
    final land = context.read<LandFilterSettings>();
    final state = {
      'spell': {
        'selectedCardTypes':
            spell.selectedCardTypes.map((e) => e.displayName).toList(),
        'selectedColors': spell.selectedColors.map((e) => e.symbol).toList(),
        'minCMC': spell.minCMC,
        'maxCMC': spell.maxCMC,
        'exclusiveColorMatch': spell.exclusiveColorMatch,
        'selectedRarities': spell.selectedRarities.toList(),
        'keywords': spell.keywords,
      },
      'land': {
        'producedMana': land.producedMana.map((e) => e.symbol).toList(),
        'selectedLandTypes': land.selectedLandTypes.toList(),
        'fetchLands': land.fetchLands,
        'shockLands': land.shockLands,
        'dualLands': land.dualLands,
        'utilityLands': land.utilityLands,
        'keywords': land.keywords,
      },
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_persistedDailyFiltersKey, jsonEncode(state));
  }

  Future<void> _clearPersistedDailyFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistedDailyFiltersKey);
  }

  Widget _buildPersistentFiltersBanner() {
    return Consumer<UserPreferencesService>(
      builder: (context, preferences, _) {
        if (!preferences.persistentFiltersEnabled) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                NavigationScreen.routeUserPreferences,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.16 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.green.withAlpha((0.45 * 255).round())),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Persistent filters are ON',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Spell Cards'), // Changed from 'Non-Land Cards'
            Tab(text: 'Lands'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final cardService = context.read<CardService>();
              final nonLandFilters = context.read<SpellFilterSettings>();
              final landFilters = context.read<LandFilterSettings>();
              await cardService.refreshDailyCards(nonLandFilters, landFilters);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPersistentFiltersBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                SpellFilterTab(),
                LandFilterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpellFilterTab extends StatelessWidget {
  const SpellFilterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<CardService, SpellFilterSettings>(
      builder: (context, cardService, filterSettings, child) {
        final isCommanderLocked = cardService.selectedCommanders.isNotEmpty;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card Types Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card Types',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...CardType.values
                        .where((type) => type.displayName != 'Land')
                        .map((cardType) {
                      return CheckboxListTile(
                        title: Text(cardType.displayName),
                        value:
                            filterSettings.selectedCardTypes.contains(cardType),
                        onChanged: (value) {
                          filterSettings.toggleCardType(cardType);
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Commander Colors Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commander Colors',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cards that could be played in a deck with these colors',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isCommanderLocked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Locked to ${cardService.selectedCommanderNames} while a commander is selected.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    Switch(
                      value: filterSettings.exclusiveColorMatch,
                      onChanged: isCommanderLocked
                          ? null
                          : (_) => filterSettings.toggleColorMatchMode(),
                    ),
                    Text(filterSettings.exclusiveColorMatch
                        ? 'Must match colors exactly'
                        : 'Can be played with these colors'),
                    const SizedBox(height: 12),
                    ...MTGColor.values.map((color) {
                      return CheckboxListTile(
                        title: ManaSymbolLabel(color: color),
                        value: filterSettings.selectedColors.contains(color),
                        onChanged: isCommanderLocked
                            ? null
                            : (value) {
                                filterSettings.toggleColor(color);
                              },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mana Value Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mana Value',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total mana cost of the spell',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Minimum',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              // Add min CMC to filter settings
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Maximum',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              filterSettings
                                  .setMaxCMC(double.tryParse(value) ?? 15);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Oracle Text Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oracle Text',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search card text, ability words, and keywords',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search card text...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        filterSettings.setKeywords(value);
                      },
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rarity Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rarity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...['Common', 'Uncommon', 'Rare', 'Mythic'].map((rarity) {
                      return CheckboxListTile(
                        title: Text(rarity),
                        value: true, // Add rarity to filter settings
                        onChanged: (value) {
                          // Add rarity toggle to filter settings
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class LandFilterTab extends StatelessWidget {
  const LandFilterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<CardService, LandFilterSettings>(
      builder: (context, cardService, filterSettings, child) {
        final isCommanderLocked = cardService.selectedCommanders.isNotEmpty;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Produced Mana Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produced Mana',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (isCommanderLocked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Locked to ${cardService.selectedCommanderNames} while a commander is selected.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...MTGColor.values.map((color) {
                      return CheckboxListTile(
                        title: ManaSymbolLabel(color: color),
                        value: filterSettings.producedMana.contains(color),
                        onChanged: isCommanderLocked
                            ? null
                            : (value) {
                                filterSettings.toggleProducedMana(color);
                              },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Land Types Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Land Types',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...filterSettings.landTypes.map((landType) {
                      return CheckboxListTile(
                        title: Text(landType),
                        value:
                            filterSettings.selectedLandTypes.contains(landType),
                        onChanged: (value) {
                          filterSettings.toggleLandType(landType);
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Special Land Types Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Land Types',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Fetch Lands'),
                      value: filterSettings.fetchLands,
                      onChanged: (_) => filterSettings.toggleFetchLands(),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Shock Lands'),
                      value: filterSettings.shockLands,
                      onChanged: (_) => filterSettings.toggleShockLands(),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Dual Lands'),
                      value: filterSettings.dualLands,
                      onChanged: (_) => filterSettings.toggleDualLands(),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Utility Lands'),
                      value: filterSettings.utilityLands,
                      onChanged: (_) => filterSettings.toggleUtilityLands(),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Keywords Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keywords',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Keywords (comma separated)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        filterSettings.setKeywords(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
