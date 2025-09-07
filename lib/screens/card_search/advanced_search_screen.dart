import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import '../../models/cards/card_enums.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _oracleController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  Set<MTGColor> _selectedColors = {};
  Set<CardType> _selectedTypes = {};
  RangeValues _cmc = const RangeValues(0, 16);

  @override
  void dispose() {
    _nameController.dispose();
    _oracleController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'Advanced Search',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchField(
            controller: _nameController,
            label: 'Card Name',
            hint: 'Enter card name...',
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _oracleController,
            label: 'Oracle Text',
            hint: 'Enter card text...',
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _typeController,
            label: 'Type Line',
            hint: 'Enter card type...',
          ),
          const SizedBox(height: 24),
          Text(
            'Mana Value',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RangeSlider(
            values: _cmc,
            min: 0,
            max: 16,
            divisions: 16,
            labels: RangeLabels(
              _cmc.start.round().toString(),
              _cmc.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _cmc = values;
              });
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Colors',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: MTGColor.values.map((color) {
              return FilterChip(
                label: Text(color.displayName),
                selected: _selectedColors.contains(color),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedColors.add(color);
                    } else {
                      _selectedColors.remove(color);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Card Types',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: CardType.values.map((type) {
              return FilterChip(
                label: Text(type.displayName),
                selected: _selectedTypes.contains(type),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTypes.add(type);
                    } else {
                      _selectedTypes.remove(type);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement advanced search
            },
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Search'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
          ),
          style: const TextStyle(color: Color(0xFFF5F5F5)),
        ),
      ],
    );
  }
}