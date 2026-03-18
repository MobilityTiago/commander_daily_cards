import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../models/cards/mtg_card.dart';
import '../services/card_service.dart';

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
  static const Map<String, String> _scryfallHeaders = {
    'User-Agent':
        'Command/1.0 (https://github.com/yourname/commander_daily_cards)',
    'Accept': 'application/json',
  };

  late PageController _pageController;
  late int _currentIndex;
  final Map<int, int> _currentVersionByCardIndex = {};
  final Map<int, PageController> _versionControllers = {};
  final Map<String, List<MTGCard>> _versionsCacheByName = {};
  final Map<String, List<MTGCard>> _remoteVersionsByName = {};
  final Set<String> _loadingRemoteVersionsForName = {};
  final Map<String, int> _activeFaceByCardId = {};
  int _versionsCacheSourceSize = -1;

  bool _hasDisplayImage(MTGCard card) {
    final topLevel = card.imageUris?.normal != null ||
        card.imageUris?.large != null ||
        card.imageUris?.small != null;
    if (topLevel) return true;

    final firstFace = (card.cardFaces != null && card.cardFaces!.isNotEmpty)
        ? card.cardFaces!.first
        : null;
    return firstFace?.imageUris?.normal != null ||
        firstFace?.imageUris?.large != null ||
        firstFace?.imageUris?.small != null;
  }

  int _maxFaceIndex(MTGCard card) {
    final facesWithImages = (card.cardFaces ?? [])
        .where((face) =>
            face.imageUris?.normal != null ||
            face.imageUris?.large != null ||
            face.imageUris?.small != null)
        .length;
    if (facesWithImages <= 1) return 0;
    return facesWithImages - 1;
  }

  int _activeFaceIndex(MTGCard card) {
    final maxIndex = _maxFaceIndex(card);
    return (_activeFaceByCardId[card.id] ?? 0).clamp(0, maxIndex);
  }

  String? _imageUrlForFace(MTGCard card, int faceIndex) {
    final faces = (card.cardFaces ?? [])
        .where((face) =>
            face.imageUris?.normal != null ||
            face.imageUris?.large != null ||
            face.imageUris?.small != null)
        .toList();

    if (faces.isNotEmpty) {
      final index = faceIndex.clamp(0, faces.length - 1);
      final selected = faces[index];
      return selected.imageUris?.normal ??
          selected.imageUris?.large ??
          selected.imageUris?.small;
    }

    return card.imageUris?.normal ??
        card.imageUris?.large ??
        card.imageUris?.small;
  }

  void _toggleFace(MTGCard card) {
    final maxIndex = _maxFaceIndex(card);
    if (maxIndex == 0) return;

    final current = _activeFaceIndex(card);
    final next = (current + 1) % (maxIndex + 1);
    setState(() {
      _activeFaceByCardId[card.id] = next;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _versionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<MTGCard> _versionsForCard(MTGCard card, List<MTGCard> sourceCards) {
    if (_versionsCacheSourceSize != sourceCards.length) {
      _versionsCacheByName.clear();
      _versionsCacheSourceSize = sourceCards.length;
    }

    final cacheKey = card.name.trim().toLowerCase();
    final cached = _versionsCacheByName[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final seenIds = <String>{};
    final targetName = card.name.trim().toLowerCase();
    final versions = sourceCards
        .where((c) => c.name.trim().toLowerCase() == targetName)
        .where(_hasDisplayImage)
        .where((c) => seenIds.add(c.id))
        .toList();

    if (versions.isEmpty) {
      versions.add(card);
    }

    final remoteVersions = _remoteVersionsByName[targetName];
    if (remoteVersions != null && remoteVersions.isNotEmpty) {
      final seen = <String>{...versions.map((c) => c.id)};
      for (final remote in remoteVersions) {
        if (seen.add(remote.id)) {
          versions.add(remote);
        }
      }
    }

    _ensureRemoteVersionsLoaded(card.name);

    final currentIndex = versions.indexWhere((c) => c.id == card.id);
    if (currentIndex > 0) {
      final current = versions.removeAt(currentIndex);
      versions.insert(0, current);
    }

    _versionsCacheByName[cacheKey] = versions;
    return versions;
  }

  Future<void> _ensureRemoteVersionsLoaded(String cardName) async {
    final key = cardName.trim().toLowerCase();
    if (key.isEmpty) return;
    if (_remoteVersionsByName.containsKey(key)) return;
    if (_loadingRemoteVersionsForName.contains(key)) return;

    _loadingRemoteVersionsForName.add(key);

    try {
      var nextUrl = Uri.parse(
        'https://api.scryfall.com/cards/search?q=!"${Uri.encodeQueryComponent(cardName.trim())}"&unique=prints',
      );

      final fetched = <MTGCard>[];
      final seen = <String>{};

      while (true) {
        final response = await http.get(nextUrl, headers: _scryfallHeaders);
        if (response.statusCode != 200) {
          break;
        }

        final payload = json.decode(response.body) as Map<String, dynamic>;
        final items =
            (payload['data'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];

        for (final item in items) {
          final card = MTGCard.fromJson(item);
          if (!_hasDisplayImage(card)) continue;
          if (!seen.add(card.id)) continue;
          fetched.add(card);
        }

        final hasMore = payload['has_more'] == true;
        final nextPage = payload['next_page'] as String?;
        if (!hasMore || nextPage == null || nextPage.isEmpty) break;
        nextUrl = Uri.parse(nextPage);
      }

      if (!mounted) return;
      _remoteVersionsByName[key] = fetched;
      setState(() {
        // Drop cached local versions so remote printings are merged on rebuild.
        _versionsCacheByName.remove(key);
      });
    } catch (_) {
      // Keep view usable with local versions if remote fetch fails.
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingRemoteVersionsForName.remove(key);
      });
    }
  }

  PageController _versionControllerFor(int cardIndex, int initialPage) {
    final existing = _versionControllers[cardIndex];
    if (existing != null) return existing;

    final created = PageController(initialPage: initialPage);
    _versionControllers[cardIndex] = created;
    return created;
  }

  MTGCard _activeCardForOptions(CardService cardService) {
    final baseCard = widget.cards[_currentIndex];
    final sourceCards =
        cardService.allCards.isNotEmpty ? cardService.allCards : widget.cards;
    final versions = _versionsForCard(baseCard, sourceCards);
    final versionIndex = (_currentVersionByCardIndex[_currentIndex] ?? 0)
        .clamp(0, versions.length - 1);
    return versions[versionIndex];
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
    return Consumer<CardService>(
      builder: (context, cardService, _) {
        final sourceCards = cardService.allCards.isNotEmpty
            ? cardService.allCards
            : widget.cards;

        return Scaffold(
          backgroundColor: AppColors.black.withAlpha((0.8 * 255).round()),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            onLongPress: () => _showOptions(_activeCardForOptions(cardService)),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.cards.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              scrollDirection: Axis.vertical,
              itemBuilder: (context, index) {
                final baseCard = widget.cards[index];
                final normalizedName = baseCard.name.trim().toLowerCase();
                final isLoadingVersions =
                    _loadingRemoteVersionsForName.contains(normalizedName);
                final versions = _versionsForCard(baseCard, sourceCards);
                final initialVersion = (_currentVersionByCardIndex[index] ?? 0)
                    .clamp(0, versions.length - 1);
                final versionController =
                    _versionControllerFor(index, initialVersion);
                final currentVersion =
                    (_currentVersionByCardIndex[index] ?? initialVersion)
                        .clamp(0, versions.length - 1);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth - 32;
                    final maxH = constraints.maxHeight - 48;
                    const ratio = 5 / 7;

                    double cardW = maxW;
                    double cardH = cardW / ratio;
                    if (cardH > maxH) {
                      cardH = maxH;
                      cardW = cardH * ratio;
                    }

                    return Center(
                      child: SizedBox(
                        width: cardW,
                        height: cardH,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: versionController,
                              itemCount: versions.length,
                              scrollDirection: Axis.horizontal,
                              onPageChanged: (versionIndex) {
                                setState(() {
                                  _currentVersionByCardIndex[index] =
                                      versionIndex;
                                });
                              },
                              itemBuilder: (context, versionIndex) {
                                final card = versions[versionIndex];
                                final faceIndex = _activeFaceIndex(card);
                                final imageUrl =
                                    _imageUrlForFace(card, faceIndex);
                                final canToggleFace = _maxFaceIndex(card) > 0;
                                final faceLabel = faceIndex == 0
                                    ? 'Front'
                                    : (faceIndex == 1
                                        ? 'Back'
                                        : 'Face ${faceIndex + 1}');

                                return Stack(
                                  children: [
                                    Hero(
                                      tag:
                                          '${card.id}-$versionIndex-face-$faceIndex',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: imageUrl != null
                                            ? Image.network(
                                                imageUrl,
                                                width: cardW,
                                                height: cardH,
                                                fit: BoxFit.contain,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                    if (canToggleFace)
                                      Positioned(
                                        top: cardH * 0.33,
                                        right: 8,
                                        child: FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            backgroundColor: Colors.purple
                                                .withAlpha(
                                                    (0.45 * 255).round()),
                                            foregroundColor: Colors.white,
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () => _toggleFace(card),
                                          child: Text('↻ $faceLabel'),
                                        ),
                                      ),
                                    if (card.gameChanger)
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: AppColors.gameChangerOrange,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              bottomRight: Radius.circular(16),
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
                                );
                              },
                            ),
                            if (versions.length > 1)
                              Positioned(
                                left: 6,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton(
                                    onPressed: currentVersion > 0
                                        ? () {
                                            versionController.previousPage(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                    ),
                                  ),
                                ),
                              ),
                            if (versions.length > 1)
                              Positioned(
                                right: 6,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton(
                                    onPressed:
                                        currentVersion < versions.length - 1
                                            ? () {
                                                versionController.nextPage(
                                                  duration: const Duration(
                                                      milliseconds: 180),
                                                  curve: Curves.easeOut,
                                                );
                                              }
                                            : null,
                                    icon: const Icon(Icons.chevron_right),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                    ),
                                  ),
                                ),
                              ),
                            if (versions.length > 1 || isLoadingVersions)
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${currentVersion + 1}/${versions.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (isLoadingVersions) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
