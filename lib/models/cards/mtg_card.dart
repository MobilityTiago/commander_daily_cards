class MTGCard {
  final String id;
  final String name;
  final String? manaCost;
  final double cmc;
  final String? typeLine;
  final String? oracleText;
  final List<String>? colors;
  final List<String>? colorIdentity;
  final List<String>? keywords;
  final List<String>? producedMana;
  final Map<String, String> legalities;
  final ImageUris? imageUris;
  final bool gameChanger;
  final String? artist;
  final String? rarity;
  final String? power;     // Added power field
  final String? toughness; // Added toughness field
  final String? loyalty;  // Added loyalty field

  MTGCard({
    required this.id,
    required this.name,
    this.manaCost,
    required this.cmc,
    this.typeLine,
    this.oracleText,
    this.colors,
    this.colorIdentity,
    this.keywords,
    this.producedMana,
    required this.legalities,
    this.imageUris,
    this.gameChanger = false,
    this.artist,
    this.rarity,
    this.power,     // Added to constructor
    this.toughness, // Added to constructor
    this.loyalty,        // Added to constructor
  });

  factory MTGCard.fromJson(Map<String, dynamic> json) {
    return MTGCard(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      manaCost: json['mana_cost'],
      cmc: (json['cmc'] ?? 0).toDouble(),
      typeLine: json['type_line'],
      oracleText: json['oracle_text'],
      colors: json['colors']?.cast<String>(),
      colorIdentity: json['color_identity']?.cast<String>(),
      keywords: json['keywords']?.cast<String>(),
      producedMana: json['produced_mana']?.cast<String>(),
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      imageUris: json['image_uris'] != null
          ? ImageUris.fromJson(json['image_uris'])
          : null,
      gameChanger: json['game_changer'] ?? false,
      artist: json['artist'],
      rarity: json['rarity']?.toLowerCase(),
      power: json['power'],     // Parse from JSON
      toughness: json['toughness'], // Parse from JSON
      loyalty: json['loyalty'],  // Parse from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mana_cost': manaCost,
      'cmc': cmc,
      'type_line': typeLine,
      'oracle_text': oracleText,
      'colors': colors,
      'color_identity': colorIdentity,
      'keywords': keywords,
      'produced_mana': producedMana,
      'legalities': legalities,
      'image_uris': imageUris?.toJson(),
      'game_changer': gameChanger,
      'artist': artist,
      'rarity': rarity,
      'power': power,         // Add to JSON
      'toughness': toughness, // Add to JSON
      'loyalty': loyalty,        // Add to JSON
    };
  }

  String? get imageUrl {
    return imageUris?.normal ?? imageUris?.small;
  }

  bool get isCommanderLegal {
    return legalities['commander'] == 'legal';
  }

  // Add helper method to check if card is a creature
  bool get isCreature {
    return typeLine?.toLowerCase().contains('creature') ?? false;
  }

  // Add helper method to get power/toughness string
  String? get powerToughness {
    return isCreature ? '$power/$toughness' : null;
  }

  // Add helper method to check if card is a planeswalker
  bool get isPlaneswalker {
    return typeLine?.toLowerCase().contains('planeswalker') ?? false;
  }
}

class ImageUris {
  final String? small;
  final String? normal;
  final String? large;
  final String? artCrop;  // Added art_crop field

  ImageUris({
    this.small,
    this.normal,
    this.large,
    this.artCrop,  // Added to constructor
  });

  factory ImageUris.fromJson(Map<String, dynamic> json) {
    return ImageUris(
      small: json['small'],
      normal: json['normal'],
      large: json['large'],
      artCrop: json['art_crop'],  // Parse from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'small': small,
      'normal': normal,
      'large': large,
      'art_crop': artCrop,  // Add to JSON
    };
  }
}
