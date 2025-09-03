import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_settings.dart';
import '../models/card_enums.dart';
import '../services/card_service.dart';

class FilterScreen extends StatelessWidget {
  const FilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Settings'),
        actions: [
          TextButton(
            onPressed: () async {
              final cardService = context.read<CardService>();
              final filterSettings = context.read<FilterSettings>();
              await cardService.refreshDailyCards(filterSettings);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: Consumer<FilterSettings>(
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
                      ...CardType.values.map((cardType) {
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

              // Colors Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Colors',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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

              // Mana Cost Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum CMC: ${filterSettings.maxCMC.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: filterSettings.maxCMC,
                        min: 0,
                        max: 15,
                        divisions: 15,
                        onChanged: (value) {
                          filterSettings.setMaxCMC(value);
                        },
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
      ),
    );
  }
}