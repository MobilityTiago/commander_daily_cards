import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/cards/mtg_card.dart';
import '../../services/symbol_service.dart';
import '../../services/card_service.dart';
import '../../services/set_service.dart';
import '../../models/filters/filter_settings.dart';
import '../../styles/colors.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/card_badges_overlay.dart';
import '../../widgets/card_suggestion_section.dart';
import '../../widgets/card_zoom_view.dart';
import 'filter_screen.dart';
import '../../widgets/app_bar.dart';


class HomeScreen extends StatefulWidget { 
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _suggestionPageController;
  int _suggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _suggestionPageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardService = context.read<CardService>();
      final setService = context.read<SetService>();
      final nonLandFilters = context.read<SpellFilterSettings>();
      final landFilters = context.read<LandFilterSettings>();
      cardService.loadInitialData(nonLandFilters, landFilters);
      setService.loadSets();
    });
  }

  @override
  void dispose() {
    _suggestionPageController.dispose();
    super.dispose();
  }

  Future<void> _openCommanderSearch(CardService cardService) async {
    // Capture providers before the async gap to avoid BuildContext warnings.
    final spellFilters = context.read<SpellFilterSettings>();
    final landFilters = context.read<LandFilterSettings>();

    final List<MTGCard>? result = await showGeneralDialog<List<MTGCard>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withAlpha((0.92 * 255).round()),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (ctx, _, __) =>
          _CommanderSearchDialog(
            cardService: cardService,
            initialSelection: cardService.selectedCommanders,
          ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final identity = <String>{};
      for (final card in result) {
        identity.addAll(card.colorIdentity ?? const <String>[]);
      }
      final identityList = identity.toList()..sort();
      spellFilters.lockToCommanderIdentity(identityList);
      landFilters.lockToCommanderIdentity(identityList);
      await cardService.setSelectedCommanders(result);
      await cardService.refreshDailyCards(spellFilters, landFilters);
      AppHaptics.confirm();
    }
  }

  Future<void> _removeCommander(CardService cardService) async {
    final spellFilters = context.read<SpellFilterSettings>();
    final landFilters = context.read<LandFilterSettings>();

    spellFilters.unlockCommanderIdentity();
    landFilters.unlockCommanderIdentity();
    await cardService.setSelectedCommanders(const []);
    await cardService.refreshDailyCards(spellFilters, landFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CardService>(
        builder: (context, cardService, child) {
          if (cardService.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading daily cards...'),
                ],
              ),
            );
          }

          final dateText = DateFormat.yMMMMd().format(DateTime.now());
          final suggestions = cardService.dailySuggestionCards;
          final selectedAppBarCard = cardService.dailyAppBarCard;
          final selectedIndex = selectedAppBarCard != null
              ? suggestions.indexWhere((c) => c.id == selectedAppBarCard.id)
              : -1;
          final effectiveIndex = selectedIndex >= 0 ? selectedIndex : 0;

          // Keep the page view in sync with the current app bar card selection.
          if (_suggestionIndex != effectiveIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _suggestionIndex = effectiveIndex);
              if (_suggestionPageController.hasClients &&
                  effectiveIndex < (suggestions.isEmpty ? 1 : suggestions.length)) {
                _suggestionPageController.jumpToPage(effectiveIndex);
              }
            });
          }

          final backgroundCard = selectedAppBarCard ??
              (suggestions.isNotEmpty
                  ? suggestions[effectiveIndex.clamp(0, suggestions.length - 1)]
                  : (cardService.dailyRegularCard ??
                      cardService.dailyGameChangerCard ??
                      cardService.dailyRegularLand ??
                      cardService.dailyGameChangerLand));

          return RefreshIndicator(
            onRefresh: () async {
              final nonLandFilters = context.read<SpellFilterSettings>();
              final landFilters = context.read<LandFilterSettings>();
              await cardService.refreshDailyCards(nonLandFilters, landFilters);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: 280,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text('Command'),
                  actions: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FilterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.filter_alt),
                    ),
                  ],
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxExtent = 280.0;
                      final statusBar = MediaQuery.of(context).padding.top;
                      final minExtent = kToolbarHeight + statusBar;
                      final t = ((constraints.maxHeight - minExtent) /
                              (maxExtent - minExtent))
                          .clamp(0.0, 1.0);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _suggestionPageController,
                            itemCount: suggestions.isEmpty ? 1 : suggestions.length,
                            onPageChanged: (index) {
                              final suggestionCard = suggestions.isNotEmpty
                                  ? suggestions[index]
                                  : null;

                              if (suggestionCard != null) {
                                cardService.setDailyAppBarCard(suggestionCard);
                              }

                              setState(() {
                                _suggestionIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final suggestionCard = suggestions.isNotEmpty
                                  ? suggestions[index]
                                  : backgroundCard;

                              return AppBarBackground(
                                imageUrl: suggestionCard?.imageUris?.artCrop,
                              );
                            },
                          ),
                          Opacity(
                            opacity: t,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    'Suggestions for $dateText',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    backgroundCard?.name ?? 'Unknown Card',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Illustrated by ${backgroundCard?.artist ?? 'Unknown Artist'}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Commander section
                        _CommanderSelector(
                          commanders: cardService.selectedCommanders,
                          onTap: () => _openCommanderSearch(cardService),
                          onRemove: cardService.selectedCommanders.isNotEmpty
                              ? () => _removeCommander(cardService)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Non-Land Cards Section Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                          child: Text(
                            'Spells',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Regular Card Section
                        CardSuggestionSection(
                          card: cardService.dailyRegularCard,
                          accentColor: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        // Game Changer Card Section
                        CardSuggestionSection(
                          card: cardService.dailyGameChangerCard,
                          accentColor: Colors.orange,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                          child: Text(
                            'Lands',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Regular Land Section
                        CardSuggestionSection(
                          card: cardService.dailyRegularLand,
                          accentColor: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        // Game Changer Land Section
                        CardSuggestionSection(
                          card: cardService.dailyGameChangerLand,
                          accentColor: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Commander Selector ───────────────────────────────────────────────────────

class _CommanderSelector extends StatelessWidget {
  final List<MTGCard> commanders;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  const _CommanderSelector({
    required this.commanders,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (commanders.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkRed,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.search, color: Colors.white),
          label: const Text(
            'Select your commander',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final orderedCommanders = _orderCommandersForDisplay(commanders);
    final primary = orderedCommanders.first;
    final secondary = orderedCommanders.length > 1 ? orderedCommanders[1] : null;
    final combinedIdentity = _combinedCommanderIdentity(commanders);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: primary.imageUris?.artCrop != null
                ? Image.network(
                    primary.imageUris!.artCrop!,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.black12),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha((0.40 * 255).round()),
                    Colors.black.withAlpha((0.78 * 255).round()),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  secondary == null ? 'Commander' : 'Commanders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _CommanderIdentitySymbols(
                  colorIdentity: combinedIdentity,
                ),
                const SizedBox(height: 12),
                _SelectedCommanderTile(card: primary),
                if (secondary != null) ...[
                  const SizedBox(height: 12),
                  _SelectedCommanderTile(
                    card: secondary,
                    label: secondary.isBackgroundCommanderCard
                        ? 'Background'
                        : 'Partner',
                  ),
                ],
                const SizedBox(height: 16),
                if (secondary != null)
                  Text(
                    '${primary.name} + ${secondary.name}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (secondary != null) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.black.withAlpha((0.35 * 255).round()),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(
                          secondary == null
                              ? 'Change Commander'
                              : 'Change Commanders',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove commander',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCommanderTile extends StatelessWidget {
  final MTGCard card;
  final String? label;

  const _SelectedCommanderTile({required this.card, this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => CardZoomView(
              cards: [card],
              initialIndex: 0,
            ),
            transitionsBuilder: (context, animation, _, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            if (card.imageUris?.artCrop != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  card.imageUris!.artCrop!,
                  width: 72,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 72,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.person, color: Colors.white70),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _CommanderResultMana(card: card),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_full, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SearchSelectedCommanderTile extends StatelessWidget {
  final MTGCard card;
  final VoidCallback onRemove;

  const _SearchSelectedCommanderTile({
    required this.card,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          if (card.imageUris?.artCrop != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                card.imageUris!.artCrop!,
                width: 56,
                height: 40,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              card.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

// ── Commander Search Dialog ──────────────────────────────────────────────────

class _CommanderSearchDialog extends StatefulWidget {
  final CardService cardService;
  final List<MTGCard> initialSelection;
  const _CommanderSearchDialog({
    required this.cardService,
    required this.initialSelection,
  });

  @override
  State<_CommanderSearchDialog> createState() =>
      _CommanderSearchDialogState();
}

class _CommanderSearchDialogState extends State<_CommanderSearchDialog> {
  final _controller = TextEditingController();
  List<MTGCard> _results = [];
  late List<MTGCard> _selectedCards;
  final Set<String> _flippedCardIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedCards = List<MTGCard>.from(widget.initialSelection.take(2));
    _controller.addListener(_onQueryChanged);
    _rebuildResults();
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(_rebuildResults);
  }

  bool _isFlipped(MTGCard card) => _flippedCardIds.contains(card.id);

  void _toggleFlipped(MTGCard card) {
    if (!card.hasDoubleFacedImages) return;
    setState(() {
      if (!_flippedCardIds.add(card.id)) {
        _flippedCardIds.remove(card.id);
      }
    });
  }

  String? _displayArtImage(MTGCard card) {
    if (!card.hasDoubleFacedImages) {
      return card.mainFaceArtCropUrl ?? card.mainFaceImageUrl;
    }

    if (_isFlipped(card)) {
      return card.backFaceArtCropUrl ??
          card.backFaceImageUrl ??
          card.mainFaceArtCropUrl ??
          card.mainFaceImageUrl;
    }

    return card.mainFaceArtCropUrl ??
        card.mainFaceImageUrl ??
        card.backFaceArtCropUrl ??
        card.backFaceImageUrl;
  }

  void _rebuildResults() {
    final query = _controller.text.toLowerCase().trim();

    Iterable<MTGCard> candidates;
    if (_selectedCards.length == 1) {
      final first = _selectedCards.first;
      candidates = widget.cardService.allCards.where((card) {
        if (!card.canBeCommander) return false;
        return first.isValidAdditionalCommanderCandidate(card);
      });
    } else {
      candidates = widget.cardService.allCards.where(
        (card) => card.canBePrimaryCommander,
      );
    }

    if (query.isNotEmpty) {
      candidates = candidates.where(
        (card) => card.name.toLowerCase().contains(query),
      );
    }

    final nextResults = candidates.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _results = nextResults;
  }

  void _closeWithSelection() {
    Navigator.of(context).pop(
      _selectedCards.isEmpty ? null : List<MTGCard>.from(_selectedCards),
    );
  }

  void _removeSelectedCard(MTGCard card) {
    setState(() {
      _selectedCards.removeWhere((item) => item.id == card.id);
      _rebuildResults();
    });
  }

  void _handleCommanderTap(MTGCard card) {
    if (_selectedCards.isEmpty) {
      if (!card.canBePrimaryCommander) {
        return;
      }
      setState(() {
        _selectedCards = [card];
        _controller.clear();
        _rebuildResults();
      });
      if (!card.supportsAdditionalCommanderChoice) {
        _closeWithSelection();
      }
      return;
    }

    final first = _selectedCards.first;
    if (first.id == card.id) {
      _closeWithSelection();
      return;
    }

    if (_selectedCards.length == 1 && first.canPairWithAsCommander(card)) {
      setState(() {
        _selectedCards = [first, card];
        _rebuildResults();
      });
      _closeWithSelection();
      return;
    }

    setState(() {
      _selectedCards = [card];
      _controller.clear();
      _rebuildResults();
    });
    if (!card.supportsAdditionalCommanderChoice) {
      _closeWithSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeWithSelection,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.black.withAlpha((0.95 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                IconButton(
                                  onPressed: _closeWithSelection,
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                            if (_selectedCards.isNotEmpty) ...[
                              ...(() {
                                final displayedSelectedCards =
                                    _orderCommandersForDisplay(_selectedCards);
                                return [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _selectedCards.length == 1 &&
                                          _selectedCards.first
                                              .supportsAdditionalCommanderChoice
                                      ? 'Selected commander. Choose a legal partner/background or close to keep only this card.'
                                      : 'Selected commander',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: displayedSelectedCards
                                    .map(
                                      (card) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _SearchSelectedCommanderTile(
                                          card: card,
                                          onRemove: () => _removeSelectedCard(card),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                                ];
                              })(),
                            ],
                            TextField(
                              controller: _controller,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search commanders...',
                                hintStyle: const TextStyle(color: AppColors.white),
                                prefixIcon: const Icon(Icons.search),
                                prefixIconColor: AppColors.white,
                                suffixIcon: ListenableBuilder(
                                  listenable: _controller,
                                  builder: (_, __) => _controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              color: AppColors.white),
                                          onPressed: () => _controller.clear(),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                filled: true,
                                fillColor: AppColors.darkGrey,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: _results.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 32),
                                        child: Text(
                                          _selectedCards.length == 1
                                              ? 'No legal pairings found for ${_selectedCards.first.name}${_controller.text.isEmpty ? '' : ' matching "${_controller.text}"'}'
                                              : 'Type to search commanders',
                                          style: const TextStyle(color: Colors.white54),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _results.length,
                                          itemBuilder: (context, i) {
                                            final card = _results[i];
                                            final artImage =
                                                _displayArtImage(card);
                                            return ListTile(
                                              contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                              leading: SizedBox(
                                                width: 56,
                                                height: 40,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      artImage != null
                                                          ? Image.network(
                                                              artImage,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : const DecoratedBox(
                                                              decoration: BoxDecoration(
                                                                color: Colors.white12,
                                                              ),
                                                            ),
                                                      CardBadgesOverlay(
                                                        hasDoubleFacedImages:
                                                            card.hasDoubleFacedImages,
                                                        isBanned: card.legalities[
                                                                'commander'] ==
                                                            'banned',
                                                        isGameChanger:
                                                            card.gameChanger,
                                                        density:
                                                            CardBadgeDensity.compact,
                                                        onDoubleFacedTap: () =>
                                                            _toggleFlipped(card),
                                                        isDoubleFacedFlipped:
                                                            _isFlipped(card),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                card.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14),
                                              ),
                                              subtitle: Text(
                                                card.typeLine ?? '',
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11),
                                              ),
                                              trailing: _CommanderResultMana(card: card),
                                              onTap: () => _handleCommanderTap(card),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color Identity Dots ───────────────────────────────────────────────────────

class _ColorIdentityDots extends StatelessWidget {
  final List<String> colorIdentity;
  const _ColorIdentityDots(this.colorIdentity);

  static Color _colorForSymbol(String symbol) {
    switch (symbol) {
      case 'W':
        return const Color(0xFFF9FAF4);
      case 'U':
        return const Color(0xFF0E68AB);
      case 'B':
        return const Color(0xFF21130D);
      case 'R':
        return const Color(0xFFD3202A);
      case 'G':
        return const Color(0xFF00733E);
      default:
        return const Color(0xFF9FA4A9); // colorless
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _sortColorSymbolsWubrg(
      colorIdentity.isEmpty ? ['C'] : colorIdentity,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: symbols
          .map(
            (s) => Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: _colorForSymbol(s),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CommanderResultMana extends StatelessWidget {
  final MTGCard card;

  const _CommanderResultMana({required this.card});

  @override
  Widget build(BuildContext context) {
    final manaCost = card.manaCost ??
        ((card.cardFaces != null && card.cardFaces!.isNotEmpty)
            ? card.cardFaces!.first.manaCost
            : null);

    if (manaCost == null || manaCost.isEmpty) {
      return _ColorIdentityDots(card.colorIdentity ?? []);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 108),
      child: _ManaCostSymbols(manaCost: manaCost),
    );
  }
}

class _ManaCostSymbols extends StatelessWidget {
  final String manaCost;

  const _ManaCostSymbols({required this.manaCost});

  @override
  Widget build(BuildContext context) {
    final tokens = _parseManaTokens(manaCost);

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final token in tokens) _ManaTokenIcon(token: token),
      ],
    );
  }

}

class _ManaTokenIcon extends StatelessWidget {
  final String token;
  final double size;

  const _ManaTokenIcon({required this.token, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final symbolService = context.watch<SymbolService>();
    final symbol = symbolService.symbolByToken(token);
    final svgData = symbolService.svgDataByToken(token);

    if (symbol != null && (svgData == null || svgData.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        symbolService.requestRefreshOnMiss(token);
      });
    }

    if (svgData != null && svgData.isNotEmpty) {
      return SvgPicture.string(
        svgData,
        width: size,
        height: size,
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        border: Border.all(color: Colors.white30),
        shape: BoxShape.circle,
      ),
      child: Text(
        token.replaceAll('{', '').replaceAll('}', ''),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CommanderIdentitySymbols extends StatelessWidget {
  final List<String> colorIdentity;

  const _CommanderIdentitySymbols({required this.colorIdentity});

  @override
  Widget build(BuildContext context) {
    final symbols = _sortColorSymbolsWubrg(
      colorIdentity.isEmpty ? const ['C'] : colorIdentity,
    );

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final symbol in symbols)
          _ManaTokenIcon(
            token: '{$symbol}',
            size: 12,
          ),
      ],
    );
  }
}

List<String> _combinedCommanderIdentity(List<MTGCard> cards) {
  final colors = <String>{};
  for (final card in cards) {
    colors.addAll(card.colorIdentity ?? const <String>[]);
  }
  return _sortColorSymbolsWubrg(colors.toList());
}

List<MTGCard> _orderCommandersForDisplay(List<MTGCard> cards) {
  if (cards.length != 2) return cards;

  final first = cards[0];
  final second = cards[1];
  if (first.isBackgroundCommanderCard && !second.isBackgroundCommanderCard) {
    return [second, first];
  }

  return cards;
}

List<String> _sortColorSymbolsWubrg(List<String> symbols) {
  const order = ['W', 'U', 'B', 'R', 'G', 'C'];
  final unique = <String>{...symbols};
  return order.where(unique.contains).toList();
}

List<String> _parseManaTokens(String value) {
  final tokens = <String>[];
  var current = StringBuffer();
  var inside = false;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == '{') {
      inside = true;
      current = StringBuffer()..write(char);
      continue;
    }
    if (inside) {
      current.write(char);
      if (char == '}') {
        tokens.add(current.toString());
        inside = false;
        current = StringBuffer();
      }
    }
  }

  return tokens;
}