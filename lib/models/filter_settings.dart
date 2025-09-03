import 'package:flutter/material.dart';
import 'card_enums.dart';
import 'mtg_card.dart';

class FilterSettings extends ChangeNotifier {
  Set<CardType> _selectedCardTypes = Set.from(CardType.values);
  Set<MTGColor> _selectedColors = Set.from(MTGColor.values);
  double _maxCMC = 10.0;
  String _keywords = '';

  Set<CardType> get selectedCardTypes => _selectedCardTypes;
  Set<MTGColor> get selectedColors => _selectedColors;
  double get maxCMC => _maxCMC;
  String get keywords => _keywords;

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

  void setMaxCMC(double cmc) {
    _maxCMC = cmc;
    notifyListeners();
  }

  void setKeywords(String keywords) {
    _keywords = keywords;
    notifyListeners();
  }

  bool matchesCard(MTGCard card) {
    // Check card type
    final cardTypeMatches = _selectedCardTypes.isEmpty ||
        _selectedCardTypes.any((cardType) =>
            card.typeLine?.contains(cardType.displayName) == true);

    // Check colors
    final colorMatches = _selectedColors.isEmpty ||
        (card.colors?.isEmpty == true && _selectedColors.contains(MTGColor.colorless)) ||
        (card.colors?.any((color) =>
            _selectedColors.any((selectedColor) => selectedColor.symbol == color)) == true);

    // Check CMC
    final cmcMatches = card.cmc <= _maxCMC;

    // Check keywords
    final keywordMatches = _keywords.isEmpty ||
        _keywords.split(',').every((keyword) {
          final trimmed = keyword.trim().toLowerCase();
          return card.oracleText?.toLowerCase().contains(trimmed) == true ||
              card.keywords?.any((k) => k.toLowerCase().contains(trimmed)) == true;
        });

    return cardTypeMatches && colorMatches && cmcMatches && keywordMatches;
  }
}