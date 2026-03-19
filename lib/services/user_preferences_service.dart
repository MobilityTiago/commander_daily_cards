import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PricePreference {
  none,
  both,
  usd,
  eur,
}

enum MarketPreference {
  tcgplayer,
  cardmarket,
}

class UserPreferencesService extends ChangeNotifier {
  static const String _installationIdKey = 'prefs_installation_id';
  static const String _prefsDataPrefix = 'user_preferences_';

  bool _isLoaded = false;
  String? _username;
  String? _email;
  PricePreference _pricePreference = PricePreference.none;
  MarketPreference _marketPreference = MarketPreference.tcgplayer;
  bool _persistentFiltersEnabled = true;
  String? _installationId;

  bool get isLoaded => _isLoaded;
  String? get username => _username;
  String? get email => _email;
  PricePreference get pricePreference => _pricePreference;
  MarketPreference get marketPreference => _marketPreference;
  bool get persistentFiltersEnabled => _persistentFiltersEnabled;

  UserPreferencesService() {
    unawaited(load());
  }

  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    _installationId = prefs.getString(_installationIdKey);

    if (_installationId == null || _installationId!.isEmpty) {
      _installationId = _generateInstallationScopedId();
      await prefs.setString(_installationIdKey, _installationId!);
    }

    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          _username = _normalizeOptional(decoded['username'] as String?);
          _email = _normalizeOptional(decoded['email'] as String?);
          _pricePreference =
              _decodePricePreference(decoded['pricePreference'] as String?);
          _marketPreference =
              _decodeMarketPreference(decoded['marketPreference'] as String?);
          _persistentFiltersEnabled =
              decoded['persistentFiltersEnabled'] as bool? ?? true;
        }
      } catch (_) {
        // Keep defaults when local data is invalid.
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> savePreferences({
    String? username,
    String? email,
    required PricePreference pricePreference,
    required MarketPreference marketPreference,
    required bool persistentFiltersEnabled,
  }) async {
    await _ensureLoaded();

    _username = _normalizeOptional(username);
    _email = _normalizeOptional(email);
    _pricePreference = pricePreference;
    _marketPreference = marketPreference;
    _persistentFiltersEnabled = persistentFiltersEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode({
        'username': _username,
        'email': _email,
        'pricePreference': _pricePreference.name,
        'marketPreference': _marketPreference.name,
        'persistentFiltersEnabled': _persistentFiltersEnabled,
      }),
    );

    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    await load();
  }

  String get _storageKey => '$_prefsDataPrefix$_installationId';

  String _generateInstallationScopedId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = Random().nextInt(1 << 32);
    return 'local-$now-$randomPart';
  }

  String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  PricePreference _decodePricePreference(String? value) {
    return PricePreference.values.firstWhere(
      (option) => option.name == value,
      orElse: () => PricePreference.none,
    );
  }

  MarketPreference _decodeMarketPreference(String? value) {
    return MarketPreference.values.firstWhere(
      (option) => option.name == value,
      orElse: () => MarketPreference.tcgplayer,
    );
  }
}
