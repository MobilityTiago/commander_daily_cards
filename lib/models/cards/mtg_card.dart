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
  final String? setCode;
  final String? setName;
  final String? lang;
  final List<String>? games;
  final double? usd;
  final double? eur;
  final double? tix;
  final String? power; // Added power field
  final String? toughness; // Added toughness field
  final String? loyalty; // Added loyalty field
  final List<CardFace>? cardFaces;

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
    this.setCode,
    this.setName,
    this.lang,
    this.games,
    this.usd,
    this.eur,
    this.tix,
    this.power, // Added to constructor
    this.toughness, // Added to constructor
    this.loyalty, // Added to constructor
    this.cardFaces,
  });

  factory MTGCard.fromJson(Map<String, dynamic> json) {
    return MTGCard(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      manaCost: json['mana_cost'],
      cmc: _parseDouble(json['cmc'], defaultValue: 0),
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
      setCode: json['set'],
      setName: json['set_name'],
      lang: json['lang'],
      games: (json['games'] as List?)?.cast<String>(),
      usd: _parseDouble(json['prices']?['usd']),
      eur: _parseDouble(json['prices']?['eur']),
      tix: _parseDouble(json['prices']?['tix']),
      power: _parseString(json['power']), // Parse from JSON (string or number)
      toughness:
          _parseString(json['toughness']), // Parse from JSON (string or number)
      loyalty:
          _parseString(json['loyalty']), // Parse from JSON (string or number)
      cardFaces: (json['card_faces'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(CardFace.fromJson)
          .toList(),
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
      'set': setCode,
      'set_name': setName,
      'lang': lang,
      'games': games,
      'prices': {
        'usd': usd,
        'eur': eur,
        'tix': tix,
      },
      'power': power, // Add to JSON
      'toughness': toughness, // Add to JSON
      'loyalty': loyalty, // Add to JSON
      'card_faces': cardFaces?.map((f) => f.toJson()).toList(),
    };
  }

  String? get imageUrl {
    return mainFaceImageUrl;
  }

  String? get mainFaceImageUrl {
    final firstFace =
        (cardFaces != null && cardFaces!.isNotEmpty) ? cardFaces!.first : null;

    return imageUris?.normal ??
        imageUris?.large ??
        imageUris?.small ??
        firstFace?.imageUris?.normal ??
        firstFace?.imageUris?.large ??
        firstFace?.imageUris?.small;
  }

  bool get hasDoubleFacedImages {
    final faces = cardFaces;
    if (faces == null || faces.length < 2) return false;

    final firstHasImage = faces[0].imageUris?.normal != null ||
        faces[0].imageUris?.large != null ||
        faces[0].imageUris?.small != null;
    final secondHasImage = faces[1].imageUris?.normal != null ||
        faces[1].imageUris?.large != null ||
        faces[1].imageUris?.small != null;
    return firstHasImage && secondHasImage;
  }

  bool get isCommanderLegal {
    return legalities['commander'] == 'legal';
  }

  String get combinedTypeLine {
    final parts = <String>[];
    if (typeLine != null && typeLine!.isNotEmpty) {
      parts.add(typeLine!);
    }
    if (cardFaces != null) {
      for (final face in cardFaces!) {
        final faceType = face.typeLine;
        if (faceType != null && faceType.isNotEmpty) {
          parts.add(faceType);
        }
      }
    }
    return parts.join(' // ');
  }

  String get combinedOracleText {
    final parts = <String>[];
    if (oracleText != null && oracleText!.isNotEmpty) {
      parts.add(oracleText!);
    }
    if (cardFaces != null) {
      for (final face in cardFaces!) {
        final faceOracle = face.oracleText;
        if (faceOracle != null && faceOracle.isNotEmpty) {
          parts.add(faceOracle);
        }
      }
    }
    return parts.join('\n');
  }

  String get normalizedCombinedTypeLine => combinedTypeLine.toLowerCase();

  String get normalizedCombinedOracleText => combinedOracleText.toLowerCase();

  bool get _hasAnyPowerToughness {
    if ((power != null && power!.isNotEmpty) ||
        (toughness != null && toughness!.isNotEmpty)) {
      return true;
    }

    if (cardFaces != null) {
      for (final face in cardFaces!) {
        if ((face.power != null && face.power!.isNotEmpty) ||
            (face.toughness != null && face.toughness!.isNotEmpty)) {
          return true;
        }
      }
    }

    return false;
  }

  bool get canBeCommander {
    if (!isCommanderLegal) return false;

    final type = normalizedCombinedTypeLine;
    final oracle = normalizedCombinedOracleText;

    final isLegendaryCreature =
        type.contains('legendary') && type.contains('creature');
    final isLegendaryPlaneswalker =
        type.contains('legendary') && type.contains('planeswalker');
    final isLegendaryBackground =
        type.contains('legendary enchantment') && type.contains('background');
    final isLegendaryVehicleOrSpacecraft =
        type.contains('legendary') &&
        (type.contains('vehicle') || type.contains('spacecraft'));
    final isPermanent = type.contains('artifact') ||
        type.contains('battle') ||
        type.contains('creature') ||
        type.contains('enchantment') ||
        type.contains('land') ||
        type.contains('planeswalker');

    final hasExplicitCommanderText = oracle.contains('can be your commander');
    final hasPartnerLikeText = oracle.contains('partner') ||
        oracle.contains('friends forever') ||
        oracle.contains("doctor's companion") ||
        oracle.contains('choose a background');

    return isLegendaryCreature ||
        (isPermanent && hasExplicitCommanderText) ||
        ((isLegendaryCreature || isLegendaryPlaneswalker) && hasPartnerLikeText) ||
        isLegendaryBackground ||
        (isLegendaryVehicleOrSpacecraft && _hasAnyPowerToughness);
  }

        bool get canBePrimaryCommander => canBeCommander && !isBackgroundCommanderCard;

  bool get isBackgroundCommanderCard =>
      normalizedCombinedTypeLine.contains('legendary enchantment') &&
      normalizedCombinedTypeLine.contains('background');

  bool get hasChooseABackground =>
      normalizedCombinedOracleText.contains('choose a background');

  bool get hasFriendsForever =>
      normalizedCombinedOracleText.contains('friends forever');

  bool get hasDoctorsCompanion =>
      normalizedCombinedOracleText.contains("doctor's companion");

  bool get hasPartnerWith =>
      normalizedCombinedOracleText.contains('partner with ');

  bool get hasGenericPartner =>
      normalizedCombinedOracleText.contains('partner') && !hasPartnerWith;

    bool get isDoctor => normalizedCombinedTypeLine.contains('doctor');

  bool get supportsAdditionalCommanderChoice =>
      hasChooseABackground ||
      isBackgroundCommanderCard ||
      hasGenericPartner ||
      hasPartnerWith ||
      hasFriendsForever ||
      hasDoctorsCompanion;

  String? get partnerWithName {
    for (final line in combinedOracleText.split('\n')) {
      final lower = line.toLowerCase();
      const marker = 'partner with ';
      final index = lower.indexOf(marker);
      if (index == -1) continue;
      return line.substring(index + marker.length).trim();
    }
    return null;
  }

  bool canPairWithAsCommander(MTGCard other) {
    if (id == other.id) return false;
    if (!canBeCommander || !other.canBeCommander) return false;

    if (hasChooseABackground && other.isBackgroundCommanderCard) return true;
    if (isBackgroundCommanderCard && other.hasChooseABackground) return true;

    final partnerName = partnerWithName;
    if (partnerName != null && other.name.toLowerCase() == partnerName.toLowerCase()) {
      return true;
    }

    final otherPartnerName = other.partnerWithName;
    if (otherPartnerName != null && name.toLowerCase() == otherPartnerName.toLowerCase()) {
      return true;
    }

    if (hasFriendsForever && other.hasFriendsForever) return true;
    if (hasGenericPartner && other.hasGenericPartner) return true;

    final isDoctor = normalizedCombinedTypeLine.contains('doctor');
    final otherIsDoctor = other.normalizedCombinedTypeLine.contains('doctor');
    if (hasDoctorsCompanion && otherIsDoctor) return true;
    if (other.hasDoctorsCompanion && isDoctor) return true;

    return false;
  }

  bool isValidAdditionalCommanderCandidate(MTGCard other) {
    if (id == other.id) return false;
    if (!canBeCommander || !other.canBeCommander) return false;

    if (hasChooseABackground) return other.isBackgroundCommanderCard;
    if (isBackgroundCommanderCard) return other.hasChooseABackground;

    final partnerName = partnerWithName;
    if (partnerName != null) {
      final target = partnerName.toLowerCase();
      return other.name.toLowerCase() == target ||
          (other.partnerWithName?.toLowerCase() == name.toLowerCase()) ||
          (other.partnerWithName?.toLowerCase() == target);
    }

    if (hasFriendsForever) return other.hasFriendsForever;
    if (hasDoctorsCompanion) return other.isDoctor;
    if (hasGenericPartner) return other.hasGenericPartner;

    return false;
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

  static double _parseDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}

class CardFace {
  final String? name;
  final String? manaCost;
  final String? typeLine;
  final String? oracleText;
  final String? power;
  final String? toughness;
  final ImageUris? imageUris;

  CardFace({
    this.name,
    this.manaCost,
    this.typeLine,
    this.oracleText,
    this.power,
    this.toughness,
    this.imageUris,
  });

  factory CardFace.fromJson(Map<String, dynamic> json) {
    return CardFace(
      name: json['name'],
      manaCost: json['mana_cost'],
      typeLine: json['type_line'],
      oracleText: json['oracle_text'],
      power: MTGCard._parseString(json['power']),
      toughness: MTGCard._parseString(json['toughness']),
      imageUris: json['image_uris'] != null
          ? ImageUris.fromJson(json['image_uris'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mana_cost': manaCost,
      'type_line': typeLine,
      'oracle_text': oracleText,
      'power': power,
      'toughness': toughness,
      'image_uris': imageUris?.toJson(),
    };
  }
}

class ImageUris {
  final String? small;
  final String? normal;
  final String? large;
  final String? artCrop; // Added art_crop field

  ImageUris({
    this.small,
    this.normal,
    this.large,
    this.artCrop, // Added to constructor
  });

  factory ImageUris.fromJson(Map<String, dynamic> json) {
    return ImageUris(
      small: json['small'],
      normal: json['normal'],
      large: json['large'],
      artCrop: json['art_crop'], // Parse from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'small': small,
      'normal': normal,
      'large': large,
      'art_crop': artCrop, // Add to JSON
    };
  }
}
