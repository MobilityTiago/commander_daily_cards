import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_preferences_service.dart';
import '../../widgets/app_bar.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({super.key});

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  bool _controllersInitialized = false;
  bool _isSaving = false;
  PricePreference _selectedPricePreference = PricePreference.none;
  MarketPreference _selectedMarketPreference = MarketPreference.tcgplayer;
  bool _persistentFiltersEnabled = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save(UserPreferencesService preferences) async {
    if (_isSaving) return;

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

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences saved')),
    );
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
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
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
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : () => _save(preferences),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save preferences'),
              ),
            ],
          );
        },
      ),
    );
  }
}
