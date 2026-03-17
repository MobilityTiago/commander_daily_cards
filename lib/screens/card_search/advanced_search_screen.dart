import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_bar.dart';
import '../../widgets/card_zoom_view.dart';
import '../../models/cards/card_enums.dart';
import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

enum ColorMode { includes, exact, atMost }

enum SearchGame { paper, arena, mtgo }

enum PriceCurrency { usd, eur }

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _oracleController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _manaCostController = TextEditingController();
  final TextEditingController _setController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _rawQueryController = TextEditingController();
  final TextEditingController _flavorController = TextEditingController();

  final Set<MTGColor> _selectedColors = {};
  final Set<MTGColor> _selectedCommanderColors = {};
  ColorMode _colorMode = ColorMode.includes;

  bool _showRawQueryField = false;

  final ScrollController _scrollController = ScrollController();
  int _resultsToShow = 20;

  // Price filtering controllers
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();

  PriceCurrency _selectedPriceCurrency = PriceCurrency.usd;

  final Set<SearchGame> _selectedGames = {};

  final RangeValues _cmc = const RangeValues(0, 16);
  RangeValues _power = const RangeValues(0, 12);
  RangeValues _toughness = const RangeValues(0, 12);
  RangeValues _loyalty = const RangeValues(0, 10);

  double? _usdMin;
  double? _usdMax;
  double? _eurMin;
  double? _eurMax;
  double? _tixMin;
  double? _tixMax;

  String? _selectedRarity;

  bool _isLoading = false;
  List<MTGCard> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          _resultsToShow < _searchResults.length) {
        setState(() {
          _resultsToShow = (_resultsToShow + 20).clamp(0, _searchResults.length);
        });
      }
    });

    _priceMinController.addListener(() {
      final value = double.tryParse(_priceMinController.text);
      if (_selectedPriceCurrency == PriceCurrency.usd) {
        _usdMin = value;
      } else {
        _eurMin = value;
      }
    });

    _priceMaxController.addListener(() {
      final value = double.tryParse(_priceMaxController.text);
      if (_selectedPriceCurrency == PriceCurrency.usd) {
        _usdMax = value;
      } else {
        _eurMax = value;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oracleController.dispose();
    _typeController.dispose();
    _manaCostController.dispose();
    _setController.dispose();
    _artistController.dispose();
    _languageController.dispose();
    _rawQueryController.dispose();
    _flavorController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final rawQuery = _rawQueryController.text.trim();
    final cardService = context.read<CardService>();

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _resultsToShow = 20;
    });

    // If the user entered a raw query, use it as-is. Otherwise build a
    // Scryfall advanced query from the UI fields.
    final query = rawQuery.isNotEmpty ? rawQuery : _buildAdvancedQuery();

    if (query.trim().isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final results = await cardService.searchCardsFromScryfallQuery(query);
    setState(() {
      _searchResults = results;
      _resultsToShow = 20;
      _isLoading = false;
    });
    _scrollController.jumpTo(0);
  }

  String _buildAdvancedQuery() {
    final parts = <String>[];

    final name = _nameController.text.trim();
    final oracle = _oracleController.text.trim();
    final type = _typeController.text.trim();
    final rawMana = _manaCostController.text.trim();
    final setCode = _setController.text.trim();
    final artist = _artistController.text.trim();
    final lang = _languageController.text.trim();
    final flavor = _flavorController.text.trim();

    if (name.isNotEmpty) {
      parts.add('name:"$name"');
    }
    if (oracle.isNotEmpty) {
      parts.add('o:"$oracle"');
    }
    if (type.isNotEmpty) {
      parts.add('t:"$type"');
    }

    if (rawMana.isNotEmpty) {
      parts.add('mana:"$rawMana"');
    }

    final minCmc = _cmc.start.round();
    final maxCmc = _cmc.end.round();
    if (minCmc > 0) {
      parts.add('cmc>=$minCmc');
    }
    if (maxCmc < 16) {
      parts.add('cmc<=$maxCmc');
    }

    if (_selectedColors.isNotEmpty) {
      final colors = _selectedColors.map((c) => c.symbol).join();
      switch (_colorMode) {
        case ColorMode.includes:
          parts.add('c:$colors');
          break;
        case ColorMode.exact:
          parts.add('c=$colors');
          break;
        case ColorMode.atMost:
          parts.add('c<=$colors');
          break;
      }
    }

    if (_selectedCommanderColors.isNotEmpty) {
      final colors = _selectedCommanderColors.map((c) => c.symbol).join();
      parts.add('ci<=$colors');
    }


    if (_selectedGames.isNotEmpty) {
      final games = _selectedGames.map((g) {
        switch (g) {
          case SearchGame.paper:
            return 'paper';
          case SearchGame.arena:
            return 'arena';
          case SearchGame.mtgo:
            return 'mtgo';
        }
      }).join(',');
      parts.add('games:$games');
    }

    if (setCode.isNotEmpty) {
      parts.add('set:$setCode');
    }

    if (_selectedRarity != null && _selectedRarity!.isNotEmpty) {
      parts.add('r:${_selectedRarity!.toLowerCase()}');
    }

    if (artist.isNotEmpty) {
      parts.add('artist:"$artist"');
    }

    if (lang.isNotEmpty) {
      parts.add('lang:$lang');
    }

    if (flavor.isNotEmpty) {
      parts.add('o:"$flavor"');
    }

    if (_usdMin != null) {
      parts.add('usd>=$_usdMin');
    }
    if (_usdMax != null) {
      parts.add('usd<=$_usdMax');
    }
    if (_eurMin != null) {
      parts.add('eur>=$_eurMin');
    }
    if (_eurMax != null) {
      parts.add('eur<=$_eurMax');
    }
    if (_tixMin != null) {
      parts.add('tix>=$_tixMin');
    }
    if (_tixMax != null) {
      parts.add('tix<=$_tixMax');
    }

    // Add numeric stats
    if (_power.start > 0) {
      parts.add('pow>=${_power.start.round()}');
    }
    if (_power.end < 12) {
      parts.add('pow<=${_power.end.round()}');
    }

    if (_toughness.start > 0) {
      parts.add('tou>=${_toughness.start.round()}');
    }
    if (_toughness.end < 12) {
      parts.add('tou<=${_toughness.end.round()}');
    }

    if (_loyalty.start > 0) {
      parts.add('loy>=${_loyalty.start.round()}');
    }
    if (_loyalty.end < 10) {
      parts.add('loy<=${_loyalty.end.round()}');
    }

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'Advanced Search',
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          const Text(
            'Use Scryfall advanced query syntax (see: scryfall.com/advanced)',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Raw advanced query',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showRawQueryField = !_showRawQueryField;
                  });
                },
                child: Text(_showRawQueryField ? 'Hide' : 'Show'),
              ),
            ],
          ),
          if (_showRawQueryField) ...[
            const SizedBox(height: 8),
            _buildSearchField(
              controller: _rawQueryController,
              label: 'Raw Advanced Query',
              hint: 'e.g. o:"draw a card" c:WU cmc<=3',
              maxLines: 2,
            ),
            const SizedBox(height: 24),
          ],
          if (!_showRawQueryField) ...[
            const SizedBox(height: 24),
          ],
          const Divider(),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _nameController,
            label: 'Card Name',
            hint: 'Enter card name...',
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _oracleController,
            label: 'Oracle Text',
            hint: 'Enter card text...',
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final all = context.read<CardService>().typeLineSuggestions;
              return all.where((s) => s
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              controller.text = _typeController.text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Type Line',
                  hintText: 'Enter card type...',
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              controller.clear();
                              _typeController.clear();
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _typeController.text = value;
                  });
                },
              );
            },
            onSelected: (selection) {
              _typeController.text = selection;
            },
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _manaCostController,
            label: 'Mana Cost',
            hint: 'eg. {2}{G}{G}',
          ),
          const SizedBox(height: 16),
          Text(
            'Color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DropdownButton<ColorMode>(
                value: _colorMode,
                items: const [
                  DropdownMenuItem(
                    value: ColorMode.includes,
                    child: Text('Includes'),
                  ),
                  DropdownMenuItem(
                    value: ColorMode.exact,
                    child: Text('Exactly'),
                  ),
                  DropdownMenuItem(
                    value: ColorMode.atMost,
                    child: Text('At most'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _colorMode = value;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: MTGColor.values.map((color) {
                    return FilterChip(
                      label: Text(color.displayName),
                      selected: _selectedColors.contains(color),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedColors.add(color);
                          } else {
                            _selectedColors.remove(color);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Commander Color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MTGColor.values.map((color) {
              return FilterChip(
                label: Text(color.displayName),
                selected: _selectedCommanderColors.contains(color),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCommanderColors.add(color);
                    } else {
                      _selectedCommanderColors.remove(color);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Games',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: SearchGame.values.map((game) {
              final label = () {
                switch (game) {
                  case SearchGame.paper:
                    return 'Paper';
                  case SearchGame.arena:
                    return 'Arena';
                  case SearchGame.mtgo:
                    return 'MTGO';
                }
              }();

              return FilterChip(
                label: Text(label),
                selected: _selectedGames.contains(game),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGames.add(game);
                    } else {
                      _selectedGames.remove(game);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final all = context.read<CardService>().setSuggestions;
              return all.where((s) => s
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              controller.text = _setController.text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Set / Block',
                  hintText: 'e.g. Zendikar',
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              controller.clear();
                              _setController.clear();
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _setController.text = value;
                  });
                },
              );
            },
            onSelected: (selection) {
              _setController.text = selection;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRarity,
            items: const [
              DropdownMenuItem(value: 'common', child: Text('Common')),
              DropdownMenuItem(value: 'uncommon', child: Text('Uncommon')),
              DropdownMenuItem(value: 'rare', child: Text('Rare')),
              DropdownMenuItem(value: 'mythic', child: Text('Mythic')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRarity = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Rarity',
            ),
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final all = context.read<CardService>().artistSuggestions;
              return all.where((s) => s
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              controller.text = _artistController.text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Artist',
                  hintText: 'e.g. Christopher Moeller',
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              controller.clear();
                              _artistController.clear();
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _artistController.text = value;
                  });
                },
              );
            },
            onSelected: (selection) {
              _artistController.text = selection;
            },
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final all = context.read<CardService>().languageSuggestions;
              return all.where((s) => s
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              controller.text = _languageController.text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Language',
                  hintText: 'e.g. en',
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              controller.clear();
                              _languageController.clear();
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _languageController.text = value;
                  });
                },
              );
            },
            onSelected: (selection) {
              _languageController.text = selection;
            },
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _flavorController,
            label: 'Flavor / Lore (fulltext)',
            hint: 'Search flavor text, rulings, etc',
          ),
          const SizedBox(height: 16),
          Text(
            'Price Filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DropdownButton<PriceCurrency>(
                value: _selectedPriceCurrency,
                items: const [
                  DropdownMenuItem(
                    value: PriceCurrency.usd,
                    child: Text('USD'),
                  ),
                  DropdownMenuItem(
                    value: PriceCurrency.eur,
                    child: Text('EUR'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriceCurrency = value;
                      _priceMinController.text = (value == PriceCurrency.usd
                              ? _usdMin
                              : _eurMin)
                          ?.toString() ?? '';
                      _priceMaxController.text = (value == PriceCurrency.usd
                              ? _usdMax
                              : _eurMax)
                          ?.toString() ?? '';
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _priceMinController,
                  decoration: InputDecoration(
                    labelText:
                        '${_selectedPriceCurrency.name.toUpperCase()} min',
                    hintText: '0.00',
                    suffixIcon: _priceMinController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _priceMinController.clear();
                                if (_selectedPriceCurrency ==
                                    PriceCurrency.usd) {
                                  _usdMin = null;
                                } else {
                                  _eurMin = null;
                                }
                              });
                            },
                          ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceMaxController,
                  decoration: InputDecoration(
                    labelText:
                        '${_selectedPriceCurrency.name.toUpperCase()} max',
                    hintText: '0.00',
                    suffixIcon: _priceMaxController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _priceMaxController.clear();
                                if (_selectedPriceCurrency ==
                                    PriceCurrency.usd) {
                                  _usdMax = null;
                                } else {
                                  _eurMax = null;
                                }
                              });
                            },
                          ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Power / Toughness / Loyalty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Power'),
          RangeSlider(
            values: _power,
            min: 0,
            max: 12,
            divisions: 12,
            labels: RangeLabels(
              _power.start.round().toString(),
              _power.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _power = values;
              });
            },
          ),
          Text('Toughness'),
          RangeSlider(
            values: _toughness,
            min: 0,
            max: 12,
            divisions: 12,
            labels: RangeLabels(
              _toughness.start.round().toString(),
              _toughness.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _toughness = values;
              });
            },
          ),
          Text('Loyalty'),
          RangeSlider(
            values: _loyalty,
            min: 0,
            max: 10,
            divisions: 10,
            labels: RangeLabels(
              _loyalty.start.round().toString(),
              _loyalty.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _loyalty = values;
              });
            },
          ),
          const SizedBox(height: 24),
          if (_searchResults.isNotEmpty) ...[
            Text(
              'Results (${_searchResults.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.715,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: math.min(_searchResults.length, _resultsToShow),
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
                                  color: Color(0xFF2A2A2A),
                                ),
                              ),
                      ),
                      if (card.gameChanger)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF0000),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(2),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'GC',
                                style: TextStyle(
                                  color: Colors.white,
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
            if (_resultsToShow < _searchResults.length)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ]
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _performSearch,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Search'),
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        controller.clear();
                      });
                    },
                  ),
          ),
          style: const TextStyle(color: Color(0xFFF5F5F5)),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}