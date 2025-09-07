import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  bool get isLoading => _isLoading;
  MTGCard? get dailyRegularCard => _dailyRegularCard;
  MTGCard? get dailyGameChangerCard => _dailyGameChangerCard;
  MTGCard? get dailyRegularLand => _dailyRegularLand;
  MTGCard? get dailyGameChangerLand => _dailyGameChangerLand;

  static const String _lastUpdateKey = 'LastCardDataUpdate';
  static const String _dailyCardDateKey = 'LastDailyCardDate';
  static const String _regularCardKey = 'DailyRegularCard';
  static const String _gameChangerCardKey = 'DailyGameChangerCard';
  static const String _regularLandKey = 'DailyRegularLand';
  static const String _gameChangerLandKey = 'DailyGameChangerLand';
  static const String _allCardsKey = 'AllCards';

  Future<void> loadInitialData(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {

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
        await generateDailyCards(nonLandFilters, landFilters);
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

  Future<void> refreshDailyCards(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {
   
    await generateDailyCards(nonLandFilters, landFilters);
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

  Future<void> generateDailyCards(SpellFilterSettings nonLandFilters, LandFilterSettings landFilters) async {
    final filteredCards = _allCards.where((card) => 
        nonLandFilters.matchesCard(card) && 
        !_isCommanderBanned(card)
    ).toList();
    
    final filteredLands = _allCards.where((card) => 
        landFilters.matchesCard(card) && 
        !_isCommanderBanned(card)
    ).toList();

    if (filteredCards.isEmpty) {
      debugPrint('No cards match the current filters');
      return;
    }

    if (filteredLands.isEmpty) {
      debugPrint('No lands match the current filters');
      return;
    }

    // Generate deterministic random based on current date
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final seed = dateString.hashCode;
    final random = Random(seed);

    final shuffledCards = List<MTGCard>.from(filteredCards)..shuffle(random);
    final shuffledLands = List<MTGCard>.from(filteredLands)..shuffle(random);

  // Select regular card and game changer
    _dailyRegularCard = shuffledCards
        .firstWhere(
          (card) => !_isGameChanger(card),
          orElse: () => shuffledCards.first,
        );
    
    try{
        _dailyGameChangerCard = shuffledCards
          .where((card) => card != _dailyRegularCard)
          .firstWhere(
            (card) => _isGameChanger(card)
          );
    }
    catch(e){
      _dailyGameChangerCard = null;
    }

    // Select lands
      _dailyRegularLand = shuffledLands
        .firstWhere(
          (card) => !_isGameChanger(card),
          orElse: () => shuffledLands.first,
        );

        try{
            _dailyGameChangerLand = shuffledLands
              .where((card) => card != _dailyRegularLand)
              .firstWhere(
          (card) => _isGameChanger(card)
        );
        }
        catch(e){
          _dailyGameChangerLand = null;
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
    } catch (e) {
      debugPrint('Error saving daily cards: $e');
    }
  }

  bool _isCommanderBanned(MTGCard card) {
    return card.legalities['commander'] == 'banned';
  }

  bool _isGameChanger(MTGCard card) {
    return card.gameChanger;
  }

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
}