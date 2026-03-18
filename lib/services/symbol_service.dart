import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service/card_symbol.dart';

class SymbolService extends ChangeNotifier {
  static const String _symbologyUrl = 'https://api.scryfall.com/symbology';
  static const String _symbolsCacheKey = 'ScryfallSymbolsCache';
  static const String _symbolsCacheDateKey = 'ScryfallSymbolsCacheDate';
  static const String _symbolSvgCacheKey = 'ScryfallSymbolSvgCache';
  static const Duration _cacheDuration = Duration(days: 7);
  static const Map<String, String> _scryfallHeaders = {
    'User-Agent': 'Command/1.0 (https://github.com/yourname/commander_daily_cards)',
    'Accept': 'application/json',
  };

  List<CardSymbol> _symbols = [];
  Map<String, String> _svgByToken = {};
  bool _isLoading = false;
  DateTime? _lastUpdated;
  final Set<String> _attemptedTokenRefresh = {};

  List<CardSymbol> get symbols => List.unmodifiable(_symbols);
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  static const Set<String> _coreManaTokens = {
    '{W}',
    '{U}',
    '{B}',
    '{R}',
    '{G}',
    '{C}',
  };

  CardSymbol? symbolByToken(String token) {
    for (final item in _symbols) {
      if (item.symbol == token) return item;
    }
    return null;
  }

  String? svgDataByToken(String token) {
    return _svgByToken[token];
  }

  /// Tries a single background refresh when a symbol is missing from cache.
  ///
  /// This avoids repeatedly hammering the API while still giving the app a
  /// chance to recover missing symbol data.
  void requestRefreshOnMiss(String token) {
    if (_isLoading) return;
    if (_svgByToken[token]?.isNotEmpty == true) return;
    if (_attemptedTokenRefresh.contains(token)) return;

    _attemptedTokenRefresh.add(token);
    unawaited(_refreshMissingToken(token));
  }

  Future<void> _refreshMissingToken(String token) async {
    try {
      if (symbolByToken(token) == null) {
        await loadSymbols(forceRefresh: true);
      }

      if (_svgByToken[token]?.isNotEmpty == true) return;

      final symbol = symbolByToken(token);
      final svgUri = symbol?.svgUri;
      if (svgUri == null || svgUri.isEmpty) return;

      final response = await http.get(
        Uri.parse(svgUri),
        headers: _scryfallHeaders,
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        _svgByToken = {
          ..._svgByToken,
          token: response.body,
        };
        await _saveToCache();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing symbol $token: $e');
    }
  }

  Future<void> loadSymbols({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromCache();

      final shouldRefresh = forceRefresh ||
          _symbols.isEmpty ||
          _lastUpdated == null ||
          DateTime.now().difference(_lastUpdated!) > _cacheDuration;

      if (shouldRefresh) {
        await _fetchAndSaveSymbols();
      }
    } catch (e) {
      debugPrint('Error loading symbols: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchAndSaveSymbols() async {
    final response = await http.get(
      Uri.parse(_symbologyUrl),
      headers: _scryfallHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch symbols: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = CardSymbolResponse.fromJson(data);

    _symbols = parsed.data;
    _lastUpdated = DateTime.now();

    await _fetchCoreManaSymbolSvgs();

    await _saveToCache();
  }

  Future<void> _fetchCoreManaSymbolSvgs() async {
    final nextSvgByToken = <String, String>{..._svgByToken};

    for (final token in _coreManaTokens) {
      if (nextSvgByToken[token]?.isNotEmpty == true) continue;

      final symbol = symbolByToken(token);
      final svgUri = symbol?.svgUri;
      if (svgUri == null || svgUri.isEmpty) continue;

      try {
        final response = await http.get(
          Uri.parse(svgUri),
          headers: _scryfallHeaders,
        );
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          nextSvgByToken[token] = response.body;
        }
      } catch (_) {
        // Keep graceful fallback behavior when network requests fail.
      }
    }

    _svgByToken = nextSvgByToken;
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = CardSymbolResponse(data: _symbols).toJson();

    await prefs.setString(_symbolsCacheKey, jsonEncode(payload));
    await prefs.setString(
      _symbolsCacheDateKey,
      (_lastUpdated ?? DateTime.now()).toIso8601String(),
    );
    await prefs.setString(_symbolSvgCacheKey, jsonEncode(_svgByToken));
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(_symbolsCacheKey);
    final cachedDate = prefs.getString(_symbolsCacheDateKey);
    final cachedSvg = prefs.getString(_symbolSvgCacheKey);

    if (cached == null || cached.isEmpty) return;

    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    final parsed = CardSymbolResponse.fromJson(decoded);

    _symbols = parsed.data;
    _lastUpdated = cachedDate != null ? DateTime.tryParse(cachedDate) : null;

    if (cachedSvg != null && cachedSvg.isNotEmpty) {
      final decodedSvg = jsonDecode(cachedSvg) as Map<String, dynamic>;
      _svgByToken = decodedSvg.map((k, v) => MapEntry(k, v.toString()));
    }
  }
}