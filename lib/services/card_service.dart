import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mtg_card.dart';
import '../models/bulk_data.dart';
import '../models/filter_settings.dart';

class CardService extends ChangeNotifier {
  bool _isLoading = false;
  MTGCard? _dailyRegularCard;
  MTGCard? _dailyGameChangerCard;
  List<MTGCard> _allCards = [];

  bool get isLoading => _isLoading;
  MTGCard? get dailyRegularCard => _dailyRegularCard;
  MTGCard? get dailyGameChangerCard => _dailyGameChangerCard;

  static const String _lastUpdateKey = 'LastCardDataUpdate';
  static const String _dailyCardDateKey = 'LastDailyCardDate';
  static const String _regularCardKey = 'DailyRegularCard';
  static const String _gameChangerCardKey = 'DailyGameChangerCard';
  static const String _allCardsKey = 'AllCards';

  Future<void> loadInitialData(FilterSettings filters) async {
    _isLoading = true;
    notifyListeners();

    try {
      final shouldUpdateCards = await _shouldUpdateCardData();

      if (shouldUpdateCards || _allCards.isEmpty) {
        await _downloadCardData();
      } else {
        await _loadLocalCardData();
      }

      if (await _shouldGenerateNewDailyCards()) {
        await generateDailyCards(filters);
      } else {
        await _loadSavedDailyCards();
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDailyCards(FilterSettings filters) async {
    await generateDailyCards(filters);
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
      final bulkDataResponse = await http.get(
        Uri.parse('https://api.scryfall.com/bulk-data'),
      );

      if (bulkDataResponse.statusCode != 200) {
        throw Exception('Failed to fetch bulk data info');
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
      final cardDataResponse = await http.get(
        Uri.parse(oracleData.downloadUri),
      );

      if (cardDataResponse.statusCode != 200) {
        throw Exception('Failed to download card data');
      }

      final List<dynamic> cardJsonList = json.decode(cardDataResponse.body);
      final cards = cardJsonList
          .map((cardJson) => MTGCard.fromJson(cardJson))
          .where((card) => card.isCommanderLegal)
          .toList();

      _allCards = cards;
      await _saveCardDataLocally(cards);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint('Error downloading card data: $e');
      await _loadLocalCardData();
    }
  }

  Future<void> _loadLocalCardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJsonString = prefs.getString(_allCardsKey);
      
      if (cardsJsonString != null) {
        final List<dynamic> cardJsonList = json.decode(cardsJsonString);
        _allCards = cardJsonList
            .map((cardJson) => MTGCard.fromJson(cardJson))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading local card data: $e');
    }
  }

  Future<void> _saveCardDataLocally(List<MTGCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = cards.map((card) => card.toJson()).toList();
      await prefs.setString(_allCardsKey, json.encode(cardsJson));
    } catch (e) {
      debugPrint('Error saving card data locally: $e');
    }
  }

  Future<void> generateDailyCards(FilterSettings filters) async {
    final filteredCards = _allCards
        .where((card) => filters.matchesCard(card) && !_isCommanderBanned(card))
        .toList();

    if (filteredCards.isEmpty) {
      debugPrint('No cards match the current filters');
      return;
    }

    // Generate deterministic random based on current date
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final seed = dateString.hashCode;
    final random = Random(seed);

    final shuffledCards = List<MTGCard>.from(filteredCards)..shuffle(random);

    // Select regular card
    _dailyRegularCard = shuffledCards.first;

    // Select game changer card
    _dailyGameChangerCard = shuffledCards
        .skip(1)
        .firstWhere(
          (card) => _isGameChanger(card),
          orElse: () => shuffledCards.length > 1 ? shuffledCards[1] : shuffledCards.first,
        );

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
    } catch (e) {
      debugPrint('Error saving daily cards: $e');
    }
  }

  bool _isCommanderBanned(MTGCard card) {
    const bannedCards = [
      'Ancestral Recall', 'Balance', 'Biorhythm', 'Black Lotus',
      'Braids, Cabal Minion', 'Chaos Orb', 'Coalition Victory',
      'Channel', 'Emrakul, the Aeons Torn', 'Erayo, Soratami Ascendant',
      'Falling Star', 'Fastbond', 'Flash', 'Gifts Ungiven',
      'Griselbrand', 'Hullbreacher', 'Iona, Shield of Emeria',
      'Karakas', 'Leovold, Emissary of Trest', 'Library of Alexandria',
      'Limited Resources', 'Lutri, the Spellchaser', 'Mox Emerald',
      'Mox Jet', 'Mox Pearl', 'Mox Ruby', 'Mox Sapphire',
      'Panoptic Mirror', 'Paradox Engine', 'Primeval Titan',
      'Prophet of Kruphix', 'Recurring Nightmare', 'Rofellos, Llanowar Emissary',
      'Shahrazad', 'Sundering Titan', 'Sway of the Stars',
      'Sylvan Primordial', 'Time Vault', 'Time Walk', 'Tinker',
      'Tolarian Academy', 'Trade Secrets', 'Upheaval', 'Yawgmoth\'s Bargain'
    ];

    return bannedCards.contains(card.name);
  }

  bool _isGameChanger(MTGCard card) {
    const gameChangerKeywords = [
      'draw', 'destroy', 'exile', 'counter', 'return', 'search',
      'double', 'extra turn', 'win the game', 'lose the game',
      'each opponent', 'all opponents'
    ];

    final oracleText = card.oracleText?.toLowerCase() ?? '';
    return gameChangerKeywords.any((keyword) => oracleText.contains(keyword)) ||
        card.cmc >= 6;
  }
}