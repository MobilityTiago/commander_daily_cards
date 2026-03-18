import 'base_filter_settings.dart';
import '../cards/card_enums.dart';
import '../cards/mtg_card.dart';

class SpellFilterSettings extends BaseFilterSettings {
  final Set<CardType> _selectedCardTypes = Set.from(CardType.values.where((type) => type.displayName != 'Land'));
  final Set<MTGColor> _selectedColors = Set.from(MTGColor.values);
  List<String>? _commanderIdentityLock;
  double _minCMC = 0.0;
  double _maxCMC = 15.0;
  bool _exclusiveColorMatch = false;
  final Set<String> _selectedRarities = {'common', 'uncommon', 'rare', 'mythic'};

  Set<CardType> get selectedCardTypes => _selectedCardTypes;
  Set<MTGColor> get selectedColors => _selectedColors;
  double get minCMC => _minCMC;
  double get maxCMC => _maxCMC;
  bool get exclusiveColorMatch => _exclusiveColorMatch;
  Set<String> get selectedRarities => _selectedRarities;
  bool get isCommanderLocked => _commanderIdentityLock != null;
  List<String> get commanderIdentityLock =>
      List.unmodifiable(_commanderIdentityLock ?? const <String>[]);

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
    // Spell filter should only match non-land cards. If typeLine is missing or
    // doesn't explicitly contain 'land', treat it as a non-land.
    if (card.typeLine == null ||
        card.typeLine!.toLowerCase().contains('land')) {
      return false;
    }

    final cardTypeMatches = _selectedCardTypes.isEmpty ||
        _selectedCardTypes.any((cardType) =>
            card.typeLine?.contains(cardType.displayName) == true);

    final colorMatches = isCommanderLocked
      ? _isIdentitySubsetOfCommander(card.colorIdentity ?? [])
      : _selectedColors.isEmpty ||
        (card.colors?.isEmpty == true &&
          _selectedColors.contains(MTGColor.colorless)) ||
        (_exclusiveColorMatch
          ? _areColorListsEqual(
            card.colorIdentity ?? [],
            _selectedColors.where((c) => c != MTGColor.colorless)
              .map((c) => c.symbol)
              .toList())
          : card.colorIdentity?.any((color) =>
              _selectedColors.any(
                (selectedColor) => selectedColor.symbol == color)) ==
            true);

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

  bool _isIdentitySubsetOfCommander(List<String> cardIdentity) {
    final allowed = _commanderIdentityLock;
    if (allowed == null) return true;
    return cardIdentity.every(allowed.contains);
  }

  void setColorsFromIdentity(List<String> colorIdentity) {
    _selectedColors.clear();
    if (colorIdentity.isEmpty) {
      _selectedColors.add(MTGColor.colorless);
    } else {
      for (final symbol in colorIdentity) {
        final match =
            MTGColor.values.where((c) => c.symbol == symbol).firstOrNull;
        if (match != null) _selectedColors.add(match);
      }
    }
    notifyListeners();
  }

  void lockToCommanderIdentity(List<String> colorIdentity) {
    _commanderIdentityLock = List<String>.from(colorIdentity);
    _exclusiveColorMatch = false;
    _selectedColors.clear();
    if (colorIdentity.isEmpty) {
      _selectedColors.add(MTGColor.colorless);
    } else {
      for (final symbol in colorIdentity) {
        final match =
            MTGColor.values.where((c) => c.symbol == symbol).firstOrNull;
        if (match != null) _selectedColors.add(match);
      }
    }
    notifyListeners();
  }

  void unlockCommanderIdentity() {
    _commanderIdentityLock = null;
    resetColors();
  }

  void resetColors() {
    _selectedColors
      ..clear()
      ..addAll(MTGColor.values);
    notifyListeners();
  }
}

