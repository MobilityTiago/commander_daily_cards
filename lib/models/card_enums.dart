enum CardType {
  creature('Creature'),
  instant('Instant'),
  sorcery('Sorcery'),
  enchantment('Enchantment'),
  artifact('Artifact'),
  planeswalker('Planeswalker'),
  land('Land');

  const CardType(this.displayName);
  final String displayName;
}

enum MTGColor {
  white('W', 'White'),
  blue('U', 'Blue'),
  black('B', 'Black'),
  red('R', 'Red'),
  green('G', 'Green'),
  colorless('C', 'Colorless');

  const MTGColor(this.symbol, this.displayName);
  final String symbol;
  final String displayName;
}