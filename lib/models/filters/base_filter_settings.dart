import 'package:flutter/material.dart';
import '../cards/mtg_card.dart';

abstract class BaseFilterSettings extends ChangeNotifier {
  String _keywords = '';
  
  String get keywords => _keywords;

  void setKeywords(String keywords) {
    _keywords = keywords;
    notifyListeners();
  }

  bool matchesCard(MTGCard card);
}