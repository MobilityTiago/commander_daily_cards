import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import '../styles/colors.dart';
import '../models/cards/mtg_card.dart';

class CardZoomView extends StatefulWidget {
  final List<MTGCard> cards;
  final int initialIndex;

  const CardZoomView({
    super.key,
    required this.cards,
    required this.initialIndex,
  });

  @override
  State<CardZoomView> createState() => _CardZoomViewState();
}

class _CardZoomViewState extends State<CardZoomView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showOptions(MTGCard card) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.darkGrey,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                'Copy All Details',
                _getAllCardDetails(card),
              ),
              const Divider(color: AppColors.lightGrey),
              _buildOption(
                'Copy Name and Mana Cost',
                '${card.name} ${card.manaCost ?? ""}',
              ),
              _buildOption(
                'Copy Type Line',
                card.typeLine ?? '',
              ),
              _buildOption(
                'Copy Rules Text',
                card.oracleText ?? '',
              ),
              if (card.power != null && card.toughness != null)
                _buildOption(
                  'Copy Power/Toughness',
                  '${card.power}/${card.toughness}',
                ),
              if (card.isPlaneswalker && card.loyalty != null)
                _buildOption(
                  'Copy Loyalty',
                  card.loyalty!,
                ),
              const Divider(color: AppColors.lightGrey),
              ListTile(
                leading: const Icon(Icons.save_alt, color: AppColors.white),
                title: const Text(
                  'Save Card Art',
                  style: TextStyle(color: AppColors.white),
                ),
                onTap: () => _saveCardArt(card),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: AppColors.white),
                title: const Text(
                  'Save Art Crop',
                  style: TextStyle(color: AppColors.white),
                ),
                onTap: () => _saveArtCrop(card),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await Clipboard.setData(ClipboardData(text: result));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    }
  }

  Widget _buildOption(String title, String content) {
    return ListTile(
      leading: const Icon(Icons.copy, color: AppColors.white),
      title: Text(title, style: const TextStyle(color: AppColors.white)),
      onTap: () => Navigator.pop(context, content),
    );
  }

  Future<void> _saveCardArt(MTGCard card) async {
    if (card.imageUris?.normal != null) {
      Navigator.pop(context);
      try {
        final response = await http.get(Uri.parse(card.imageUris!.normal!));
        final result = await ImageGallerySaver.saveImage(
          response.bodyBytes,
          name: '${card.name.replaceAll(RegExp(r'[^\w\s-]'), '')}_full',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['isSuccess'] 
                  ? 'Card art saved to gallery' 
                  : 'Failed to save card art'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save card art')),
          );
        }
      }
    }
  }

  Future<void> _saveArtCrop(MTGCard card) async {
    if (card.imageUris?.artCrop != null) {
      Navigator.pop(context);
      try {
        final response = await http.get(Uri.parse(card.imageUris!.artCrop!));
        final result = await ImageGallerySaver.saveImage(
          response.bodyBytes,
          name: card.name.replaceAll(RegExp(r'[^\w\s-]'), ''),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['isSuccess'] 
                  ? 'Art saved to gallery' 
                  : 'Failed to save art'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save art')),
          );
        }
      }
    }
  }

  String _getAllCardDetails(MTGCard card) {
    final buffer = StringBuffer();
    
    // Name and mana cost
    buffer.writeln('${card.name} ${card.manaCost ?? ""}');
    
    // Type line
    if (card.typeLine != null) {
      buffer.writeln(card.typeLine);
    }
    
    // Oracle text
    if (card.oracleText != null) {
      buffer.writeln('\n${card.oracleText}');
    }
    
    // Power/Toughness for creatures
    if (card.power != null && card.toughness != null) {
      buffer.writeln('\n${card.power}/${card.toughness}');
    }
    
    // Loyalty for planeswalkers
    if (card.isPlaneswalker && card.loyalty != null) {
      buffer.writeln('\nLoyalty: ${card.loyalty}');
    }
    
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black.withOpacity(0.8),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onLongPress: () => _showOptions(widget.cards[_currentIndex]),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.cards.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            final card = widget.cards[index];
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    Hero(
                      tag: card.imageUris?.normal ?? '',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          card.imageUris?.normal ?? '',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (card.gameChanger)
                      Positioned(
                        top: 0,
                        left: 0,  // Changed from right to left
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),  // Changed from topRight
                              bottomRight: Radius.circular(16),  // Changed from bottomLeft
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'GC',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}