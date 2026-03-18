import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cards/mtg_card.dart';
import '../models/service/bulk_data.dart';
import '../models/filters/filter_settings.dart';

class CardService extends ChangeNotifier {
  bool _isLoading = false;
  MTGCard? _dailyRegularCard;
  MTGCard? _dailyGameChangerCard;
  MTGCard? _dailyRegularLand;
  MTGCard? _dailyGameChangerLand;
  List<MTGCard> _allCards = [];
  List<MTGCard> _dailySuggestionCards = [];
  List<MTGCard> _selectedCommanders = [];

  String? _dailyAppBarCardId;

  bool get isLoading => _isLoading;
  MTGCard? get dailyRegularCard => _dailyRegularCard;
  MTGCard? get dailyGameChangerCard => _dailyGameChangerCard;
  MTGCard? get dailyRegularLand => _dailyRegularLand;
  MTGCard? get dailyGameChangerLand => _dailyGameChangerLand;
  List<MTGCard> get dailySuggestionCards => _dailySuggestionCards;
  List<MTGCard> get allCards => List.unmodifiable(_allCards);
  List<MTGCard> get selectedCommanders => List.unmodifiable(_selectedCommanders);
  MTGCard? get selectedCommander =>
      _selectedCommanders.isEmpty ? null : _selectedCommanders.first;
  MTGCard? get selectedCommanderPartner =>
      _selectedCommanders.length > 1 ? _selectedCommanders[1] : null;
  List<String> get selectedCommanderIdentity {
    final colors = <String>{};
    for (final card in _selectedCommanders) {
      colors.addAll(card.colorIdentity ?? const <String>[]);
    }
    return colors.toList()..sort();
  }
  String get selectedCommanderNames => _selectedCommanders.map((c) => c.name).join(' + ');

  /// All cards in the local dataset that are marked as Game Changers.
  List<MTGCard> get allGameChangerCards =>
      _allCards.where((c) => c.gameChanger).toList();

  /// All cards in the local dataset that are banned in Commander.
  List<MTGCard> get allBannedCards =>
      _allCards.where((c) => c.legalities['commander'] == 'banned').toList();

  /// The card currently used as the app bar background across all screens.
  ///
  /// This is persisted to SharedPreferences so it stays consistent between
  /// app restarts (until a new daily suggestion list is generated).
  MTGCard? get dailyAppBarCard {
    if (_dailyAppBarCardId != null) {
      try {
        return _dailySuggestionCards
            .firstWhere((card) => card.id == _dailyAppBarCardId);
      } catch (_) {
        // Fallback if the stored card isn't in today's suggestion list.
      }
    }

    // Fall back to the standard daily cards if we don't have a selected app bar card.
    return _dailyRegularCard ??
        _dailyGameChangerCard ??
        _dailyRegularLand ??
        _dailyGameChangerLand;
  }

  static const String _lastUpdateKey = 'LastCardDataUpdate';
  static const String _dailyCardDateKey = 'LastDailyCardDate';
  static const String _regularCardKey = 'DailyRegularCard';
  static const String _gameChangerCardKey = 'DailyGameChangerCard';
  static const String _regularLandKey = 'DailyRegularLand';
  static const String _gameChangerLandKey = 'DailyGameChangerLand';
  static const String _appBarCardKey = 'DailyAppBarCardId';
  static const String _selectedCommanderKey = 'SelectedCommander';

  Future<void> loadInitialData(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {

    _isLoading = true;
    notifyListeners();

    try {
      // Fast path: load already-saved daily cards first so home can render
      // immediately without waiting for full card dataset parsing.
      await _loadSavedDailyCards();

      if (_selectedCommanders.isNotEmpty) {
        final identity = selectedCommanderIdentity;
        nonLandFilters.lockToCommanderIdentity(identity);
        landFilters.lockToCommanderIdentity(identity);
      }

      final shouldGenerateDaily = await _shouldGenerateNewDailyCards();

      if (shouldGenerateDaily) {
        await _ensureCardDataLoadedForStartup();
        await generateDailyCards(nonLandFilters, landFilters);
      } else {
        // We already loaded saved daily cards above. Keep startup snappy and
        // warm/update card data in background for search screens.
        unawaited(_ensureCardDataLoadedForStartup());
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureCardDataLoadedForStartup() async {
    final shouldUpdateCards = await _shouldUpdateCardData();

    if (shouldUpdateCards || _allCards.isEmpty) {
      await _downloadCardData();
    } else {
      await _loadLocalCardData();
    }
  }

  Future<void> refreshDailyCards(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {
    await generateDailyCards(nonLandFilters, landFilters);
  }

  /// Ensures the local card catalog is loaded for screens that depend on
  /// [_allCards] but do not run the full daily-card initialization flow.
  Future<void> ensureCardCatalogLoaded() async {
    if (_allCards.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _ensureCardDataLoadedForStartup();
    } catch (e) {
      debugPrint('Error ensuring card catalog is loaded: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the card used for app bar backgrounds across the app.
  ///
  /// This is persisted so the same card remains visible after restarting the app
  /// until the daily suggestions update.
  Future<void> setDailyAppBarCard(MTGCard? card) async {
    _dailyAppBarCardId = card?.id;
    await _saveAppBarCardId();
    notifyListeners();
  }

  Future<void> setSelectedCommanders(List<MTGCard> cards) async {
    _selectedCommanders = _sanitizeSelectedCommanders(cards);
    await _saveSelectedCommanders();
    notifyListeners();
  }

  Future<void> _saveSelectedCommanders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedCommanders.isNotEmpty) {
        await prefs.setString(
          _selectedCommanderKey,
          json.encode(_selectedCommanders.map((c) => c.toJson()).toList()),
        );
      } else {
        await prefs.remove(_selectedCommanderKey);
      }
    } catch (e) {
        debugPrint('Error saving selected commanders: $e');
    }
  }

  /// Returns commander-legal cards whose name contains [query].
  /// A card qualifies if its type line includes "Legendary Creature" or its
  /// oracle text contains "can be your commander".
  List<MTGCard> searchCommanders(String query) {
    if (_allCards.isEmpty) return [];
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    return _allCards.where((card) {
      if (!card.canBePrimaryCommander) return false;
      return card.name.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<MTGCard> _sanitizeSelectedCommanders(Iterable<MTGCard> cards) {
    final selected = List<MTGCard>.from(cards.take(2));
    if (selected.length == 1 && selected.first.isBackgroundCommanderCard) {
      return [];
    }
    return selected;
  }

  Future<void> _saveAppBarCardId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dailyAppBarCardId != null) {
        await prefs.setString(_appBarCardKey, _dailyAppBarCardId!);
      } else {
        await prefs.remove(_appBarCardKey);
      }
    } catch (e) {
      debugPrint('Error saving app bar card id: $e');
    }
  }

  /// Searches cards using the local cache.
  ///
  /// If you want to use Scryfall's advanced search syntax, call
  /// [searchCardsFromScryfallQuery] instead.
  List<MTGCard> searchCards(String query) {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return _allCards.where((card) {
      final name = card.name.toLowerCase();
      final text = card.oracleText?.toLowerCase() ?? '';
      final typeLine = card.typeLine?.toLowerCase() ?? '';

      return name.contains(normalizedQuery) ||
          text.contains(normalizedQuery) ||
          typeLine.contains(normalizedQuery);
    }).toList();
  }

  /// Searches cards using a Scryfall-style query syntax (see https://scryfall.com/advanced).
  ///
  /// This is performed entirely using the local cached card data, so it works
  /// offline and will not make network requests once the bulk dataset has been
  /// downloaded.
  Future<List<MTGCard>> searchCardsFromScryfallQuery(String query) async {
    if (query.trim().isEmpty) return [];

    // Ensure we have local data first.
    if (_allCards.isEmpty) {
      await _loadLocalCardData();
    }

    // If we still don't have any local cards, we can't do a local search.
    if (_allCards.isEmpty) {
      return [];
    }

    try {
      final parsed = _parseScryfallQuery(query);
      // Advanced search intentionally includes banned cards (they get a BAN badge in the UI).
      return _filterCardsByParsedQuery(parsed);
    } catch (e) {
      debugPrint('Failed to parse advanced query: $e');
      return [];
    }
  }

  _AdvancedQuery _parseScryfallQuery(String query) {
    final tokens = _tokenizeScryfallQuery(query);

    final parsed = _AdvancedQuery();

    for (final token in tokens) {
      if (token.isEmpty) continue;

      // Negative tokens (e.g. -t:creature)
      final isNegation = token.startsWith('-');
      final content = isNegation ? token.substring(1) : token;

      if (content.startsWith('name:')) {
        parsed.name = _unquote(content.substring(5));
        parsed.nameNegated = isNegation;
        continue;
      }
      if (content.startsWith('o:')) {
        parsed.oracleText = _unquote(content.substring(2));
        parsed.oracleNegated = isNegation;
        continue;
      }
      if (content.startsWith('t:')) {
        parsed.typeLine = _unquote(content.substring(2));
        parsed.typeNegated = isNegation;
        continue;
      }
      if (content.startsWith('mana:')) {
        parsed.manaCost = _unquote(content.substring(5));
        parsed.manaNegated = isNegation;
        continue;
      }
      if (content.startsWith('mana=')) {
        parsed.manaCostExact = _unquote(content.substring(5));
        parsed.manaNegated = isNegation;
        continue;
      }
      if (content.startsWith('c=')) {
        parsed.colorIdentityExact = content.substring(2);
        parsed.colorNegated = isNegation;
        continue;
      }
      if (content.startsWith('c<=')) {
        parsed.colorIdentityAtMost = content.substring(3);
        parsed.colorNegated = isNegation;
        continue;
      }
      if (content.startsWith('c:')) {
        parsed.colorIdentity = content.substring(2);
        parsed.colorNegated = isNegation;
        continue;
      }
      if (content.startsWith('ci<=')) {
        parsed.commanderIdentityAtMost = content.substring(4);
        parsed.commanderNegated = isNegation;
        continue;
      }
      if (content.startsWith('ci=')) {
        parsed.commanderIdentityExact = content.substring(3);
        parsed.commanderNegated = isNegation;
        continue;
      }
      if (content.startsWith('ci:')) {
        parsed.commanderIdentity = content.substring(3);
        parsed.commanderNegated = isNegation;
        continue;
      }
      if (content.startsWith('cmc>=')) {
        parsed.cmcMin = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('cmc<=')) {
        parsed.cmcMax = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('cmc>')) {
        parsed.cmcMin = double.tryParse(content.substring(4))?.toDouble();
        if (parsed.cmcMin != null) parsed.cmcMin = parsed.cmcMin! + 0.0001;
        continue;
      }
      if (content.startsWith('cmc<')) {
        parsed.cmcMax = double.tryParse(content.substring(4))?.toDouble();
        if (parsed.cmcMax != null) parsed.cmcMax = parsed.cmcMax! - 0.0001;
        continue;
      }
      if (content.startsWith('pow>=')) {
        parsed.powerMin = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('pow<=')) {
        parsed.powerMax = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('tou>=')) {
        parsed.toughnessMin = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('tou<=')) {
        parsed.toughnessMax = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('loy>=')) {
        parsed.loyaltyMin = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('loy<=')) {
        parsed.loyaltyMax = double.tryParse(content.substring(5));
        continue;
      }
      if (content.startsWith('set:')) {
        parsed.setCode = _unquote(content.substring(4));
        parsed.setNegated = isNegation;
        continue;
      }
      if (content.startsWith('r:') || content.startsWith('rarity:')) {
        final value = content.contains(':')
            ? _unquote(content.split(':')[1])
            : null;
        parsed.rarity = value;
        if (value != null && value.isNotEmpty) {
          parsed.rarities.add(value.toLowerCase());
        }
        parsed.rarityNegated = isNegation;
        continue;
      }
      if (content.startsWith('artist:')) {
        parsed.artist = _unquote(content.substring(7));
        parsed.artistNegated = isNegation;
        continue;
      }
      if (content.startsWith('lang:')) {
        parsed.lang = _unquote(content.substring(5));
        parsed.langNegated = isNegation;
        continue;
      }
      if (content.startsWith('games:')) {
        parsed.games = _unquote(content.substring(6)).split(',');
        parsed.gamesNegated = isNegation;
        continue;
      }
      if (content.startsWith('usd>=')) {
        parsed.usdMin = double.tryParse(content.substring(4));
        continue;
      }
      if (content.startsWith('usd<=')) {
        parsed.usdMax = double.tryParse(content.substring(4));
        continue;
      }
      if (content.startsWith('eur>=')) {
        parsed.eurMin = double.tryParse(content.substring(4));
        continue;
      }
      if (content.startsWith('eur<=')) {
        parsed.eurMax = double.tryParse(content.substring(4));
        continue;
      }
      if (content.startsWith('tix>=')) {
        parsed.tixMin = double.tryParse(content.substring(4));
        continue;
      }
      if (content.startsWith('tix<=')) {
        parsed.tixMax = double.tryParse(content.substring(4));
        continue;
      }

      // Fallback: treat as a general text match.
      parsed.freeText.add(content);
    }

    return parsed;
  }

  List<String> _tokenizeScryfallQuery(String query) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < query.length; i++) {
      final char = query[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        buffer.write(char);
        continue;
      }

      if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  String _unquote(String value) {
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  List<MTGCard> _filterCardsByParsedQuery(_AdvancedQuery query) {
    return _allCards.where((card) {
      bool matches = true;

      String normalized(String? inValue) => (inValue ?? '').toLowerCase();

      final name = normalized(card.name);
      final oracle = normalized(card.oracleText);
      final typeLine = normalized(card.typeLine);

      if (query.name != null) {
        final contains = name.contains(query.name!.toLowerCase());
        matches = matches && (query.nameNegated ? !contains : contains);
      }

      if (query.oracleText != null) {
        final contains = oracle.contains(query.oracleText!.toLowerCase());
        matches = matches && (query.oracleNegated ? !contains : contains);
      }

      if (query.typeLine != null) {
        final contains = typeLine.contains(query.typeLine!.toLowerCase());
        matches = matches && (query.typeNegated ? !contains : contains);
      }

      if (query.manaCost != null) {
        bool manaContainsOrderInsensitive(String? cardMana, String queryMana) {
          final cardRaw = normalized(cardMana).trim();
          final queryRaw = queryMana.toLowerCase().trim();

          final tokenRegex = RegExp(r'\{[^}]+\}');
          final cardTokens = tokenRegex
              .allMatches(cardRaw)
              .map((m) => m.group(0)!)
              .toList();
          final queryTokens = tokenRegex
              .allMatches(queryRaw)
              .map((m) => m.group(0)!)
              .toList();

          // If either side has no mana tokens, fall back to plain contains.
          if (cardTokens.isEmpty || queryTokens.isEmpty) {
            return cardRaw.contains(queryRaw);
          }

          // Multiset subset check: every query token must exist in card tokens
          // with at least the same frequency, regardless of order.
          final cardCount = <String, int>{};
          for (final token in cardTokens) {
            cardCount[token] = (cardCount[token] ?? 0) + 1;
          }

          for (final token in queryTokens) {
            final current = cardCount[token] ?? 0;
            if (current <= 0) return false;
            cardCount[token] = current - 1;
          }

          return true;
        }

        final contains = manaContainsOrderInsensitive(card.manaCost, query.manaCost!);
        matches = matches && (query.manaNegated ? !contains : contains);
      }
      if (query.manaCostExact != null) {
        String normalizeManaCostOrder(String? manaCost) {
          final raw = normalized(manaCost).trim();
          final tokenMatches = RegExp(r'\{[^}]+\}')
              .allMatches(raw)
              .map((m) => m.group(0)!)
              .toList();

          if (tokenMatches.isEmpty) {
            return raw.replaceAll(' ', '');
          }

          tokenMatches.sort();
          return tokenMatches.join();
        }

        final mana = normalizeManaCostOrder(card.manaCost);
        final target = normalizeManaCostOrder(query.manaCostExact);
        final exact = mana == target;
        matches = matches && (query.manaNegated ? !exact : exact);
      }

      final cardIdentity = (card.colorIdentity ?? []).join().toUpperCase();
      if (query.colorIdentity != null && query.colorIdentity!.isNotEmpty) {
        final target = query.colorIdentity!.toUpperCase();
        final contains = target.split('').every((c) => cardIdentity.contains(c));
        matches = matches && (query.colorNegated ? !contains : contains);
      }
      if (query.colorIdentityExact != null && query.colorIdentityExact!.isNotEmpty) {
        final target = query.colorIdentityExact!.toUpperCase();
        final exact = cardIdentity == target;
        matches = matches && (query.colorNegated ? !exact : exact);
      }
      if (query.colorIdentityAtMost != null && query.colorIdentityAtMost!.isNotEmpty) {
        final target = query.colorIdentityAtMost!.toUpperCase();
        final atMost = cardIdentity.split('').toSet().difference(target.split('').toSet()).isEmpty;
        matches = matches && (query.colorNegated ? !atMost : atMost);
      }

      if (query.commanderIdentityExact != null && query.commanderIdentityExact!.isNotEmpty) {
        final target = query.commanderIdentityExact!.toUpperCase();
        final exact = cardIdentity == target;
        matches = matches && (query.commanderNegated ? !exact : exact);
      }
      if (query.commanderIdentityAtMost != null && query.commanderIdentityAtMost!.isNotEmpty) {
        final target = query.commanderIdentityAtMost!.toUpperCase();
        final atMost = cardIdentity.split('').toSet().difference(target.split('').toSet()).isEmpty;
        matches = matches && (query.commanderNegated ? !atMost : atMost);
      }
      if (query.commanderIdentity != null && query.commanderIdentity!.isNotEmpty) {
        final target = query.commanderIdentity!.toUpperCase();
        final contains = target.split('').every((c) => cardIdentity.contains(c));
        matches = matches && (query.commanderNegated ? !contains : contains);
      }

      if (query.cmcMin != null) {
        matches = matches && (card.cmc >= query.cmcMin!);
      }
      if (query.cmcMax != null) {
        matches = matches && (card.cmc <= query.cmcMax!);
      }

      double? tryParseNum(String? value) {
        if (value == null) return null;
        return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
      }

      final cardPower = tryParseNum(card.power);
      final cardToughness = tryParseNum(card.toughness);
      final cardLoyalty = tryParseNum(card.loyalty);

      if (query.powerMin != null && cardPower != null) {
        matches = matches && (cardPower >= query.powerMin!);
      }
      if (query.powerMax != null && cardPower != null) {
        matches = matches && (cardPower <= query.powerMax!);
      }
      if (query.toughnessMin != null && cardToughness != null) {
        matches = matches && (cardToughness >= query.toughnessMin!);
      }
      if (query.toughnessMax != null && cardToughness != null) {
        matches = matches && (cardToughness <= query.toughnessMax!);
      }
      if (query.loyaltyMin != null && cardLoyalty != null) {
        matches = matches && (cardLoyalty >= query.loyaltyMin!);
      }
      if (query.loyaltyMax != null && cardLoyalty != null) {
        matches = matches && (cardLoyalty <= query.loyaltyMax!);
      }

      if (query.setCode != null) {
        final cardSet = (card.setCode ?? '').toLowerCase();
        final contains = cardSet == query.setCode!.toLowerCase();
        matches = matches && (query.setNegated ? !contains : contains);
      }

      if (query.rarities.isNotEmpty) {
        final cardRarity = (card.rarity ?? '').toLowerCase();
        final containsAny = query.rarities.contains(cardRarity);
        matches = matches && (query.rarityNegated ? !containsAny : containsAny);
      } else if (query.rarity != null) {
        final cardRarity = (card.rarity ?? '').toLowerCase();
        final contains = cardRarity == query.rarity!.toLowerCase();
        matches = matches && (query.rarityNegated ? !contains : contains);
      }

      if (query.artist != null) {
        final cardArtist = (card.artist ?? '').toLowerCase();
        final contains = cardArtist.contains(query.artist!.toLowerCase());
        matches = matches && (query.artistNegated ? !contains : contains);
      }

      if (query.lang != null) {
        final cardLang = (card.lang ?? '').toLowerCase();
        final contains = cardLang == query.lang!.toLowerCase();
        matches = matches && (query.langNegated ? !contains : contains);
      }

      if (query.games.isNotEmpty) {
        final cardGames = (card.games ?? []).map((g) => g.toLowerCase()).toList();
        final contains = query.games
            .map((g) => g.toLowerCase())
            .every((g) => cardGames.contains(g));
        matches = matches && (query.gamesNegated ? !contains : contains);
      }

      if (query.usdMin != null && card.usd != null) {
        matches = matches && (card.usd! >= query.usdMin!);
      }
      if (query.usdMax != null && card.usd != null) {
        matches = matches && (card.usd! <= query.usdMax!);
      }
      if (query.eurMin != null && card.eur != null) {
        matches = matches && (card.eur! >= query.eurMin!);
      }
      if (query.eurMax != null && card.eur != null) {
        matches = matches && (card.eur! <= query.eurMax!);
      }
      if (query.tixMin != null && card.tix != null) {
        matches = matches && (card.tix! >= query.tixMin!);
      }
      if (query.tixMax != null && card.tix != null) {
        matches = matches && (card.tix! <= query.tixMax!);
      }

      if (query.freeText.isNotEmpty) {
        final combined = '$name $oracle $typeLine';
        for (final free in query.freeText) {
          if (!combined.contains(free.toLowerCase())) {
            matches = false;
            break;
          }
        }
      }

      return matches;
    }).toList();
  }

  Future<bool> _shouldUpdateCardData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateString = prefs.getString(_lastUpdateKey);
    
    if (lastUpdateString == null) return true;

    final lastUpdate = DateTime.parse(lastUpdateString);
    final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
    
    return lastUpdate.isBefore(twoWeeksAgo);
  }

   Future<bool> _shouldGenerateNewDailyCards() async {
    // Check if regular cards are null
    if (_dailyRegularCard == null || _dailyRegularLand == null) {
      return true;
    }

    // Validate game changer status
    if (_dailyRegularCard!.gameChanger || _dailyRegularLand!.gameChanger) {
      return true;
    }

    // Only check game changer status if the cards exist
    if (_dailyGameChangerCard != null && !_dailyGameChangerCard!.gameChanger) {
      return true;
    }
    if (_dailyGameChangerLand != null && !_dailyGameChangerLand!.gameChanger) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastDateString = prefs.getString(_dailyCardDateKey);
    
    if (lastDateString == null) return true;

    final lastDate = DateTime.parse(lastDateString);
    final today = DateTime.now();
    
    return !_isSameDay(lastDate, today);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _downloadCardData() async {
    try {
      // Get bulk data info
      const headers = {
        'User-Agent': 'Command/1.0 (https://github.com/yourname/commander_daily_cards)',
        'Accept': 'application/json',
      };

      final bulkDataResponse = await http
          .get(
            Uri.parse('https://api.scryfall.com/bulk-data'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (bulkDataResponse.statusCode != 200) {
        debugPrint(
          'Failed to fetch bulk data info: ${bulkDataResponse.statusCode} - ${bulkDataResponse.body}',
        );
        throw Exception(
            'Failed to fetch bulk data info (HTTP ${bulkDataResponse.statusCode})');
      }

      final bulkData = BulkDataResponse.fromJson(
        json.decode(bulkDataResponse.body),
      );

      // Find oracle cards bulk data
      final oracleData = bulkData.data.firstWhere(
        (item) => item.type == 'oracle_cards',
        orElse: () => throw Exception('Oracle cards data not found'),
      );

      // Download cards data
      final cardDataResponse = await http
          .get(
            Uri.parse(oracleData.downloadUri),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (cardDataResponse.statusCode != 200) {
        debugPrint(
          'Failed to download card data: ${cardDataResponse.statusCode} - ${cardDataResponse.body}',
        );
        throw Exception('Failed to download card data');
      }

      final List<dynamic> cardJsonList = json.decode(cardDataResponse.body);
      final cards = cardJsonList
          .map((cardJson) => MTGCard.fromJson(cardJson))
          .where((card) =>
              card.isCommanderLegal ||
              card.legalities['commander'] == 'banned')
          .toList();

      _allCards = cards;
      final saved = await _saveCardDataLocally(cards);
      if (!saved) {
        throw Exception('Failed to save card data locally');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

    } catch (e, st) {
      debugPrint('Error downloading card data: $e\n$st');
      await _loadLocalCardData();
    }
  }

  Future<File> _localCardDataFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/all_cards.json');
  }

  Future<void> _loadLocalCardData() async {
    try {
      final file = await _localCardDataFile();
      if (!await file.exists()) return;

      final cardsJsonString = await file.readAsString();
      final List<dynamic> cardJsonList = json.decode(cardsJsonString);
      _allCards = cardJsonList
          .map((cardJson) => MTGCard.fromJson(cardJson))
          .toList();
    } catch (e) {
      debugPrint('Error loading local card data: $e');
    }
  }

  Future<bool> _saveCardDataLocally(List<MTGCard> cards) async {
    try {
      final file = await _localCardDataFile();
      final cardsJson = cards.map((card) => card.toJson()).toList();
      await file.writeAsString(json.encode(cardsJson));
      return true;
    } catch (e) {
      debugPrint('Error saving card data locally: $e');
      return false;
    }
  }

  Future<void> generateDailyCards(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {
    final filteredCards = _allCards.where((card) =>
        nonLandFilters.matchesCard(card) && !_isCommanderBanned(card)).toList();

    final filteredLands = _allCards.where((card) =>
        landFilters.matchesCard(card) && !_isCommanderBanned(card)).toList();

    if (filteredCards.isEmpty) {
      debugPrint('No cards match the current filters');
      return;
    }

    if (filteredLands.isEmpty) {
      debugPrint('No lands match the current filters');
      return;
    }

    // Generate the daily suggestion list (used for the app bar image). This is
    // deterministic and derived from the current date.
    final today = DateTime.now();
    _buildDailySuggestionCards(today);

    // Use the same deterministic seed for filtering so results are stable.
    final dateString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final random = Random(dateString.hashCode);

    final shuffledCards = List<MTGCard>.from(filteredCards)..shuffle(random);
    final shuffledLands = List<MTGCard>.from(filteredLands)..shuffle(random);

    // Regular card: keep existing if still valid
    if (_dailyRegularCard != null &&
        filteredCards.contains(_dailyRegularCard) &&
        !_isGameChanger(_dailyRegularCard!)) {
      // keep existing regular card
    } else {
      _dailyRegularCard = shuffledCards.firstWhere(
        (card) => !_isGameChanger(card),
        orElse: () => shuffledCards.first,
      );
    }

    // Game changer card: keep existing if still valid, otherwise pick another
    if (_dailyGameChangerCard != null &&
        filteredCards.contains(_dailyGameChangerCard) &&
        _isGameChanger(_dailyGameChangerCard!)) {
      // keep existing game changer
    } else {
      try {
        _dailyGameChangerCard = shuffledCards
            .where((card) => card != _dailyRegularCard)
            .firstWhere((card) => _isGameChanger(card));
      } catch (e) {
        _dailyGameChangerCard = null;
      }
    }

    // Regular land: keep existing if still valid
    if (_dailyRegularLand != null &&
        filteredLands.contains(_dailyRegularLand) &&
        !_isGameChanger(_dailyRegularLand!)) {
      // keep existing regular land
    } else {
      _dailyRegularLand = shuffledLands.firstWhere(
        (card) => !_isGameChanger(card),
        orElse: () => shuffledLands.first,
      );
    }

    // Game changer land: keep existing if still valid, otherwise pick another
    if (_dailyGameChangerLand != null &&
        filteredLands.contains(_dailyGameChangerLand) &&
        _isGameChanger(_dailyGameChangerLand!)) {
      // keep existing game changer land
    } else {
      try {
        _dailyGameChangerLand = shuffledLands
            .where((card) => card != _dailyRegularLand)
            .firstWhere((card) => _isGameChanger(card));
      } catch (e) {
        _dailyGameChangerLand = null;
      }
    }

    await _saveDailyCards();
    notifyListeners();
  }

  Future<void> _loadSavedDailyCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final regularCardJson = prefs.getString(_regularCardKey);
      if (regularCardJson != null) {
        _dailyRegularCard = MTGCard.fromJson(json.decode(regularCardJson));
      }

      final gameChangerCardJson = prefs.getString(_gameChangerCardKey);
      if (gameChangerCardJson != null) {
        _dailyGameChangerCard = MTGCard.fromJson(json.decode(gameChangerCardJson));
      }

      final regularLandCardJson = prefs.getString(_regularLandKey);
      if (regularLandCardJson != null) {
        _dailyRegularLand = MTGCard.fromJson(json.decode(regularLandCardJson));
      }

      final gameChangerLandJson = prefs.getString(_gameChangerLandKey);
      if (gameChangerLandJson != null) {
        _dailyGameChangerLand = MTGCard.fromJson(json.decode(gameChangerLandJson));
      }

      final selectedCommanderJson = prefs.getString(_selectedCommanderKey);
      if (selectedCommanderJson != null) {
        final decoded = json.decode(selectedCommanderJson);
        if (decoded is List) {
          _selectedCommanders = _sanitizeSelectedCommanders(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(MTGCard.fromJson),
          );
        } else if (decoded is Map<String, dynamic>) {
          _selectedCommanders = _sanitizeSelectedCommanders([
            MTGCard.fromJson(decoded),
          ]);
        }
      }

      _dailyAppBarCardId = prefs.getString(_appBarCardKey);

      // Ensure the daily suggestion list is rebuilt so app bar selection works
      // consistently across app launches.
      _buildDailySuggestionCards(DateTime.now());
    } catch (e) {
      debugPrint('Error loading saved daily cards: $e');
    }
  }

  Future<void> _saveDailyCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_dailyCardDateKey, DateTime.now().toIso8601String());

      if (_dailyRegularCard != null) {
        await prefs.setString(
          _regularCardKey,
          json.encode(_dailyRegularCard!.toJson()),
        );
      }

      if (_dailyGameChangerCard != null) {
        await prefs.setString(
          _gameChangerCardKey,
          json.encode(_dailyGameChangerCard!.toJson()),
        );
      }

      if (_dailyRegularLand != null) {
        await prefs.setString(
          _regularLandKey,
          json.encode(_dailyRegularLand!.toJson()),
        );
      }

      if (_dailyGameChangerLand != null) {
        await prefs.setString(
          _gameChangerLandKey,
          json.encode(_dailyGameChangerLand!.toJson()),
        );
      }

      if (_dailyAppBarCardId != null) {
        await prefs.setString(_appBarCardKey, _dailyAppBarCardId!);
      } else {
        await prefs.remove(_appBarCardKey);
      }
    } catch (e) {
      debugPrint('Error saving daily cards: $e');
    }
  }

  void _buildDailySuggestionCards(DateTime date) {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final seed = dateString.hashCode;
    final random = Random(seed);
    final shuffledAllCards = List<MTGCard>.from(_allCards)..shuffle(random);
    _dailySuggestionCards = shuffledAllCards.take(50).toList();

    if (_dailyAppBarCardId != null &&
        _dailySuggestionCards.any((card) => card.id == _dailyAppBarCardId)) {
      // keep existing selection
    } else if (_dailySuggestionCards.isNotEmpty) {
      _dailyAppBarCardId = _dailySuggestionCards.first.id;
    }
  }

  bool _isCommanderBanned(MTGCard card) {
    return card.legalities['commander'] == 'banned';
  }

  bool _isGameChanger(MTGCard card) {
    return card.gameChanger;
  }

  List<String> get typeLineSuggestions {
    final suggestions = <String>{};

    for (final typeLine in _allCards
        .map((card) => card.typeLine)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()) {
      // Split the type line into supertypes/types (before the em dash)
      final parts = typeLine.split('—');
      final mainTypes = parts.first.trim();
      if (mainTypes.isNotEmpty) {
        suggestions.add(mainTypes);
        for (final token in mainTypes.split(' ')) {
          if (token.isNotEmpty) {
            suggestions.add(token);
          }
        }
      }
    }

    return suggestions.toList();
  }

  List<String> get setSuggestions {
    return _allCards
        .map((card) => card.setName)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> get artistSuggestions {
    return _allCards
        .map((card) => card.artist)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> get languageSuggestions {
    return _allCards
        .map((card) => card.lang)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }
}

class _AdvancedQuery {
  String? name;
  bool nameNegated = false;

  String? oracleText;
  bool oracleNegated = false;

  String? typeLine;
  bool typeNegated = false;

  String? manaCost;
  String? manaCostExact;
  bool manaNegated = false;

  String? colorIdentity;
  String? colorIdentityExact;
  String? colorIdentityAtMost;
  bool colorNegated = false;

  String? commanderIdentity;
  String? commanderIdentityExact;
  String? commanderIdentityAtMost;
  bool commanderNegated = false;

  double? cmcMin;
  double? cmcMax;

  double? powerMin;
  double? powerMax;
  double? toughnessMin;
  double? toughnessMax;
  double? loyaltyMin;
  double? loyaltyMax;

  String? setCode;
  bool setNegated = false;

  String? rarity;
  final Set<String> rarities = {};
  bool rarityNegated = false;

  String? artist;
  bool artistNegated = false;

  String? lang;
  bool langNegated = false;

  List<String> games = [];
  bool gamesNegated = false;

  double? usdMin;
  double? usdMax;
  double? eurMin;
  double? eurMax;
  double? tixMin;
  double? tixMax;

  final List<String> freeText = [];
}
