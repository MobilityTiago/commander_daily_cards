import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service/mtg_set.dart';

class SetService extends ChangeNotifier {
  static const String _setsUrl = 'https://api.scryfall.com/sets';
  static const String _setsCacheKey = 'ScryfallSetsCache';
  static const String _setsCacheDateKey = 'ScryfallSetsCacheDate';
  static const String _setIconSvgCacheKey = 'ScryfallSetIconSvgCache';
  static const Duration _cacheDuration = Duration(days: 14);
  static const Map<String, String> _scryfallHeaders = {
    'User-Agent': 'Command/1.0 (https://github.com/yourname/commander_daily_cards)',
    'Accept': 'application/json',
  };

  List<MTGSet> _sets = [];
  Map<String, String> _iconSvgBySetCode = {};
  bool _isLoading = false;
  DateTime? _lastUpdated;

  List<MTGSet> get sets => List.unmodifiable(_sets);
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  MTGSet? setByCode(String code) {
    final normalized = code.toLowerCase();
    for (final set in _sets) {
      if (set.code == normalized) return set;
    }
    return null;
  }

  String? iconSvgBySetCode(String code) {
    return _iconSvgBySetCode[code.toLowerCase()];
  }

  Future<void> loadSets({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromCache();

      final shouldRefresh = forceRefresh ||
          _sets.isEmpty ||
          _lastUpdated == null ||
          DateTime.now().difference(_lastUpdated!) > _cacheDuration;

      if (shouldRefresh) {
        await _fetchAndSaveSets();
      }
    } catch (e) {
      debugPrint('Error loading sets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchAndSaveSets() async {
    Uri nextUrl = Uri.parse(_setsUrl);
    final fetched = <MTGSet>[];

    while (true) {
      final response = await http
          .get(nextUrl, headers: _scryfallHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sets: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
      fetched.addAll(items.map(MTGSet.fromJson));

      final hasMore = data['has_more'] == true;
      final nextPage = data['next_page'] as String?;
      if (!hasMore || nextPage == null || nextPage.isEmpty) {
        break;
      }

      nextUrl = Uri.parse(nextPage);
    }

    _sets = fetched;
    _lastUpdated = DateTime.now();

    await _fetchMissingSetIconSvgs();
    await _saveToCache();
  }

  Future<void> _fetchMissingSetIconSvgs() async {
    final next = <String, String>{..._iconSvgBySetCode};

    for (final set in _sets) {
      final code = set.code.toLowerCase();
      if (next[code]?.isNotEmpty == true) continue;
      final iconUri = set.iconSvgUri;
      if (iconUri == null || iconUri.isEmpty) continue;

      try {
        final response = await http
            .get(Uri.parse(iconUri), headers: _scryfallHeaders)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          next[code] = response.body;
        }
      } catch (_) {
        // Keep best-effort behavior for individual icon fetches.
      }
    }

    _iconSvgBySetCode = next;
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _setsCacheKey,
      jsonEncode(_sets.map((set) => set.toJson()).toList()),
    );
    await prefs.setString(
      _setsCacheDateKey,
      (_lastUpdated ?? DateTime.now()).toIso8601String(),
    );
    await prefs.setString(_setIconSvgCacheKey, jsonEncode(_iconSvgBySetCode));
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedSets = prefs.getString(_setsCacheKey);
    final cachedDate = prefs.getString(_setsCacheDateKey);
    final cachedIcons = prefs.getString(_setIconSvgCacheKey);

    if (cachedSets != null && cachedSets.isNotEmpty) {
      final decoded = jsonDecode(cachedSets) as List;
      _sets = decoded
          .whereType<Map<String, dynamic>>()
          .map(MTGSet.fromJson)
          .toList();
    }

    if (cachedDate != null && cachedDate.isNotEmpty) {
      _lastUpdated = DateTime.tryParse(cachedDate);
    }

    if (cachedIcons != null && cachedIcons.isNotEmpty) {
      final decoded = jsonDecode(cachedIcons) as Map<String, dynamic>;
      _iconSvgBySetCode = decoded.map(
        (key, value) => MapEntry(key.toLowerCase(), value.toString()),
      );
    }
  }
}
