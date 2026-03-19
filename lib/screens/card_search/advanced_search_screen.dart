import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/app_bar.dart';
import '../../widgets/card_zoom_view.dart';
import '../../models/cards/card_enums.dart';
import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';
import '../../services/set_service.dart';
import '../../services/symbol_service.dart';
import '../../services/user_preferences_service.dart';
import '../navigation/navigation_screen.dart';
import '../../widgets/card_badges_overlay.dart';
import '../../widgets/flip_animated_image.dart';
import '../../widgets/mana_symbol_label.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

enum ColorMode { includes, exact, atMost }

enum SearchGame { paper, arena, mtgo }

enum PriceCurrency { usd, eur }

class _SetOption {
  final String code;
  final String name;
  final String? iconSvg;

  const _SetOption({
    required this.code,
    required this.name,
    this.iconSvg,
  });
}

const List<String> _baseManaTokens = ['{W}', '{U}', '{B}', '{R}', '{G}', '{C}'];
const List<String> _hybridManaTokens = [
  '{W/U}',
  '{W/B}',
  '{U/B}',
  '{U/R}',
  '{B/R}',
  '{B/G}',
  '{R/G}',
  '{R/W}',
  '{G/W}',
  '{G/U}',
  '{2/W}',
  '{2/U}',
  '{2/B}',
  '{2/R}',
  '{2/G}',
  '{W/P}',
  '{U/P}',
  '{B/P}',
  '{R/P}',
  '{G/P}',
];

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  static const String _persistedStateKey = 'advanced_search_filter_state';

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
  bool _lockCommanderColorToSelectedCommander = false;
  ColorMode _colorMode = ColorMode.includes;
  bool _exactManaCost = false;
  bool _showHybridMana = false;

  bool _showRawQueryField = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultsSectionKey = GlobalKey();
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

  final Set<String> _selectedRarities = {};

  bool _isLoading = false;
  bool _showArtCropOnly = false;
  List<MTGCard> _searchResults = [];
  final Set<String> _flippedCardIds = <String>{};
  CardService? _cardService;
  SetService? _setService;
  UserPreferencesService? _userPreferencesService;
  List<String> _lastCommanderIds = const [];

  bool _isFlipped(MTGCard card) => _flippedCardIds.contains(card.id);

  void _toggleFlipped(MTGCard card) {
    if (!card.hasDoubleFacedImages) return;
    setState(() {
      if (!_flippedCardIds.add(card.id)) {
        _flippedCardIds.remove(card.id);
      }
    });
  }

  String? _displayArtImage(MTGCard card) {
    if (!card.hasDoubleFacedImages) {
      return card.mainFaceArtCropUrl ?? card.mainFaceImageUrl;
    }

    if (_isFlipped(card)) {
      return card.backFaceArtCropUrl ??
          card.backFaceImageUrl ??
          card.mainFaceArtCropUrl ??
          card.mainFaceImageUrl;
    }

    return card.mainFaceArtCropUrl ??
        card.mainFaceImageUrl ??
        card.backFaceArtCropUrl ??
        card.backFaceImageUrl;
  }

  String? _displayNormalImage(MTGCard card) {
    if (!card.hasDoubleFacedImages) {
      return card.mainFaceImageUrl;
    }

    if (_isFlipped(card)) {
      return card.backFaceImageUrl ?? card.mainFaceImageUrl;
    }

    return card.mainFaceImageUrl ?? card.backFaceImageUrl;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPersistedStateIfEnabled());
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          _resultsToShow < _searchResults.length) {
        setState(() {
          _resultsToShow =
              (_resultsToShow + 20).clamp(0, _searchResults.length);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextCardService = context.read<CardService>();
    final nextSetService = context.read<SetService>();
    final nextUserPreferencesService = context.read<UserPreferencesService>();

    if (!identical(_cardService, nextCardService)) {
      _cardService?.removeListener(_handleCommanderSelectionChanged);
      _cardService = nextCardService;
      _cardService?.addListener(_handleCommanderSelectionChanged);
      _syncCommanderLockFromSelection();
    }

    if (!identical(_userPreferencesService, nextUserPreferencesService)) {
      _userPreferencesService = nextUserPreferencesService;
    }

    if (!identical(_setService, nextSetService)) {
      _setService = nextSetService;
    }
  }

  String _resolveSetCodeForQuery(String rawInput) {
    final value = rawInput.trim();
    if (value.isEmpty) return value;

    final trailingCodeMatch = RegExp(r'\(([a-zA-Z0-9]+)\)\s*$')
        .firstMatch(value);
    if (trailingCodeMatch != null) {
      final matched = trailingCodeMatch.group(1);
      if (matched != null && matched.isNotEmpty) {
        return matched.toLowerCase();
      }
    }

    final sets = _setService?.sets ?? const [];
    final lower = value.toLowerCase();
    for (final set in sets) {
      if (set.code == lower || set.name.toLowerCase() == lower) {
        return set.code;
      }
    }

    return value;
  }

  @override
  void dispose() {
    final snapshot = _buildPersistedStateSnapshot();
    final persistentFiltersEnabled =
        _userPreferencesService?.persistentFiltersEnabled ?? false;
    if (persistentFiltersEnabled) {
      unawaited(_saveStateIfEnabled(snapshot: snapshot));
    } else {
      unawaited(_clearPersistedState());
    }
    _cardService?.removeListener(_handleCommanderSelectionChanged);
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

  Future<void> _loadPersistedStateIfEnabled() async {
    final prefsService =
        _userPreferencesService ?? context.read<UserPreferencesService>();
    if (!prefsService.persistentFiltersEnabled) {
      await _clearPersistedState();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_persistedStateKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = json.decode(raw);
      if (data is! Map<String, dynamic>) return;

      setState(() {
        _nameController.text = data['name'] as String? ?? '';
        _oracleController.text = data['oracle'] as String? ?? '';
        _typeController.text = data['type'] as String? ?? '';
        _manaCostController.text = data['manaCost'] as String? ?? '';
        _setController.text = data['set'] as String? ?? '';
        _artistController.text = data['artist'] as String? ?? '';
        _languageController.text = data['language'] as String? ?? '';
        _rawQueryController.text = data['rawQuery'] as String? ?? '';
        _flavorController.text = data['flavor'] as String? ?? '';
        _showRawQueryField = data['showRawQueryField'] as bool? ?? false;
        _showHybridMana = data['showHybridMana'] as bool? ?? false;
        _exactManaCost = data['exactManaCost'] as bool? ?? false;

        final colorMode = data['colorMode'] as String?;
        _colorMode = ColorMode.values.firstWhere(
          (value) => value.name == colorMode,
          orElse: () => ColorMode.includes,
        );

        _selectedColors
          ..clear()
          ..addAll(
            (data['selectedColors'] as List? ?? const [])
                .whereType<String>()
                .map(
                  (symbol) => MTGColor.values.firstWhere(
                    (c) => c.symbol == symbol,
                    orElse: () => MTGColor.colorless,
                  ),
                ),
          );

        _selectedCommanderColors
          ..clear()
          ..addAll(
            (data['selectedCommanderColors'] as List? ?? const [])
                .whereType<String>()
                .map(
                  (symbol) => MTGColor.values.firstWhere(
                    (c) => c.symbol == symbol,
                    orElse: () => MTGColor.colorless,
                  ),
                ),
          );

        _lockCommanderColorToSelectedCommander =
            data['lockCommanderColorToSelectedCommander'] as bool? ?? false;

        _selectedGames
          ..clear()
          ..addAll(
            (data['selectedGames'] as List? ?? const [])
                .whereType<String>()
                .map(
                  (name) => SearchGame.values.firstWhere(
                    (g) => g.name == name,
                    orElse: () => SearchGame.paper,
                  ),
                ),
          );

        _selectedRarities
          ..clear()
          ..addAll(
            (data['selectedRarities'] as List? ?? const [])
                .whereType<String>()
                .map((r) => r.toLowerCase()),
          );

        _selectedPriceCurrency = PriceCurrency.values.firstWhere(
          (value) => value.name == (data['selectedPriceCurrency'] as String?),
          orElse: () => PriceCurrency.usd,
        );

        _usdMin = (data['usdMin'] as num?)?.toDouble();
        _usdMax = (data['usdMax'] as num?)?.toDouble();
        _eurMin = (data['eurMin'] as num?)?.toDouble();
        _eurMax = (data['eurMax'] as num?)?.toDouble();
        _tixMin = (data['tixMin'] as num?)?.toDouble();
        _tixMax = (data['tixMax'] as num?)?.toDouble();

        _power = RangeValues(
          (data['powerStart'] as num?)?.toDouble() ?? 0,
          (data['powerEnd'] as num?)?.toDouble() ?? 12,
        );
        _toughness = RangeValues(
          (data['toughnessStart'] as num?)?.toDouble() ?? 0,
          (data['toughnessEnd'] as num?)?.toDouble() ?? 12,
        );
        _loyalty = RangeValues(
          (data['loyaltyStart'] as num?)?.toDouble() ?? 0,
          (data['loyaltyEnd'] as num?)?.toDouble() ?? 10,
        );

        _priceMinController.text =
            (_selectedPriceCurrency == PriceCurrency.usd ? _usdMin : _eurMin)
                    ?.toString() ??
                '';
        _priceMaxController.text =
            (_selectedPriceCurrency == PriceCurrency.usd ? _usdMax : _eurMax)
                    ?.toString() ??
                '';
      });
    } catch (_) {
      // Ignore invalid persisted state and continue with defaults.
    }
  }

  Map<String, dynamic> _buildPersistedStateSnapshot() {
    return <String, dynamic>{
      'name': _nameController.text,
      'oracle': _oracleController.text,
      'type': _typeController.text,
      'manaCost': _manaCostController.text,
      'set': _setController.text,
      'artist': _artistController.text,
      'language': _languageController.text,
      'rawQuery': _rawQueryController.text,
      'flavor': _flavorController.text,
      'showRawQueryField': _showRawQueryField,
      'showHybridMana': _showHybridMana,
      'exactManaCost': _exactManaCost,
      'colorMode': _colorMode.name,
      'selectedColors': _selectedColors.map((c) => c.symbol).toList(),
      'selectedCommanderColors':
          _selectedCommanderColors.map((c) => c.symbol).toList(),
      'lockCommanderColorToSelectedCommander':
          _lockCommanderColorToSelectedCommander,
      'selectedGames': _selectedGames.map((g) => g.name).toList(),
      'selectedRarities': _selectedRarities.toList(),
      'selectedPriceCurrency': _selectedPriceCurrency.name,
      'usdMin': _usdMin,
      'usdMax': _usdMax,
      'eurMin': _eurMin,
      'eurMax': _eurMax,
      'tixMin': _tixMin,
      'tixMax': _tixMax,
      'powerStart': _power.start,
      'powerEnd': _power.end,
      'toughnessStart': _toughness.start,
      'toughnessEnd': _toughness.end,
      'loyaltyStart': _loyalty.start,
      'loyaltyEnd': _loyalty.end,
    };
  }

  Future<void> _saveStateIfEnabled({Map<String, dynamic>? snapshot}) async {
    final prefsService = _userPreferencesService;
    if (prefsService == null) return;
    if (!prefsService.persistentFiltersEnabled) {
      await _clearPersistedState();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final state = snapshot ?? _buildPersistedStateSnapshot();
    await prefs.setString(_persistedStateKey, json.encode(state));
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistedStateKey);
  }

  Widget _buildPersistentFiltersBanner() {
    return Consumer<UserPreferencesService>(
      builder: (context, preferences, _) {
        if (!preferences.persistentFiltersEnabled) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
    final lockedCommanderColors =
        _colorsFromIdentity(cardService.selectedCommanderIdentity);

    void apply() {
      _lockCommanderColorToSelectedCommander = commanderIds.isNotEmpty;
      _selectedCommanderColors
        ..clear()
        ..addAll(lockedCommanderColors);
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  bool _sameStringLists(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _appendManaSymbol(String token) {
    final current = _manaCostController.text;
    final selection = _manaCostController.selection;

    if (!selection.isValid) {
      _manaCostController.text = '$current$token';
      _manaCostController.selection = TextSelection.fromPosition(
        TextPosition(offset: _manaCostController.text.length),
      );
      setState(() {});
      return;
    }

    final start = selection.start.clamp(0, current.length);
    final end = selection.end.clamp(0, current.length);
    final replaced = current.replaceRange(start, end, token);

    _manaCostController.text = replaced;
    _manaCostController.selection = TextSelection.collapsed(
      offset: start + token.length,
    );
    setState(() {});
  }

  Future<void> _performSearch() async {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_saveStateIfEnabled());

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
      unawaited(_saveStateIfEnabled());
      return;
    }

    final results = await cardService.searchCardsFromScryfallQuery(query);
    setState(() {
      _searchResults = results;
      _resultsToShow = 20;
      _isLoading = false;
    });
    unawaited(_saveStateIfEnabled());

    // Move the viewport to the results section after each search.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contextForResults = _resultsSectionKey.currentContext;
      if (contextForResults != null) {
        Scrollable.ensureVisible(
          contextForResults,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.02,
        );
      }
    });
  }

  String _buildAdvancedQuery() {
    final parts = <String>[];
    final cardService = context.read<CardService>();
    final effectiveCommanderColors = _lockCommanderColorToSelectedCommander
        ? _colorsFromIdentity(cardService.selectedCommanderIdentity)
        : _selectedCommanderColors;

    final name = _nameController.text.trim();
    final oracle = _oracleController.text.trim();
    final type = _typeController.text.trim();
    final rawMana = _manaCostController.text.trim();
    final setInput = _setController.text.trim();
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
      if (_exactManaCost) {
        parts.add('mana=$rawMana');
      } else {
        parts.add('mana:"$rawMana"');
      }
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

    if (effectiveCommanderColors.isNotEmpty) {
      final colors = effectiveCommanderColors.map((c) => c.symbol).join();
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

    final setCode = _resolveSetCodeForQuery(setInput);
    if (setCode.isNotEmpty) {
      parts.add('set:$setCode');
    }

    if (_selectedRarities.isNotEmpty) {
      for (final rarity in _selectedRarities) {
        parts.add('r:${rarity.toLowerCase()}');
      }
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

  Set<MTGColor> _colorsFromIdentity(List<String> identity) {
    return identity
        .map((symbol) =>
            MTGColor.values.where((c) => c.symbol == symbol).firstOrNull)
        .whereType<MTGColor>()
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'Advanced Search',
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _buildPersistentFiltersBanner(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showRawQueryField = !_showRawQueryField;
                      });
                    },
                    child: Text(
                      _showRawQueryField ? 'Hide' : 'Use advanced query',
                    ),
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
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
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
              const SizedBox(height: 8),
              Text(
                'Tap symbols to add mana cost',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _baseManaTokens.map((token) {
                  return _ManaSymbolInputButton(
                    token: token,
                    onPressed: () => _appendManaSymbol(token),
                  );
                }).toList(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showHybridMana = !_showHybridMana;
                    });
                  },
                  icon: Icon(
                      _showHybridMana ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showHybridMana
                      ? 'Hide hybrid mana'
                      : 'Show hybrid mana'),
                ),
              ),
              if (_showHybridMana)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hybridManaTokens.map((token) {
                    return _ManaSymbolInputButton(
                      token: token,
                      onPressed: () => _appendManaSymbol(token),
                    );
                  }).toList(),
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exact cost'),
                subtitle: const Text('Match full mana cost exactly'),
                value: _exactManaCost,
                onChanged: (value) {
                  setState(() {
                    _exactManaCost = value;
                  });
                },
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
                          label: ManaSymbolLabel(color: color),
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
              Consumer<CardService>(
                builder: (context, cardService, _) {
                  final selectedCommanders = cardService.selectedCommanders;
                  final lockedCommanderColors = _colorsFromIdentity(
                    cardService.selectedCommanderIdentity,
                  );
                  final displayedCommanderColors =
                      _lockCommanderColorToSelectedCommander
                          ? lockedCommanderColors
                          : _selectedCommanderColors;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commander Color',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('Lock to currently selected commander'),
                        subtitle: Text(
                          selectedCommanders.isNotEmpty
                              ? cardService.selectedCommanderNames
                              : 'No commander selected on the Daily page',
                        ),
                        value: _lockCommanderColorToSelectedCommander &&
                            selectedCommanders.isNotEmpty,
                        onChanged: selectedCommanders.isEmpty
                            ? null
                            : (selected) {
                                setState(() {
                                  _lockCommanderColorToSelectedCommander =
                                      selected;
                                  if (selected) {
                                    _selectedCommanderColors
                                      ..clear()
                                      ..addAll(lockedCommanderColors);
                                  }
                                });
                              },
                      ),
                      if (selectedCommanders.isNotEmpty) ...[
                        _SelectedCommanderPreview(cards: selectedCommanders),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        children: MTGColor.values.map((color) {
                          return FilterChip(
                            label: ManaSymbolLabel(color: color),
                            selected: displayedCommanderColors.contains(color),
                            onSelected: _lockCommanderColorToSelectedCommander
                                ? null
                                : (selected) {
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
                    ],
                  );
                },
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
              Autocomplete<_SetOption>(
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  final setService = context.read<SetService>();
                  final sets = setService.sets;

                  if (sets.isEmpty) {
                    return const Iterable<_SetOption>.empty();
                  }

                  final filtered = sets.where((set) {
                    if (query.isEmpty) return true;
                    return set.name.toLowerCase().contains(query) ||
                        set.code.toLowerCase().contains(query);
                  });

                  return filtered
                      .take(40)
                      .map((set) => _SetOption(
                            code: set.code,
                            name: set.name,
                            iconSvg: setService.iconSvgBySetCode(set.code),
                          ));
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  controller.text = _setController.text;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length),
                  );
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Set / Block',
                      hintText: 'e.g. Zendikar or khm',
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
                optionsViewBuilder: (context, onSelected, options) {
                  final rendered = options.toList(growable: false);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 280,
                          maxWidth: 420,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: rendered.length,
                          itemBuilder: (context, index) {
                            final option = rendered[index];
                            return ListTile(
                              dense: true,
                              leading: option.iconSvg == null
                                  ? const Icon(Icons.style)
                                  : SvgPicture.string(
                                      option.iconSvg!,
                                      width: 18,
                                      height: 18,
                                    ),
                              title: Text(option.name),
                              subtitle: Text(option.code.toUpperCase()),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                onSelected: (selection) {
                  _setController.text =
                      '${selection.name} (${selection.code.toUpperCase()})';
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Rarity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select multiple rarities. None selected means all rarities.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const ['common', 'uncommon', 'rare', 'mythic']
                    .map((rarity) {
                  return rarity;
                }).map((rarity) {
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RarityDot(rarity: rarity),
                        const SizedBox(width: 6),
                        Text(_rarityLabel(rarity)),
                      ],
                    ),
                    selected: _selectedRarities.contains(rarity),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRarities.add(rarity);
                        } else {
                          _selectedRarities.remove(rarity);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final all = context.read<CardService>().artistSuggestions;
                  return all.where((s) => s
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
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
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
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
                          _priceMinController.text =
                              (value == PriceCurrency.usd ? _usdMin : _eurMin)
                                      ?.toString() ??
                                  '';
                          _priceMaxController.text =
                              (value == PriceCurrency.usd ? _usdMax : _eurMax)
                                      ?.toString() ??
                                  '';
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
                SizedBox(key: _resultsSectionKey),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Results (${_searchResults.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Text('Art crop only'),
                    Switch.adaptive(
                      value: _showArtCropOnly,
                      onChanged: (value) {
                        setState(() {
                          _showArtCropOnly = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_showArtCropOnly)
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: math.min(_searchResults.length, _resultsToShow),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final card = _searchResults[index];
                      final artImage = _displayArtImage(card);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () {
                                if (_displayNormalImage(card) != null) {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      opaque: false,
                                      pageBuilder: (context, _, __) =>
                                          CardZoomView(
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
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: FlipAnimatedImage(
                                  imageUrl: artImage,
                                  isFlipped: _isFlipped(card),
                                  fit: BoxFit.cover,
                                  placeholder: Image.asset(
                                    'assets/images/Magic_card_back.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            CardBadgesOverlay(
                              hasDoubleFacedImages: card.hasDoubleFacedImages,
                              isBanned:
                                  card.legalities['commander'] == 'banned',
                              isGameChanger: card.gameChanger,
                              density: CardBadgeDensity.large,
                              onDoubleFacedTap: () => _toggleFlipped(card),
                              isDoubleFacedFlipped: _isFlipped(card),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.715,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: math.min(_searchResults.length, _resultsToShow),
                    itemBuilder: (context, index) {
                      final card = _searchResults[index];
                      final imageUrl = _displayNormalImage(card);
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
                                      pageBuilder: (context, _, __) =>
                                          CardZoomView(
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
                              isBanned:
                                  card.legalities['commander'] == 'banned',
                              isGameChanger: card.gameChanger,
                              onDoubleFacedTap: () => _toggleFlipped(card),
                              isDoubleFacedFlipped: _isFlipped(card),
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
        ),
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

class _SelectedCommanderPreview extends StatelessWidget {
  final List<MTGCard> cards;

  const _SelectedCommanderPreview({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            _SelectedCommanderPreviewTile(
              card: cards[i],
              label: i == 0
                  ? 'Commander'
                  : (cards[i].isBackgroundCommanderCard
                      ? 'Background'
                      : 'Partner'),
            ),
            if (i < cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SelectedCommanderPreviewTile extends StatelessWidget {
  final MTGCard card;
  final String label;

  const _SelectedCommanderPreviewTile({
    required this.card,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final manaCost = card.manaCost ??
        ((card.cardFaces != null && card.cardFaces!.isNotEmpty)
            ? card.cardFaces!.first.manaCost
            : null);
    final identityTokens =
        (card.colorIdentity == null || card.colorIdentity!.isEmpty)
            ? const ['{C}']
            : card.colorIdentity!.map((symbol) => '{$symbol}').toList();

    return Row(
      children: [
        if (card.imageUris?.artCrop != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              card.imageUris!.artCrop!,
              width: 68,
              height: 48,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 68,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.image_not_supported, color: Colors.white54),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (manaCost != null && manaCost.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InlineManaTokenWrap(
                  tokens: _parseManaTokens(manaCost),
                  iconSize: 16,
                ),
              ],
              const SizedBox(height: 4),
              _InlineManaTokenWrap(
                tokens: identityTokens,
                iconSize: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineManaTokenWrap extends StatelessWidget {
  final List<String> tokens;
  final double iconSize;

  const _InlineManaTokenWrap({
    required this.tokens,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final token in tokens)
          _StaticManaSymbol(
            token: token,
            size: iconSize,
          ),
      ],
    );
  }
}

class _StaticManaSymbol extends StatelessWidget {
  final String token;
  final double size;

  const _StaticManaSymbol({required this.token, required this.size});

  @override
  Widget build(BuildContext context) {
    final symbolService = context.watch<SymbolService>();
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
        color: Colors.white10,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        token.replaceAll('{', '').replaceAll('}', ''),
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

List<String> _parseManaTokens(String value) {
  final tokens = <String>[];
  var current = StringBuffer();
  var inside = false;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == '{') {
      inside = true;
      current = StringBuffer()..write(char);
      continue;
    }
    if (inside) {
      current.write(char);
      if (char == '}') {
        tokens.add(current.toString());
        inside = false;
        current = StringBuffer();
      }
    }
  }

  return tokens;
}

class _ManaSymbolInputButton extends StatelessWidget {
  final String token;
  final VoidCallback onPressed;

  const _ManaSymbolInputButton({
    required this.token,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final symbolService = context.watch<SymbolService>();
    final svgData = symbolService.svgDataByToken(token);

    if (svgData == null || svgData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        symbolService.requestRefreshOnMiss(token);
      });
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
          color: Colors.white10,
        ),
        child: svgData != null && svgData.isNotEmpty
            ? SvgPicture.string(
                svgData,
                width: 20,
                height: 20,
              )
            : Text(
                token.replaceAll('{', '').replaceAll('}', ''),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

String _rarityLabel(String rarity) {
  switch (rarity) {
    case 'common':
      return 'Common';
    case 'uncommon':
      return 'Uncommon';
    case 'rare':
      return 'Rare';
    case 'mythic':
      return 'Mythic';
    default:
      return rarity;
  }
}

class _RarityDot extends StatelessWidget {
  final String rarity;

  const _RarityDot({required this.rarity});

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;

    switch (rarity) {
      case 'common':
        decoration = const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        );
        break;
      case 'uncommon':
        decoration = BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        );
        break;
      case 'rare':
        decoration = const BoxDecoration(
          color: Color(0xFFD4AF37),
          shape: BoxShape.circle,
        );
        break;
      case 'mythic':
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFD180),
              Color(0xFFFF8C00),
              Color(0xFFFF6D00),
            ],
          ),
        );
        break;
      default:
        decoration = const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: decoration,
    );
  }
}
