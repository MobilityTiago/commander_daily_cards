class CardSymbolResponse {
  final List<CardSymbol> data;

  CardSymbolResponse({required this.data});

  factory CardSymbolResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CardSymbol.fromJson)
        .toList();

    return CardSymbolResponse(data: list);
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((symbol) => symbol.toJson()).toList(),
    };
  }
}

class CardSymbol {
  final String symbol;
  final String? svgUri;
  final String? english;
  final bool? representsMana;
  final bool? appearsInManaCosts;
  final double? manaValue;
  final bool? hybrid;
  final bool? phyrexian;
  final bool? funny;
  final List<String> colors;

  CardSymbol({
    required this.symbol,
    this.svgUri,
    this.english,
    this.representsMana,
    this.appearsInManaCosts,
    this.manaValue,
    this.hybrid,
    this.phyrexian,
    this.funny,
    required this.colors,
  });

  factory CardSymbol.fromJson(Map<String, dynamic> json) {
    return CardSymbol(
      symbol: json['symbol'] ?? '',
      svgUri: json['svg_uri'],
      english: json['english'],
      representsMana: json['represents_mana'],
      appearsInManaCosts: json['appears_in_mana_costs'],
      manaValue: _parseDouble(json['cmc']),
      hybrid: json['hybrid'],
      phyrexian: json['phyrexian'],
      funny: json['funny'],
      colors: (json['colors'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'svg_uri': svgUri,
      'english': english,
      'represents_mana': representsMana,
      'appears_in_mana_costs': appearsInManaCosts,
      'cmc': manaValue,
      'hybrid': hybrid,
      'phyrexian': phyrexian,
      'funny': funny,
      'colors': colors,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}