import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_preferences_service.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_bar.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({super.key});

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final FocusNode _usernameFocusNode;
  late final FocusNode _emailFocusNode;
  bool _controllersInitialized = false;
  bool _isSaving = false;
  bool _pendingSave = false;
  PricePreference _selectedPricePreference = PricePreference.none;
  MarketPreference _selectedMarketPreference = MarketPreference.tcgplayer;
  bool _persistentFiltersEnabled = true;
  String _savedUsername = '';
  String _savedEmail = '';
  PricePreference _savedPricePreference = PricePreference.none;
  MarketPreference _savedMarketPreference = MarketPreference.tcgplayer;
  bool _savedPersistentFiltersEnabled = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _usernameFocusNode = FocusNode()..addListener(_handleTextFieldBlur);
    _emailFocusNode = FocusNode()..addListener(_handleTextFieldBlur);
  }

  @override
  void dispose() {
    _usernameFocusNode
      ..removeListener(_handleTextFieldBlur)
      ..dispose();
    _emailFocusNode
      ..removeListener(_handleTextFieldBlur)
      ..dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleTextFieldBlur() {
    if (_usernameFocusNode.hasFocus || _emailFocusNode.hasFocus) {
      return;
    }
    unawaited(_saveIfChanged());
  }

  bool _hasUnsavedChanges() {
    return _usernameController.text != _savedUsername ||
        _emailController.text != _savedEmail ||
        _selectedPricePreference != _savedPricePreference ||
        _selectedMarketPreference != _savedMarketPreference ||
        _persistentFiltersEnabled != _savedPersistentFiltersEnabled;
  }

  void _captureSavedState() {
    _savedUsername = _usernameController.text;
    _savedEmail = _emailController.text;
    _savedPricePreference = _selectedPricePreference;
    _savedMarketPreference = _selectedMarketPreference;
    _savedPersistentFiltersEnabled = _persistentFiltersEnabled;
  }

  Future<void> _saveIfChanged() async {
    if (!_controllersInitialized || !_hasUnsavedChanges()) {
      return;
    }

    if (_isSaving) {
      _pendingSave = true;
      return;
    }

    final preferences = context.read<UserPreferencesService>();

    setState(() {
      _isSaving = true;
    });

    await preferences.savePreferences(
      username: _usernameController.text,
      email: _emailController.text,
      pricePreference: _selectedPricePreference,
      marketPreference: _selectedMarketPreference,
      persistentFiltersEnabled: _persistentFiltersEnabled,
    );

    _captureSavedState();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    AppHaptics.confirm();

    if (_pendingSave) {
      _pendingSave = false;
      unawaited(_saveIfChanged());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(title: 'User preferences'),
      body: Consumer<UserPreferencesService>(
        builder: (context, preferences, _) {
          if (!preferences.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_controllersInitialized) {
            _usernameController.text = preferences.username ?? '';
            _emailController.text = preferences.email ?? '';
            _selectedPricePreference = preferences.pricePreference;
            _selectedMarketPreference = preferences.marketPreference;
            _persistentFiltersEnabled = preferences.persistentFiltersEnabled;
            _captureSavedState();
            _controllersInitialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Price preference',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PricePreference>(
                initialValue: _selectedPricePreference,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PricePreference.none,
                    child: Text('None'),
                  ),
                  DropdownMenuItem(
                    value: PricePreference.both,
                    child: Text('Both (USD + EUR)'),
                  ),
                  DropdownMenuItem(
                    value: PricePreference.usd,
                    child: Text('US Dollars (\$)'),
                  ),
                  DropdownMenuItem(
                    value: PricePreference.eur,
                    child: Text('Euros (€)'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPricePreference = value;
                  });
                  AppHaptics.selection();
                  unawaited(_saveIfChanged());
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Market preference',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MarketPreference>(
                initialValue: _selectedMarketPreference,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MarketPreference.tcgplayer,
                    child: Text('TCGPlayer'),
                  ),
                  DropdownMenuItem(
                    value: MarketPreference.cardmarket,
                    child: Text('CardMarket'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMarketPreference = value;
                  });
                  AppHaptics.selection();
                  unawaited(_saveIfChanged());
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Persistent filters'),
                subtitle: const Text(
                  'Keep filters between app sessions for search and daily views',
                ),
                value: _persistentFiltersEnabled,
                onChanged: (value) {
                  setState(() {
                    _persistentFiltersEnabled = value;
                  });
                  AppHaptics.selection();
                  unawaited(_saveIfChanged());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
