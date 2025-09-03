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
  final Map<String, String> legalities;
  final ImageUris? imageUris;

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
    required this.legalities,
    this.imageUris,
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
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      imageUris: json['image_uris'] != null
          ? ImageUris.fromJson(json['image_uris'])
          : null,
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
      'legalities': legalities,
      'image_uris': imageUris?.toJson(),
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

  ImageUris({
    this.small,
    this.normal,
    this.large,
  });

  factory ImageUris.fromJson(Map<String, dynamic> json) {
    return ImageUris(
      small: json['small'],
      normal: json['normal'],
      large: json['large'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'small': small,
      'normal': normal,
      'large': large,
    };
  }
}
