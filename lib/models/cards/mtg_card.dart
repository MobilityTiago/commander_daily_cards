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
  final List<String>? producedMana;  // Changed to proper type
  final Map<String, String> legalities;
  final ImageUris? imageUris;
  final bool gameChanger;
  final String? artist;  // Add artist field
  final String? rarity; 

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
    this.producedMana,  // Added to constructor
    required this.legalities,
    this.imageUris,
    this.gameChanger = false,
    this.artist, 
    this.rarity,
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
      producedMana: json['produced_mana']?.cast<String>(),  // Added JSON parsing
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      imageUris: json['image_uris'] != null
          ? ImageUris.fromJson(json['image_uris'])
          : null,
      gameChanger: json['game_changer'] ?? false,
      artist: json['artist'],  // Parse from JSON
      rarity: json['rarity']?.toLowerCase(),  // Parse and normalize rarity
    
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
      'produced_mana': producedMana,  // Added to JSON serialization
      'legalities': legalities,
      'image_uris': imageUris?.toJson(),
      'game_changer': gameChanger,  // Also added gameChanger to ensure it's saved
      'artist': artist,  // Add to JSON
      'rarity': rarity,  // Added to JSON serialization
   
    };
  }
  String? get imageUrl {
    return imageUris?.normal ?? imageUris?.small;
  }

  bool get isCommanderLegal {
    return legalities['commander'] == 'legal';
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
