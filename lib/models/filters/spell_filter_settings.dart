import 'base_filter_settings.dart';
import '../cards/card_enums.dart';
import '../cards/mtg_card.dart';

class SpellFilterSettings extends BaseFilterSettings {
  Set<CardType> _selectedCardTypes = Set.from(CardType.values.where((type) => type.displayName != 'Land'));
  Set<MTGColor> _selectedColors = Set.from(MTGColor.values);
  double _minCMC = 0.0;
  double _maxCMC = 15.0;
  bool _exclusiveColorMatch = false;
  Set<String> _selectedRarities = {'common', 'uncommon', 'rare', 'mythic'};

  Set<CardType> get selectedCardTypes => _selectedCardTypes;
  Set<MTGColor> get selectedColors => _selectedColors;
  double get minCMC => _minCMC;
  double get maxCMC => _maxCMC;
  bool get exclusiveColorMatch => _exclusiveColorMatch;
  Set<String> get selectedRarities => _selectedRarities;

  void toggleCardType(CardType cardType) {
    if (_selectedCardTypes.contains(cardType)) {
      _selectedCardTypes.remove(cardType);
    } else {
      _selectedCardTypes.add(cardType);
    }
    notifyListeners();
  }

  void toggleColor(MTGColor color) {
    if (_selectedColors.contains(color)) {
      _selectedColors.remove(color);
    } else {
      _selectedColors.add(color);
    }
    notifyListeners();
  }

  void toggleColorMatchMode() {
    _exclusiveColorMatch = !_exclusiveColorMatch;
    notifyListeners();
  }

  void setMinCMC(double value) {
    _minCMC = value;
    notifyListeners();
  }

  void setMaxCMC(double value) {
    _maxCMC = value;
    notifyListeners();
  }

  void toggleRarity(String rarity) {
    final normalizedRarity = rarity.toLowerCase();
    if (_selectedRarities.contains(normalizedRarity)) {
      _selectedRarities.remove(normalizedRarity);
    } else {
      _selectedRarities.add(normalizedRarity);
    }
    notifyListeners();
  }

  @override
  bool matchesCard(MTGCard card) {
    if (card.typeLine?.toLowerCase().contains('land') == true) {
      return false;
    }

    final cardTypeMatches = _selectedCardTypes.isEmpty ||
        _selectedCardTypes.any((cardType) =>
            card.typeLine?.contains(cardType.displayName) == true);

    final colorMatches = _selectedColors.isEmpty ||
        (card.colors?.isEmpty == true && _selectedColors.contains(MTGColor.colorless)) ||
        (_exclusiveColorMatch
            ? _areColorListsEqual(
                card.colorIdentity ?? [], 
                _selectedColors.where((c) => c != MTGColor.colorless)
                    .map((c) => c.symbol)
                    .toList())
            : card.colorIdentity?.any((color) =>
                _selectedColors.any((selectedColor) => 
                    selectedColor.symbol == color)) == true);

    final cmcMatches = card.cmc >= _minCMC && card.cmc <= _maxCMC;

    final rarityMatches = _selectedRarities.isEmpty ||
        _selectedRarities.contains(card.rarity?.toLowerCase());

    final keywordMatches = keywords.isEmpty ||
        keywords.split(',').every((keyword) {
          final trimmed = keyword.trim().toLowerCase();
          return card.oracleText?.toLowerCase().contains(trimmed) == true ||
              card.keywords?.any((k) => k.toLowerCase().contains(trimmed)) == true;
        });

    return cardTypeMatches && 
           colorMatches && 
           cmcMatches && 
           rarityMatches && 
           keywordMatches;
  }

  bool _areColorListsEqual(List<String> colors1, List<String> colors2) {
    if (colors1.length != colors2.length) return false;
    final sortedColors1 = List<String>.from(colors1)..sort();
    final sortedColors2 = List<String>.from(colors2)..sort();
    for (var i = 0; i < sortedColors1.length; i++) {
      if (sortedColors1[i] != sortedColors2[i]) return false;
    }
    return true;
  }
}

