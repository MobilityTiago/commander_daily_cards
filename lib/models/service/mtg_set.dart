class MTGSet {
  final String id;
  final String code;
  final String name;
  final String? iconSvgUri;

  const MTGSet({
    required this.id,
    required this.code,
    required this.name,
    this.iconSvgUri,
  });

  factory MTGSet.fromJson(Map<String, dynamic> json) {
    return MTGSet(
      id: json['id'] ?? '',
      code: (json['code'] ?? '').toString().toLowerCase(),
      name: json['name'] ?? '',
      iconSvgUri: json['icon_svg_uri'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'icon_svg_uri': iconSvgUri,
    };
  }
}
