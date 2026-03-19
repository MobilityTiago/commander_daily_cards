import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../styles/colors.dart';
import '../models/cards/mtg_card.dart';
import '../services/card_service.dart';
import '../services/user_preferences_service.dart';

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
  final Map<String, MTGCard> _freshCardsById = {};
  final Map<String, DateTime?> _lastKnownUpdateByCardId = {};
  final Set<String> _priceRefreshInFlightByCardId = {};
  final Set<String> _priceRefreshCheckedByCardId = {};
  final Set<String> _lastKnownUpdateLoadInFlightByCardId = {};
  int _versionsCacheSourceSize = -1;

  static final NumberFormat _usdFormat = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 2,
  );
  static final NumberFormat _eurFormat = NumberFormat.currency(
    symbol: 'EUR ',
    decimalDigits: 2,
  );

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
    } else if (currentIndex == -1) {
      // The specific card isn't in the local oracle catalog (e.g. a specific
      // printing resolved by the card picker). Prepend it so it shows first;
      // the seenIds set below will prevent duplication when remote versions load.
      versions.insert(0, card);
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
    final active = versions[versionIndex];
    return _freshCardsById[active.id] ?? active;
  }

  void _ensureFreshPricing(MTGCard card, CardService cardService) {
    _ensureLastKnownUpdateLoaded(card.id, cardService);

    if (_priceRefreshCheckedByCardId.contains(card.id) ||
        _priceRefreshInFlightByCardId.contains(card.id)) {
      return;
    }

    _priceRefreshInFlightByCardId.add(card.id);
    unawaited(
      cardService.getCardWithFreshPricing(card).then((refreshed) {
        if (!mounted) return;
        unawaited(_refreshLastKnownUpdate(refreshed.id, cardService));
        setState(() {
          _freshCardsById[card.id] = refreshed;
          _priceRefreshCheckedByCardId.add(card.id);
          _priceRefreshInFlightByCardId.remove(card.id);
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _priceRefreshCheckedByCardId.add(card.id);
          _priceRefreshInFlightByCardId.remove(card.id);
        });
      }),
    );
  }

  Future<void> _refreshLastKnownUpdate(
      String cardId, CardService cardService) async {
    final timestamp = await cardService.getLatestKnownUpdateForCard(cardId);
    if (!mounted) return;
    setState(() {
      _lastKnownUpdateByCardId[cardId] = timestamp;
      _lastKnownUpdateLoadInFlightByCardId.remove(cardId);
    });
  }

  void _ensureLastKnownUpdateLoaded(String cardId, CardService cardService) {
    if (_lastKnownUpdateByCardId.containsKey(cardId) ||
        _lastKnownUpdateLoadInFlightByCardId.contains(cardId)) {
      return;
    }

    _lastKnownUpdateLoadInFlightByCardId.add(cardId);
    unawaited(_refreshLastKnownUpdate(cardId, cardService));
  }

  String _formatUsd(double? value) {
    if (value == null || value <= 0) return 'N/A';
    return _usdFormat.format(value);
  }

  String _formatEur(double? value) {
    if (value == null || value <= 0) return 'N/A';
    return _eurFormat.format(value).replaceFirst('EUR ', '€');
  }

  String _formatUpdatedAge(DateTime? timestamp, {required bool isRefreshing}) {
    if (isRefreshing) {
      return 'Updating...';
    }
    if (timestamp == null) {
      return 'Updated: unknown';
    }

    final delta = DateTime.now().difference(timestamp);
    if (delta.inSeconds < 60) return 'Updated just now';
    if (delta.inMinutes < 60) return 'Updated ${delta.inMinutes}m ago';
    if (delta.inHours < 24) return 'Updated ${delta.inHours}h ago';
    return 'Updated ${delta.inDays}d ago';
  }

  Uri? _marketUriForCard(MTGCard card, MarketPreference marketPreference) {
    switch (marketPreference) {
      case MarketPreference.tcgplayer:
        final raw = card.tcgplayerUrl;
        if (raw == null || raw.isEmpty) return null;
        return Uri.tryParse(raw);
      case MarketPreference.cardmarket:
        final raw = card.cardmarketUrl;
        if (raw == null || raw.isEmpty) return null;
        final base = Uri.tryParse(raw);
        if (base == null) return null;
        return base.replace(
          queryParameters: {
            ...base.queryParameters,
            'referrer': 'Tiago',
            'utm_campaign': 'card_prices',
            'utm_medium': 'text',
            'utm_source': 'command',
          },
        );
    }
  }

  Future<void> _openPreferredMarket(
    MTGCard card,
    MarketPreference marketPreference,
  ) async {
    final uri = _marketUriForCard(card, marketPreference);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No market link available for this card')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open market link')),
      );
    }
  }

  Widget _buildPriceRow(
    MTGCard card, {
    required bool isRefreshing,
    required DateTime? lastKnownUpdate,
    required PricePreference pricePreference,
    required MarketPreference marketPreference,
  }) {
    final usdText = _formatUsd(card.usd);
    final eurText = _formatEur(card.eur);
    final updatedText =
        _formatUpdatedAge(lastKnownUpdate, isRefreshing: isRefreshing);
    final marketUri = _marketUriForCard(card, marketPreference);
    final priceText = switch (pricePreference) {
      PricePreference.both => 'USD $usdText / EUR $eurText',
      PricePreference.usd => 'USD $usdText',
      PricePreference.eur => 'EUR $eurText',
      PricePreference.none => '',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: marketUri == null
            ? null
            : () => _openPreferredMarket(card, marketPreference),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((0.6 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (marketUri != null) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    updatedText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isRefreshing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    return Consumer2<CardService, UserPreferencesService>(
      builder: (context, cardService, userPreferences, _) {
        final sourceCards = cardService.allCards.isNotEmpty
            ? cardService.allCards
            : widget.cards;
        final shouldShowPrice =
            userPreferences.pricePreference != PricePreference.none;

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
                    const priceRowHeight = 52.0;
                    const priceGap = 8.0;
                    final reservedPriceHeight =
                        shouldShowPrice ? priceRowHeight + priceGap : 0.0;
                    final imageAreaMaxH =
                        (maxH - reservedPriceHeight).clamp(120.0, maxH);
                    const ratio = 5 / 7;

                    double cardW = maxW;
                    double cardH = cardW / ratio;
                    if (cardH > imageAreaMaxH) {
                      cardH = imageAreaMaxH;
                      cardW = cardH * ratio;
                    }

                    final activeVersionCard =
                        _freshCardsById[versions[currentVersion].id] ??
                            versions[currentVersion];
                    final isRefreshingPrice = _priceRefreshInFlightByCardId
                        .contains(activeVersionCard.id);
                    final lastKnownUpdate =
                        _lastKnownUpdateByCardId[activeVersionCard.id];
                    if (shouldShowPrice) {
                      _ensureFreshPricing(activeVersionCard, cardService);
                    }

                    return Center(
                      child: SizedBox(
                        width: cardW,
                        height: cardH + reservedPriceHeight,
                        child: Column(
                          children: [
                            SizedBox(
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
                                      final version = versions[versionIndex];
                                      final card =
                                          _freshCardsById[version.id] ??
                                              version;
                                      final faceIndex = _activeFaceIndex(card);
                                      final imageUrl =
                                          _imageUrlForFace(card, faceIndex);
                                      final canToggleFace =
                                          _maxFaceIndex(card) > 0;
                                      final faceLabel = faceIndex == 0
                                          ? 'Front'
                                          : (faceIndex == 1
                                              ? 'Back'
                                              : 'Face ${faceIndex + 1}');

                                      if (shouldShowPrice) {
                                        _ensureFreshPricing(card, cardService);
                                      }

                                      return Stack(
                                        children: [
                                          Hero(
                                            tag:
                                                '${card.id}-$versionIndex-face-$faceIndex',
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  backgroundColor: context
                                                      .uiColors.purple
                                                      .withAlpha(
                                                          (0.45 * 255).round()),
                                                  foregroundColor: Colors.white,
                                                  textStyle: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _toggleFace(card),
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
                                                  color: AppColors
                                                      .gameChangerOrange,
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(16),
                                                    bottomRight:
                                                        Radius.circular(16),
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'GC',
                                                    style: TextStyle(
                                                      color: AppColors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  versionController
                                                      .previousPage(
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
                                          onPressed: currentVersion <
                                                  versions.length - 1
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                padding:
                                                    const EdgeInsets.all(5),
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
                            if (shouldShowPrice) ...[
                              const SizedBox(height: priceGap),
                              _buildPriceRow(
                                activeVersionCard,
                                isRefreshing: isRefreshingPrice,
                                lastKnownUpdate: lastKnownUpdate,
                                pricePreference:
                                    userPreferences.pricePreference,
                                marketPreference:
                                    userPreferences.marketPreference,
                              ),
                            ],
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
