import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filters/filter_settings.dart';
import '../../models/cards/card_enums.dart';
import '../../services/card_service.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Spell Cards'),  // Changed from 'Non-Land Cards'
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
      body: TabBarView(
        controller: _tabController,
        children: const [
          SpellFilterTab(),
          LandFilterTab(),
        ],
      ),
    );
  }
}

class SpellFilterTab extends StatelessWidget {
  const SpellFilterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SpellFilterSettings>(
      builder: (context, filterSettings, child) {
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
                    ...CardType.values.where((type) => type.displayName != 'Land').map((cardType) {
                      return CheckboxListTile(
                        title: Text(cardType.displayName),
                        value: filterSettings.selectedCardTypes.contains(cardType),
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
                    Switch(
                      value: filterSettings.exclusiveColorMatch,
                      onChanged: (_) => filterSettings.toggleColorMatchMode(),
                    ),
                    Text(filterSettings.exclusiveColorMatch 
                        ? 'Must match colors exactly' 
                        : 'Can be played with these colors'),
                    const SizedBox(height: 12),
                    ...MTGColor.values.map((color) {
                      return CheckboxListTile(
                        title: Text(color.displayName),
                        value: filterSettings.selectedColors.contains(color),
                        onChanged: (value) {
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
                              filterSettings.setMaxCMC(double.tryParse(value) ?? 15);
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
    return Consumer<LandFilterSettings>(
      builder: (context, filterSettings, child) {
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
                    const SizedBox(height: 12),
                    ...MTGColor.values.map((color) {
                      return CheckboxListTile(
                        title: Text(color.displayName),
                        value: filterSettings.producedMana.contains(color),
                        onChanged: (value) {
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
                        value: filterSettings.selectedLandTypes.contains(landType),
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