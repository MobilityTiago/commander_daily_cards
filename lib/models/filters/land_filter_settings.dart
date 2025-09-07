import 'base_filter_settings.dart';
import '../cards/card_enums.dart';
import '../cards/mtg_card.dart';

class LandFilterSettings extends BaseFilterSettings {
  

static const Set<String> availableLandTypes = {
    'Basic',
    'Nonbasic',
    'Desert',
    'Gate',
    'Lair',
    'Locus',
    'Mine',
    'Power-Plant',
    'Tower',
    'Urza\'s',
    'No Subtype',
  };

  Set<MTGColor> _producedMana = Set.from(MTGColor.values);
  Set<String> _selectedLandTypes = Set.from(availableLandTypes);  // Initialize with all types selected

  bool _fetchLands = true;
  bool _shockLands = true;
  bool _dualLands = true;
  bool _utilityLands = true;

 Set<MTGColor> get producedMana => _producedMana;
  Set<String> get landTypes => availableLandTypes;  // Return available types
  Set<String> get selectedLandTypes => _selectedLandTypes;  // Add getter for selected types
  bool get fetchLands => _fetchLands;
  bool get shockLands => _shockLands;
  bool get dualLands => _dualLands;
  bool get utilityLands => _utilityLands;

  void toggleLandType(String landType) {
    if (_selectedLandTypes.contains(landType)) {
      _selectedLandTypes.remove(landType);
    } else {
      _selectedLandTypes.add(landType);
    }
    notifyListeners();
  }

  void toggleFetchLands() {
    _fetchLands = !_fetchLands;
    notifyListeners();
  }

  void toggleShockLands() {
    _shockLands = !_shockLands;
    notifyListeners();
  }

  void toggleDualLands() {
    _dualLands = !_dualLands;
    notifyListeners();
  }

  void toggleUtilityLands() {
    _utilityLands = !_utilityLands;
    notifyListeners();
  }

  void toggleProducedMana(MTGColor color) {
  if (_producedMana.contains(color)) {
    _producedMana.remove(color);
  } else {
    _producedMana.add(color);
  }
  notifyListeners();
}

  @override
  bool matchesCard(MTGCard card) {
    
    if (!card.typeLine!.toLowerCase().contains('land') == true) {
      return false;
    }
    final landTypeMatches = _selectedLandTypes.isEmpty ||
        _selectedLandTypes.any((type) {
          if (type == 'No Subtype') {
            final typeLine = card.typeLine?.toLowerCase() ?? '';
            return typeLine == 'land' || typeLine == 'land —';
          }
          return card.typeLine?.contains(type) == true;
        });

    final producedManaMatches = _producedMana.isEmpty ||
        (card.producedMana?.any((mana) =>
            _producedMana.any((selected) => selected.symbol == mana)) ?? false);

    final specialLandMatches = _checkSpecialLandType(card);

    final keywordMatches = keywords.isEmpty ||
        keywords.split(',').every((keyword) {
          final trimmed = keyword.trim().toLowerCase();
          return card.oracleText?.toLowerCase().contains(trimmed) == true ||
              card.keywords?.any((k) => k.toLowerCase().contains(trimmed)) == true;
        });

    return producedManaMatches && landTypeMatches && specialLandMatches && keywordMatches;
  }

  bool _checkSpecialLandType(MTGCard card) {
    final oracleText = card.oracleText?.toLowerCase() ?? '';

    if (!_fetchLands && _isFetchLand(oracleText)) return false;
    if (!_shockLands && _isShockLand(oracleText)) return false;
    if (!_dualLands && _isDualLand(card.typeLine ?? '', oracleText)) return false;
    if (!_utilityLands && _isUtilityLand(oracleText)) return false;

    return true;
  }

  bool _isFetchLand(String oracleText) =>
      oracleText.contains('search your library for') && 
      oracleText.contains('land card');

  bool _isShockLand(String oracleText) =>
      oracleText.contains('enters the battlefield') && 
      oracleText.contains('pay 2 life');

  bool _isDualLand(String typeLine, String oracleText) =>
      typeLine.contains('dual') || 
      (oracleText.contains('enters the battlefield') && 
       oracleText.contains('tapped'));

  bool _isUtilityLand(String oracleText) =>
      oracleText.contains('sacrifice') ||
      oracleText.contains('destroy') ||
      oracleText.contains('counter') ||
      oracleText.contains('draw a card');
}