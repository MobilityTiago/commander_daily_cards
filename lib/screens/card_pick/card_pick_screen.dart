import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/cards/mtg_card.dart';
import '../../services/card_service.dart';
import '../../services/set_service.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/card_zoom_view.dart';

class CardPickScreen extends StatefulWidget {
  const CardPickScreen({super.key});

  @override
  State<CardPickScreen> createState() => _CardPickScreenState();
}

class _CardPickScreenState extends State<CardPickScreen> {
  static const Map<String, String> _scryfallHeaders = {
    'User-Agent':
        'Command/1.0 (https://github.com/yourname/commander_daily_cards)',
    'Accept': 'application/json',
  };
  static const int _symbolDescriptorSize = 32;
  static const List<_SymbolCropSpec> _symbolCropSpecs = [
    _SymbolCropSpec(centerX: 0.78, centerY: 0.47, sizeFactor: 0.12),
    _SymbolCropSpec(centerX: 0.81, centerY: 0.47, sizeFactor: 0.12),
    _SymbolCropSpec(centerX: 0.78, centerY: 0.50, sizeFactor: 0.13),
    _SymbolCropSpec(centerX: 0.75, centerY: 0.49, sizeFactor: 0.11),
    _SymbolCropSpec(centerX: 0.82, centerY: 0.50, sizeFactor: 0.11),
  ];
  static const List<double> _cardWidthFractions = [0.60, 0.68, 0.76];

  final TextRecognizer _textRecognizer = TextRecognizer();
  CameraController? _cameraController;
  bool _isSettingUp = true;
  bool _isCapturing = false;
  bool _isOpeningZoom = false;
  bool _cameraPermissionPermanentlyDenied = false;
  String _statusText = 'Preparing camera...';
  MTGCard? _lastMatchedCard;
  _DebugScanInfo? _lastDebugInfo;
  bool? _lastOldFrameHeuristic;
  bool _showDebugOverlay = false;
  bool _quickScanEnabled = false;
  bool _isMonitoringCard = false;
  bool _isProcessingDetection = false;
  bool _isStoppingImageStream = false;
  int _detectionHitStreak = 0;
  Uint8List? _prevFrameLuma;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<_CardBounds?> _cardBoundsNotifier = ValueNotifier(null);
  Timer? _cardBoundsFadeTimer;
  List<CameraDescription> _availableCameras = [];
  CameraDescription? _selectedCamera;
  String? _lockedSetCode;
  late final Map<String, List<MTGCard>> _cardsByNormalizedName;
  late final List<_CardNameIndex> _nameIndex;
  final Map<String, Future<List<double>?>> _setSymbolDescriptorCache = {};
  final Map<String, Future<List<MTGCard>>> _printingsByNormalizedName = {};

  @override
  void initState() {
    super.initState();
    _cardsByNormalizedName = <String, List<MTGCard>>{};
    _nameIndex = <_CardNameIndex>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _stopCardPresenceMonitoring();
    _cardBoundsFadeTimer?.cancel();
    _cardBoundsNotifier.dispose();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cardService = context.read<CardService>();
    final setService = context.read<SetService>();

    try {
      setState(() {
        _isSettingUp = true;
        _statusText = 'Checking camera permission...';
      });

      final hasPermission = await _ensureCameraPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _isSettingUp = false;
          _statusText = _cameraPermissionPermanentlyDenied
              ? 'Camera access is blocked. Open settings to enable permission.'
              : 'Camera permission is required to scan cards.';
        });
        return;
      }

      if (cardService.allCards.isEmpty) {
        setState(() => _statusText = 'Loading card catalog...');
        await cardService.ensureCardCatalogLoaded();
      }

      if (setService.sets.isEmpty) {
        setState(() => _statusText = 'Loading set symbols...');
        await setService.loadSets();
      }

      _buildNameIndex(cardService.allCards);
      await _initCamera();
      if (!mounted) return;
      setState(() {
        _isSettingUp = false;
        _statusText = 'Point at a card and tap Scan';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSettingUp = false;
        _statusText = 'Scanner setup failed: $e';
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _cameraPermissionPermanentlyDenied = false;
      return true;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      _cameraPermissionPermanentlyDenied = true;
      return false;
    }

    final requested = await Permission.camera.request();
    if (requested.isGranted) {
      _cameraPermissionPermanentlyDenied = false;
      return true;
    }

    // On iOS, once the user denies camera access, future requests do not
    // show the system prompt again. Send users directly to Settings.
    if (defaultTargetPlatform == TargetPlatform.iOS && requested.isDenied) {
      _cameraPermissionPermanentlyDenied = true;
      return false;
    }

    _cameraPermissionPermanentlyDenied =
        requested.isPermanentlyDenied || requested.isRestricted;
    return false;
  }

  Future<void> _onPermissionActionPressed() async {
    if (_cameraPermissionPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await _bootstrap();
  }

  Future<void> _initCamera([CameraDescription? preferred]) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No camera available on this device');
    }

    final target = preferred ??
        cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );

    final streamFormat =
        Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420;
    final controller = CameraController(
      target,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: streamFormat,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _availableCameras = cameras;
      _selectedCamera = target;
      _cameraController = controller;
    });
  }

  void _buildNameIndex(List<MTGCard> cards) {
    _cardsByNormalizedName.clear();
    _nameIndex.clear();

    for (final card in cards) {
      if (card.name.isEmpty) continue;
      final normalized = _normalize(card.name);
      if (normalized.isEmpty) continue;

      _cardsByNormalizedName
          .putIfAbsent(normalized, () => <MTGCard>[])
          .add(card);
      _nameIndex.add(_CardNameIndex(card: card, normalizedName: normalized));
    }
  }

  Future<void> _scanCard({bool restartMonitoring = true}) async {
    final controller = _cameraController;
    if (_isCapturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    await _stopCardPresenceMonitoringAsync();

    setState(() {
      _isCapturing = true;
      _statusText = 'Scanning card...';
    });

    try {
      final photo = await controller.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final matched = await _matchFromRecognizedText(recognized, photo.path);

      if (!mounted) return;
      if (matched == null) {
        setState(() {
          _statusText =
              'No card match found. Keep the card centered and try again.';
        });
        return;
      }

      final englishMatch = await _ensureEnglishVersion(matched);
      final finalCard = _lockedSetCode != null
          ? await _applySetLock(englishMatch, _lockedSetCode!)
          : englishMatch;

      if (finalCard == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Card not found in locked set. Try another card or unlock the set.',
            ),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _lastMatchedCard = finalCard;
      setState(() {
        final setCode = finalCard.setCode;
        _statusText = setCode == null || setCode.isEmpty
            ? 'Matched ${finalCard.name}'
            : 'Matched ${finalCard.name} (${setCode.toUpperCase()})';
      });
      AppHaptics.confirm();
      await _openCardZoom(finalCard);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Scan failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        if (restartMonitoring && _quickScanEnabled) {
          unawaited(_resumeQuickScanMonitoringSoon());
        }
      }
    }
  }

  Future<MTGCard?> _matchFromRecognizedText(
    RecognizedText recognized,
    String photoPath,
  ) async {
    final allCandidates = <String>[];
    final titleCandidates = <String>[];
    final rawTitleCandidates = <String>[];

    double? minY;
    double? maxY;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        minY = math.min(minY ?? line.boundingBox.top, line.boundingBox.top);
        maxY =
            math.max(maxY ?? line.boundingBox.bottom, line.boundingBox.bottom);
      }
    }

    final titleThresholdY =
        (minY != null && maxY != null) ? minY + (maxY - minY) * 0.34 : null;

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = _normalize(line.text);
        if (text.length < 4) continue;
        allCandidates.add(text);

        final centerY = (line.boundingBox.top + line.boundingBox.bottom) / 2;
        final likelyTitleLine = titleThresholdY != null &&
            centerY <= titleThresholdY &&
            text.length <= 34;
        if (likelyTitleLine) {
          titleCandidates.add(text);
          final raw = line.text.trim();
          if (raw.isNotEmpty) rawTitleCandidates.add(raw);
        }
      }
    }

    final candidates = allCandidates.toSet().toList(growable: false);
    final title = titleCandidates.toSet().toList(growable: false);

    if (candidates.isEmpty) {
      _lastOldFrameHeuristic = null;
      return null;
    }

    final globalHints = await _extractPrintingHints(
      recognized,
      photoPath,
      const <MTGCard>[],
    );
    final likelyOldFrame = await _isLikelyOldFrameTitle(
      recognized,
      photoPath,
      globalHints,
    );
    _lastOldFrameHeuristic = likelyOldFrame;

    // Try exact normalized-name matches first, prioritizing title lines.
    for (final text in [...title, ...candidates]) {
      final exact = _cardsByNormalizedName[text];
      if (exact != null && exact.isNotEmpty) {
        final resolved = await _resolvePrintingMatch(
          await _printingsForMatch(exact),
          recognized,
          photoPath,
        );
        return resolved ?? exact.first;
      }
    }

    // Next try fuzzy matching only from likely title lines.
    final titleMatch = _bestFuzzyNameMatch(title);
    final titleScoreGate = likelyOldFrame ? 62 : 76;
    final titleMarginGate = likelyOldFrame ? 2 : 6;
    if (titleMatch != null &&
        titleMatch.score >= titleScoreGate &&
        titleMatch.margin >= titleMarginGate) {
      final exact = _cardsByNormalizedName[_normalize(titleMatch.card.name)];
      if (exact == null || exact.length <= 1) {
        return titleMatch.card;
      }
      final resolved = await _resolvePrintingMatch(
        await _printingsForMatch(exact),
        recognized,
        photoPath,
      );
      return resolved ?? titleMatch.card;
    }

    // If name matching is weak, assume foreign/printed name and fallback to
    // image-assisted resolution.
    if (titleMatch == null || titleMatch.score < 76) {
      return _resolveFromImageFallbackForUnknownName(
        recognized,
        photoPath,
        candidates,
        rawTitleCandidates,
      );
    }

    if (likelyOldFrame) {
      final oldFrameResolved = await _resolveOldFrameNameFallback(
        recognized,
        photoPath,
        rawTitleCandidates.isEmpty ? candidates : rawTitleCandidates,
        globalHints.languages,
      );
      if (oldFrameResolved != null) {
        return oldFrameResolved;
      }
    }

    final globalMatch = _bestFuzzyNameMatch(candidates);
    final globalScoreGate = likelyOldFrame ? 78 : 86;
    final globalMarginGate = likelyOldFrame ? 5 : 8;
    if (globalMatch == null ||
        globalMatch.score < globalScoreGate ||
        globalMatch.margin < globalMarginGate) {
      return _resolveFromImageFallbackForUnknownName(
        recognized,
        photoPath,
        candidates,
        rawTitleCandidates,
      );
    }

    final exact = _cardsByNormalizedName[_normalize(globalMatch.card.name)];
    if (exact == null || exact.length <= 1) {
      return globalMatch.card;
    }

    final resolved = await _resolvePrintingMatch(
      await _printingsForMatch(exact),
      recognized,
      photoPath,
    );
    return resolved ?? globalMatch.card;
  }

  _NameMatchScore? _bestFuzzyNameMatch(List<String> candidates) {
    if (candidates.isEmpty) return null;

    MTGCard? bestCard;
    var bestScore = -1;
    var secondBest = -1;
    for (final text in candidates) {
      for (final entry in _nameIndex) {
        final score = _nameSimilarityScore(text, entry.normalizedName);
        if (score > bestScore) {
          secondBest = bestScore;
          bestScore = score;
          bestCard = entry.card;
        } else if (score > secondBest) {
          secondBest = score;
        }
      }
    }

    if (bestCard == null) return null;
    return _NameMatchScore(
      card: bestCard,
      score: bestScore,
      margin: bestScore - secondBest,
    );
  }

  Future<MTGCard?> _resolveFromImageFallbackForUnknownName(
    RecognizedText recognized,
    String photoPath,
    List<String> normalizedCandidates,
    List<String> rawTitleCandidates,
  ) async {
    final searchTerms = <String>{
      ...rawTitleCandidates,
      ...normalizedCandidates,
    }
        .map((value) => value.trim())
        .where((value) => value.length >= 3)
        .toList(growable: false);
    if (searchTerms.isEmpty) return null;

    final fetched = <MTGCard>[];
    final seen = <String>{};
    for (final term in searchTerms.take(3)) {
      final results = await _fetchByPrintedNameFallbackFromScryfall(
        [term],
        const <String>{},
      );
      for (final card in results) {
        if (seen.add(card.id)) {
          fetched.add(card);
        }
      }
    }
    if (fetched.isEmpty) return null;

    final inferredSetCode = await _inferSetCodeFromSymbol(fetched, photoPath);
    var pool = fetched;
    if (inferredSetCode != null) {
      final narrowed = fetched
          .where((card) => card.setCode?.toLowerCase() == inferredSetCode)
          .toList(growable: false);
      if (narrowed.isNotEmpty) {
        pool = narrowed;
      }
    }

    MTGCard? best;
    var bestScore = -1;
    for (final card in pool) {
      final normalizedName = _normalize(card.name);
      for (final candidate in normalizedCandidates) {
        final score = _nameSimilarityScore(candidate, normalizedName);
        if (score > bestScore) {
          bestScore = score;
          best = card;
        }
      }
    }

    if (best != null && bestScore >= 38) {
      return best;
    }

    return _chooseLatestVersion(pool);
  }

  Future<MTGCard> _ensureEnglishVersion(MTGCard card) async {
    final lang = card.lang?.toLowerCase();
    if (lang == null || lang == 'en') return card;

    final printings = await _fetchPrintingsForName(card.name);
    if (printings.isEmpty) return card;

    final english = printings
        .where((value) => (value.lang?.toLowerCase() ?? '') == 'en')
        .toList(growable: false);
    if (english.isEmpty) return card;

    final normalizedCollector = _normalizeCollectorNumber(card.collectorNumber);
    final setCode = card.setCode?.toLowerCase();

    for (final candidate in english) {
      final sameSet =
          (candidate.setCode?.toLowerCase() ?? '') == (setCode ?? '');
      final sameCollector =
          _normalizeCollectorNumber(candidate.collectorNumber) ==
              normalizedCollector;
      if (sameSet && sameCollector) {
        return candidate;
      }
    }

    for (final candidate in english) {
      if ((candidate.setCode?.toLowerCase() ?? '') == (setCode ?? '')) {
        return candidate;
      }
    }

    return _chooseLatestVersion(english) ?? card;
  }

  Future<bool> _isLikelyOldFrameTitle(
    RecognizedText recognized,
    String photoPath,
    _PrintingHints hints,
  ) async {
    if (hints.rawSetCodes.isNotEmpty || hints.rawCollectorNumbers.isNotEmpty) {
      return false;
    }

    final image = await _loadPhotoImage(photoPath);
    if (image == null) return false;

    final lines = <TextLine>[];
    double? minY;
    double? maxY;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        lines.add(line);
        minY = math.min(minY ?? line.boundingBox.top, line.boundingBox.top);
        maxY =
            math.max(maxY ?? line.boundingBox.bottom, line.boundingBox.bottom);
      }
    }
    if (lines.isEmpty || minY == null || maxY == null) return false;

    final topBandLimit = minY + (maxY - minY) * 0.34;
    final topLines = lines.where((line) {
      final centerY = (line.boundingBox.top + line.boundingBox.bottom) / 2;
      return centerY <= topBandLimit && _normalize(line.text).length >= 4;
    }).toList(growable: false);
    if (topLines.isEmpty) return false;

    final primaryLine = topLines.reduce((left, right) {
      final leftArea = left.boundingBox.width * left.boundingBox.height;
      final rightArea = right.boundingBox.width * right.boundingBox.height;
      return leftArea >= rightArea ? left : right;
    });

    final box = primaryLine.boundingBox;
    final cropLeft = box.left.round().clamp(0, image.width - 1);
    final cropTop = box.top.round().clamp(0, image.height - 1);
    final cropRight = box.right.round().clamp(cropLeft + 1, image.width);
    final cropBottom = box.bottom.round().clamp(cropTop + 1, image.height);
    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;
    if (cropWidth < 12 || cropHeight < 6) return false;

    final crop = img.copyCrop(
      image,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );

    var brightLowSatCount = 0;
    var darkCount = 0;
    final total = crop.width * crop.height;
    for (var y = 0; y < crop.height; y++) {
      for (var x = 0; x < crop.width; x++) {
        final p = crop.getPixel(x, y);
        final r = p.r / 255.0;
        final g = p.g / 255.0;
        final b = p.b / 255.0;
        final maxCh = math.max(r, math.max(g, b));
        final minCh = math.min(r, math.min(g, b));
        final sat = maxCh <= 0 ? 0.0 : (maxCh - minCh) / maxCh;
        final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if (lum >= 0.72 && sat <= 0.20) {
          brightLowSatCount += 1;
        }
        if (lum <= 0.36) {
          darkCount += 1;
        }
      }
    }

    final brightRatio = total == 0 ? 0.0 : brightLowSatCount / total;
    final darkRatio = total == 0 ? 0.0 : darkCount / total;
    return brightRatio >= 0.20 && darkRatio >= 0.20;
  }

  Future<MTGCard?> _resolveOldFrameNameFallback(
    RecognizedText recognized,
    String photoPath,
    List<String> nameCandidates,
    Set<String> languages,
  ) async {
    final fetched = await _fetchByPrintedNameFallbackFromScryfall(
      nameCandidates,
      languages,
    );
    if (fetched.isEmpty) return null;

    final narrowed = fetched.where((card) {
      if (languages.isEmpty) return true;
      final lang = card.lang?.toLowerCase();
      return lang != null && languages.contains(lang);
    }).toList(growable: false);

    final pool = narrowed.isEmpty ? fetched : narrowed;
    final latest = _chooseLatestVersion(pool);
    if (latest == null) return null;

    final sameName = pool
        .where((card) => _normalize(card.name) == _normalize(latest.name))
        .toList(growable: false);
    if (sameName.length <= 1) {
      return latest;
    }

    final resolved = await _resolvePrintingMatch(
      sameName,
      recognized,
      photoPath,
    );
    return resolved ?? latest;
  }

  Future<List<MTGCard>> _printingsForMatch(List<MTGCard> matchedCards) async {
    if (matchedCards.isEmpty) return matchedCards;

    final normalizedName = _normalize(matchedCards.first.name);
    return _printingsByNormalizedName.putIfAbsent(normalizedName, () async {
      final fetched = await _fetchPrintingsForName(matchedCards.first.name);
      if (fetched.isEmpty) {
        return matchedCards;
      }

      final seen = <String>{};
      return fetched.where((card) => seen.add(card.id)).toList(growable: false);
    });
  }

  Future<List<MTGCard>> _fetchPrintingsForName(String cardName) async {
    final fetched = <MTGCard>[];
    final seen = <String>{};

    try {
      final encodedName = Uri.encodeQueryComponent(cardName.trim());
      var nextUrl = Uri.parse(
        'https://api.scryfall.com/cards/search?q=!"$encodedName"&unique=prints&include_multilingual=true',
      );

      while (true) {
        final response = await http
            .get(nextUrl, headers: _scryfallHeaders)
            .timeout(const Duration(seconds: 16));
        if (response.statusCode != 200) {
          break;
        }

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final items =
            (payload['data'] as List?)?.whereType<Map<String, dynamic>>() ??
                const [];
        for (final item in items) {
          final card = MTGCard.fromJson(item);
          if (!_normalize(card.name).contains(_normalize(cardName)) &&
              !_normalize(cardName).contains(_normalize(card.name))) {
            continue;
          }
          if (seen.add(card.id)) {
            fetched.add(card);
          }
        }

        final hasMore = payload['has_more'] == true;
        final nextPage = payload['next_page'] as String?;
        if (!hasMore || nextPage == null || nextPage.isEmpty) break;
        nextUrl = Uri.parse(nextPage);
      }
    } catch (_) {
      return const [];
    }

    return fetched;
  }

  Future<MTGCard?> _resolvePrintingMatch(
    List<MTGCard> candidates,
    RecognizedText recognized,
    String photoPath,
  ) async {
    final unique = <String, MTGCard>{};
    for (final candidate in candidates) {
      unique[candidate.id] = candidate;
    }

    final versions = unique.values.toList(growable: false);
    if (versions.length <= 1) {
      if (versions.isNotEmpty) {
        _lastDebugInfo = _DebugScanInfo(
          cardName: versions.first.name,
          resolvedSetCode: versions.first.setCode,
          matchPath: 'single',
        );
      }
      return versions.isEmpty ? null : versions.first;
    }

    final baseHints =
        await _extractPrintingHints(recognized, photoPath, versions);

    // Only attempt set-code-from-logo when OCR didn't provide any set code.
    var hints = baseHints;
    if (hints.setCodes.isEmpty) {
      final inferredSetCode =
          await _inferSetCodeFromSymbol(versions, photoPath);
      if (inferredSetCode != null) {
        hints = hints.copyWith(
          setCodes: <String>{inferredSetCode},
          rawSetCodes: <String>{...hints.rawSetCodes, inferredSetCode},
        );
      }
    }

    if (hints.hasPrimaryHints) {
      final strict = _resolveFromPrimaryHints(
        versions,
        hints,
        requireConfidence: true,
      );
      if (strict != null) {
        _lastDebugInfo = _DebugScanInfo(
          cardName: versions.first.name,
          resolvedSetCode: strict.setCode,
          rawSetCodes: hints.rawSetCodes,
          filteredSetCodes: hints.setCodes,
          rawLanguages: hints.rawLanguages,
          filteredLanguages: hints.languages,
          rawCollectorNumbers: hints.rawCollectorNumbers,
          filteredCollectorNumbers: hints.collectorNumbers,
          foilStarDetected: hints.foilStarDetected,
          matchPath: 'ocr',
        );
        return strict;
      }
    }

    // Requested fallback: drop set code and match with image+name.
    final hintsWithoutSetCode = hints.copyWith(setCodes: const <String>{});
    final imageMatch = await _resolveFromImageAndName(
      versions,
      hintsWithoutSetCode,
      photoPath,
    );
    if (imageMatch != null) {
      _lastDebugInfo = _DebugScanInfo(
        cardName: versions.first.name,
        resolvedSetCode: imageMatch.setCode,
        rawSetCodes: hints.rawSetCodes,
        filteredSetCodes: hints.setCodes,
        rawLanguages: hints.rawLanguages,
        filteredLanguages: hints.languages,
        rawCollectorNumbers: hints.rawCollectorNumbers,
        filteredCollectorNumbers: hints.collectorNumbers,
        foilStarDetected: hints.foilStarDetected,
        matchPath: 'symbol',
      );
      return imageMatch;
    }

    // If image isn't useful, fall back to latest printing by name.
    final latest = _chooseLatestVersion(versions, hintsWithoutSetCode);
    _lastDebugInfo = _DebugScanInfo(
      cardName: versions.first.name,
      resolvedSetCode: latest?.setCode,
      rawSetCodes: hints.rawSetCodes,
      filteredSetCodes: hints.setCodes,
      rawLanguages: hints.rawLanguages,
      filteredLanguages: hints.languages,
      rawCollectorNumbers: hints.rawCollectorNumbers,
      filteredCollectorNumbers: hints.collectorNumbers,
      foilStarDetected: hints.foilStarDetected,
      matchPath: 'latest',
    );
    return latest;
  }

  Future<_PrintingHints> _extractPrintingHints(
    RecognizedText recognized,
    String photoPath,
    List<MTGCard> versions,
  ) async {
    final rawSetCodes = <String>{};
    final rawLanguages = <String>{};
    final rawCollectorNumbers = <String>{};
    var foilStarDetected = false;

    final likelySetCodes = versions
        .map((card) => card.setCode?.toLowerCase())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    final likelyLanguages = versions
        .map((card) => card.lang?.toLowerCase())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    final likelyCollectorNumbers = versions
        .map((card) => _normalizeCollectorNumber(card.collectorNumber))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();

    // Collect every token from the full OCR output — no spatial filtering.
    // The known-values filter below is safer than guessing coordinates.
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (_containsFoilStarToken(line.text)) {
          foilStarDetected = true;
        }
        for (final element in line.elements) {
          final compact = element.text
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9*★✶✦☆]+'), '');
          if (compact.isEmpty) continue;
          if (_containsFoilStarToken(compact)) {
            foilStarDetected = true;
          }
          final alphaNumeric = compact.replaceAll(RegExp(r'[^a-z0-9]+'), '');
          if (alphaNumeric.length == 2 &&
              RegExp(r'^[a-z]{2}$').hasMatch(alphaNumeric)) {
            rawLanguages.add(alphaNumeric);
          }
          if (alphaNumeric.length >= 3 && alphaNumeric.length <= 5) {
            rawSetCodes.add(alphaNumeric);
          }
          final collectorToken = _normalizeCollectorNumber(alphaNumeric);
          if (collectorToken != null && collectorToken.isNotEmpty) {
            rawCollectorNumbers.add(collectorToken);
          }
        }
      }
    }

    // Keep only tokens that match something in the printings list.
    // If the printings list is empty, pass everything through.
    final filteredSetCodes = likelySetCodes.isEmpty
        ? rawSetCodes
        : rawSetCodes.where(likelySetCodes.contains).toSet();
    final filteredLanguages = likelyLanguages.isEmpty
        ? rawLanguages
        : rawLanguages.where(likelyLanguages.contains).toSet();
    final filteredCollectorNumbers = likelyCollectorNumbers.isEmpty
        ? rawCollectorNumbers
        : rawCollectorNumbers.where(likelyCollectorNumbers.contains).toSet();

    return _PrintingHints(
      setCodes: filteredSetCodes,
      languages: filteredLanguages,
      collectorNumbers: filteredCollectorNumbers,
      foilStarDetected: foilStarDetected,
      rawSetCodes: rawSetCodes,
      rawLanguages: rawLanguages,
      rawCollectorNumbers: rawCollectorNumbers,
    );
  }

  MTGCard? _resolveFromPrimaryHints(
      List<MTGCard> versions, _PrintingHints hints,
      {bool requireConfidence = false}) {
    MTGCard? bestCard;
    double bestScore = double.negativeInfinity;
    double secondBestScore = double.negativeInfinity;

    for (final candidate in versions) {
      var score = 0.0;
      final setCode = candidate.setCode?.toLowerCase();
      final lang = candidate.lang?.toLowerCase();
      final collector = _normalizeCollectorNumber(candidate.collectorNumber);
      final finishes = (candidate.finishes ?? const <String>[])
          .map((e) => e.toLowerCase())
          .toSet();

      if (hints.setCodes.isNotEmpty) {
        if (setCode != null && hints.setCodes.contains(setCode)) {
          score += 120;
        } else {
          score -= 45;
        }
      }

      if (hints.languages.isNotEmpty) {
        if (lang != null && hints.languages.contains(lang)) {
          score += 70;
        } else {
          score -= 30;
        }
      }

      if (hints.collectorNumbers.isNotEmpty) {
        if (collector != null && hints.collectorNumbers.contains(collector)) {
          score += 130;
        } else {
          score -= 35;
        }
      }

      if (hints.foilStarDetected) {
        if (finishes.contains('foil') || finishes.contains('etched')) {
          score += 50;
        } else if (finishes.contains('nonfoil')) {
          score -= 18;
        }
      }

      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestCard = candidate;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestCard == null) return null;

    final margin = bestScore - secondBestScore;
    if (!requireConfidence || (bestScore >= 40 && margin >= 8)) {
      return bestCard;
    }

    return null;
  }

  bool _containsFoilStarToken(String value) {
    return value.contains('*') ||
        value.contains('★') ||
        value.contains('✶') ||
        value.contains('✦') ||
        value.contains('☆');
  }

  String? _normalizeCollectorNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized =
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized.isEmpty) return null;
    if (!RegExp(r'[0-9]').hasMatch(normalized)) return null;
    return normalized;
  }

  Future<String?> _inferSetCodeFromSymbol(
    List<MTGCard> versions,
    String photoPath,
  ) async {
    final observed = await _extractObservedSetSymbolDescriptors(photoPath);
    if (observed.isEmpty) return null;

    String? bestSetCode;
    double bestScore = double.negativeInfinity;
    double secondBest = double.negativeInfinity;

    final seenCodes = <String>{};
    for (final card in versions) {
      final setCode = card.setCode?.toLowerCase();
      if (setCode == null || setCode.isEmpty || !seenCodes.add(setCode)) {
        continue;
      }
      final pseudoCard = MTGCard(
        id: card.id,
        name: card.name,
        cmc: card.cmc,
        legalities: card.legalities,
        setCode: setCode,
      );
      final score = await _scoreCandidateFromSetSymbol(pseudoCard, observed);
      if (score == null) continue;

      if (score > bestScore) {
        secondBest = bestScore;
        bestScore = score;
        bestSetCode = setCode;
      } else if (score > secondBest) {
        secondBest = score;
      }
    }

    if (bestSetCode == null) return null;
    final margin = bestScore - secondBest;
    if (bestScore >= 0.62 && margin >= 0.04) {
      return bestSetCode;
    }
    return null;
  }

  Future<MTGCard?> _resolveFromImageAndName(
    List<MTGCard> versions,
    _PrintingHints hints,
    String photoPath,
  ) async {
    final observedSymbolDescriptors =
        await _extractObservedSetSymbolDescriptors(photoPath);
    if (observedSymbolDescriptors.isEmpty) {
      return _chooseLatestVersion(versions, hints);
    }

    MTGCard? bestCard;
    double bestScore = double.negativeInfinity;
    double secondBestScore = double.negativeInfinity;

    for (final candidate in versions) {
      var score = 0.0;
      final symbolScore = await _scoreCandidateFromSetSymbol(
        candidate,
        observedSymbolDescriptors,
      );
      if (symbolScore != null) {
        score += symbolScore * 120;
      }

      if (hints.languages.isNotEmpty) {
        final lang = candidate.lang?.toLowerCase();
        if (lang != null && hints.languages.contains(lang)) {
          score += 22;
        }
      }
      if (hints.collectorNumbers.isNotEmpty) {
        final collector = _normalizeCollectorNumber(candidate.collectorNumber);
        if (collector != null && hints.collectorNumbers.contains(collector)) {
          score += 35;
        }
      }

      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestCard = candidate;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestCard == null) return _chooseLatestVersion(versions, hints);

    final margin = bestScore - secondBestScore;
    if (bestScore >= 70 && margin >= 8) {
      return bestCard;
    }

    return _chooseLatestVersion(versions, hints);
  }

  MTGCard? _chooseLatestVersion(
    List<MTGCard> versions, [
    _PrintingHints? hints,
  ]) {
    if (versions.isEmpty) return null;

    final filtered = versions.where((card) {
      if (hints == null) return true;
      if (hints.languages.isNotEmpty) {
        final lang = card.lang?.toLowerCase();
        if (lang == null || !hints.languages.contains(lang)) return false;
      }
      return true;
    }).toList(growable: false);

    final pool = filtered.isEmpty ? versions : filtered;
    final sorted = pool.toList(growable: false)
      ..sort((a, b) {
        final dateA = a.releasedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.releasedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateCmp = dateB.compareTo(dateA);
        if (dateCmp != 0) return dateCmp;

        final aCollector = _normalizeCollectorNumber(a.collectorNumber) ?? '';
        final bCollector = _normalizeCollectorNumber(b.collectorNumber) ?? '';
        return bCollector.compareTo(aCollector);
      });
    return sorted.first;
  }

  Future<List<MTGCard>> _fetchByPrintedNameFallbackFromScryfall(
    List<String> nameCandidates,
    Set<String> languages,
  ) async {
    final results = <MTGCard>[];
    final seen = <String>{};
    if (nameCandidates.isEmpty) return results;

    final guesses = nameCandidates
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));
    if (guesses.isEmpty) return results;

    final limitedGuesses = guesses.take(3).toList(growable: false);
    final languageScope =
        languages.isEmpty ? const <String?>[null] : [...languages.take(2)];

    for (final guess in limitedGuesses) {
      for (final lang in languageScope) {
        final query = lang == null
            ? 'printed_name:"$guess" game:paper'
            : 'printed_name:"$guess" lang:$lang game:paper';

        try {
          final encodedQuery = Uri.encodeQueryComponent(query);
          final uri = Uri.parse(
            'https://api.scryfall.com/cards/search?q=$encodedQuery&unique=prints&include_multilingual=true',
          );
          final response = await http
              .get(uri, headers: _scryfallHeaders)
              .timeout(const Duration(seconds: 12));
          if (response.statusCode != 200) continue;

          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final items =
              (payload['data'] as List?)?.whereType<Map<String, dynamic>>() ??
                  const [];
          for (final item in items) {
            final card = MTGCard.fromJson(item);
            if (seen.add(card.id)) {
              results.add(card);
            }
          }
          if (results.isNotEmpty) return results;
        } catch (_) {
          continue;
        }
      }
    }

    return results;
  }

  Future<img.Image?> _loadPhotoImage(String photoPath) async {
    try {
      final bytes = await File(photoPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      var oriented = img.bakeOrientation(decoded);
      if (oriented.width > oriented.height) {
        oriented = img.copyRotate(oriented, angle: 90);
      }
      return oriented;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _scoreCandidateFromSetSymbol(
    MTGCard candidate,
    List<List<double>> observedDescriptors,
  ) async {
    if (observedDescriptors.isEmpty) return null;

    final setCode = candidate.setCode;
    if (setCode == null || setCode.isEmpty) return null;

    final templateDescriptor = await _descriptorForSetCode(setCode);
    if (templateDescriptor == null) return null;

    double? best;
    for (final observed in observedDescriptors) {
      final score = _cosineSimilarity(templateDescriptor, observed);
      if (best == null || score > best) {
        best = score;
      }
    }

    return best;
  }

  Future<List<double>?> _descriptorForSetCode(String setCode) {
    final normalized = setCode.toLowerCase();
    return _setSymbolDescriptorCache.putIfAbsent(normalized, () async {
      final setService = context.read<SetService>();
      final svgData = setService.iconSvgBySetCode(normalized);
      if (svgData == null || svgData.isEmpty) return null;

      try {
        final PictureInfo pictureInfo = await vg.loadPicture(
          SvgStringLoader(svgData),
          null,
        );
        try {
          final raster = await pictureInfo.picture.toImage(64, 64);
          final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) return null;
          final decoded = img.decodeImage(bytes.buffer.asUint8List());
          if (decoded == null) return null;
          return _buildShapeDescriptor(decoded);
        } finally {
          pictureInfo.picture.dispose();
        }
      } catch (_) {
        return null;
      }
    });
  }

  Future<List<List<double>>> _extractObservedSetSymbolDescriptors(
    String photoPath,
  ) async {
    try {
      final oriented = await _loadPhotoImage(photoPath);
      if (oriented == null) return const [];

      final cardCrops = _extractCentralCardCrops(oriented);
      final descriptors = <List<double>>[];
      for (final cardCrop in cardCrops) {
        for (final spec in _symbolCropSpecs) {
          final crop = _cropRelativeSquare(cardCrop, spec);
          descriptors.add(_buildShapeDescriptor(crop));
        }
      }
      return descriptors;
    } catch (_) {
      return const [];
    }
  }

  List<img.Image> _extractCentralCardCrops(img.Image image) {
    final crops = <img.Image>[];

    for (final widthFraction in _cardWidthFractions) {
      var width = (image.width * widthFraction).round();
      var height = (width * 7 / 5).round();

      final maxHeight = (image.height * 0.92).round();
      if (height > maxHeight) {
        height = maxHeight;
        width = (height * 5 / 7).round();
      }

      final left = ((image.width - width) / 2).round();
      final top = ((image.height - height) / 2 - image.height * 0.015).round();

      crops.add(
        img.copyCrop(
          image,
          x: left,
          y: math.max(0, top),
          width: width,
          height: height,
        ),
      );
    }

    return crops;
  }

  img.Image _cropRelativeSquare(img.Image image, _SymbolCropSpec spec) {
    final size = math.max(12, (image.width * spec.sizeFactor).round());
    final centerX = (image.width * spec.centerX).round();
    final centerY = (image.height * spec.centerY).round();
    final left = centerX - size ~/ 2;
    final top = centerY - size ~/ 2;

    return img.copyCrop(
      image,
      x: left.clamp(0, math.max(0, image.width - size)),
      y: top.clamp(0, math.max(0, image.height - size)),
      width: math.min(size, image.width),
      height: math.min(size, image.height),
    );
  }

  List<double> _buildShapeDescriptor(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _symbolDescriptorSize,
      height: _symbolDescriptorSize,
      interpolation: img.Interpolation.linear,
    );

    final backgroundLuma = _estimateBorderLuminance(resized);
    final values = List<double>.filled(
      _symbolDescriptorSize * _symbolDescriptorSize,
      0,
      growable: false,
    );

    for (var y = 0; y < _symbolDescriptorSize; y++) {
      for (var x = 0; x < _symbolDescriptorSize; x++) {
        final pixel = resized.getPixel(x, y);
        final red = pixel.r / 255.0;
        final green = pixel.g / 255.0;
        final blue = pixel.b / 255.0;
        final alpha = pixel.a / 255.0;

        final maxChannel = math.max(red, math.max(green, blue));
        final minChannel = math.min(red, math.min(green, blue));
        final saturation =
            maxChannel <= 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
        final luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        final contrast = (luminance - backgroundLuma).abs();

        values[y * _symbolDescriptorSize + x] =
            math.max(saturation, contrast) * alpha;
      }
    }

    final descriptor = List<double>.filled(values.length, 0, growable: false);
    final center = (_symbolDescriptorSize - 1) / 2.0;
    final maxDistance = math.sqrt(center * center * 2);

    for (var y = 0; y < _symbolDescriptorSize; y++) {
      for (var x = 0; x < _symbolDescriptorSize; x++) {
        final index = y * _symbolDescriptorSize + x;
        final current = values[index];
        final left = values[y * _symbolDescriptorSize + math.max(0, x - 1)];
        final right = values[y * _symbolDescriptorSize +
            math.min(_symbolDescriptorSize - 1, x + 1)];
        final top = values[math.max(0, y - 1) * _symbolDescriptorSize + x];
        final bottom = values[
            math.min(_symbolDescriptorSize - 1, y + 1) * _symbolDescriptorSize +
                x];
        final edge = ((current - left).abs() +
                (current - right).abs() +
                (current - top).abs() +
                (current - bottom).abs()) /
            4.0;

        final dx = x - center;
        final dy = y - center;
        final distanceWeight =
            1.0 - (math.sqrt(dx * dx + dy * dy) / maxDistance) * 0.45;
        descriptor[index] = (current * 0.6 + edge * 0.4) * distanceWeight;
      }
    }

    return descriptor;
  }

  double _estimateBorderLuminance(img.Image image) {
    var total = 0.0;
    var count = 0;

    for (var x = 0; x < image.width; x++) {
      total += _pixelLuminance(image.getPixel(x, 0));
      total += _pixelLuminance(image.getPixel(x, image.height - 1));
      count += 2;
    }

    for (var y = 1; y < image.height - 1; y++) {
      total += _pixelLuminance(image.getPixel(0, y));
      total += _pixelLuminance(image.getPixel(image.width - 1, y));
      count += 2;
    }

    if (count == 0) return 1.0;
    return total / count;
  }

  double _pixelLuminance(img.Pixel pixel) {
    final red = pixel.r / 255.0;
    final green = pixel.g / 255.0;
    final blue = pixel.b / 255.0;
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  double _cosineSimilarity(List<double> left, List<double> right) {
    if (left.length != right.length || left.isEmpty) return 0;

    var dot = 0.0;
    var leftMagnitude = 0.0;
    var rightMagnitude = 0.0;

    for (var i = 0; i < left.length; i++) {
      dot += left[i] * right[i];
      leftMagnitude += left[i] * left[i];
      rightMagnitude += right[i] * right[i];
    }

    if (leftMagnitude <= 0 || rightMagnitude <= 0) return 0;
    return dot / math.sqrt(leftMagnitude * rightMagnitude);
  }

  int _nameSimilarityScore(String observed, String knownName) {
    if (observed == knownName) return 140;
    if (knownName.startsWith(observed) || observed.startsWith(knownName)) {
      return 105 - (knownName.length - observed.length).abs();
    }
    if (knownName.contains(observed) || observed.contains(knownName)) {
      return 95 - (knownName.length - observed.length).abs();
    }

    final observedTokens =
        observed.split(' ').where((v) => v.isNotEmpty).toSet();
    final knownTokens = knownName.split(' ').where((v) => v.isNotEmpty).toSet();
    if (observedTokens.isEmpty || knownTokens.isEmpty) return 0;

    final overlap = observedTokens.intersection(knownTokens).length;
    if (overlap == 0) return 0;

    final tokenRatio = (overlap * 100) ~/ knownTokens.length;
    final lengthPenalty =
        (knownName.length - observed.length).abs().clamp(0, 24);
    return tokenRatio - lengthPenalty;
  }

  String _normalize(String value) {
    final lower = value.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return replaced.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _openCardZoom(MTGCard card) async {
    if (_isOpeningZoom || !mounted) return;
    _isOpeningZoom = true;
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => CardZoomView(
            cards: [card],
            initialIndex: 0,
          ),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      _isOpeningZoom = false;
      if (mounted && _quickScanEnabled && !_isCapturing) {
        unawaited(_resumeQuickScanMonitoringSoon());
      }
    }
  }

  Future<void> _resumeQuickScanMonitoringSoon() async {
    // Let route transitions and stream shutdown settle before restarting.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_quickScanEnabled || _isCapturing) return;

    if (_isStoppingImageStream) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || !_quickScanEnabled || _isCapturing) return;
    }

    _startCardPresenceMonitoring();
  }

  void _toggleQuickScan() {
    setState(() => _quickScanEnabled = !_quickScanEnabled);
    if (_quickScanEnabled) {
      _startCardPresenceMonitoring();
    } else {
      _stopCardPresenceMonitoring();
    }
  }

  void _startCardPresenceMonitoring() {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isMonitoringCard ||
        _isStoppingImageStream) {
      return;
    }
    if (controller.value.isStreamingImages) {
      _isMonitoringCard = true;
      return;
    }
    _isMonitoringCard = true;
    _detectionHitStreak = 0;
    _prevFrameLuma = null;
    try {
      controller.startImageStream(_onDetectionFrame);
    } catch (e) {
      _isMonitoringCard = false;
      if (mounted) {
        setState(() {
          _statusText = 'Quick scan failed to start: $e';
        });
      }
    }
  }

  void _stopCardPresenceMonitoring() {
    unawaited(_stopCardPresenceMonitoringAsync());
  }

  Future<void> _stopCardPresenceMonitoringAsync() async {
    if (!_isMonitoringCard) {
      _isProcessingDetection = false;
      _detectionHitStreak = 0;
      return;
    }
    _isMonitoringCard = false;
    _isProcessingDetection = false;
    _detectionHitStreak = 0;
    _cardBoundsFadeTimer?.cancel();
    _cardBoundsFadeTimer = Timer(const Duration(milliseconds: 500), () {
      _cardBoundsNotifier.value = null;
    });
    final controller = _cameraController;
    if (controller == null || _isStoppingImageStream) return;
    _isStoppingImageStream = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
    } finally {
      _isStoppingImageStream = false;
    }
  }

  void _onDetectionFrame(CameraImage image) {
    if (!_quickScanEnabled ||
        !mounted ||
        _isCapturing ||
        _isProcessingDetection) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 250) return;
    _lastFrameTime = now;
    _isProcessingDetection = true;

    final luma = _extractCenterLumaFromFrame(image, 80, 112);
    if (luma == null) {
      _isProcessingDetection = false;
      return;
    }
    final prev = _prevFrameLuma;
    _prevFrameLuma = luma;

    compute(
      _detectCardPresenceIsolate,
      <String, Object>{
        'current': luma,
        if (prev != null) 'prev': prev,
        'width': 80,
        'height': 112,
        'cameraWidth': image.width.toDouble(),
        'cameraHeight': image.height.toDouble(),
      },
    ).then((bounds) {
      _isProcessingDetection = false;
      if (!mounted || !_quickScanEnabled || _isCapturing) return;
      if (bounds != null) {
        _cardBoundsFadeTimer?.cancel();
        _cardBoundsNotifier.value = bounds;
        _detectionHitStreak += 1;
        if (_detectionHitStreak >= 1) {
          _detectionHitStreak = 0;
          unawaited(_triggerQuickScan());
        }
      } else {
        _detectionHitStreak = 0;
        _cardBoundsFadeTimer?.cancel();
        _cardBoundsFadeTimer = Timer(const Duration(milliseconds: 600), () {
          _cardBoundsNotifier.value = null;
        });
      }
    }).catchError((_) {
      _isProcessingDetection = false;
      _detectionHitStreak = 0;
    });
  }

  Future<void> _triggerQuickScan() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card detected. Scanning...'),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _stopCardPresenceMonitoringAsync();
    await _scanCard(restartMonitoring: false);
    // Pause briefly so the same card isn't immediately re-scanned.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted && _quickScanEnabled && !_isOpeningZoom) {
      await _resumeQuickScanMonitoringSoon();
    }
  }

  Future<void> _switchCamera(CameraDescription camera) async {
    await _stopCardPresenceMonitoringAsync();
    final old = _cameraController;
    setState(() => _cameraController = null);
    await old?.dispose();
    await _initCamera(camera);
    if (mounted && _quickScanEnabled) {
      _startCardPresenceMonitoring();
    }
  }

  Future<MTGCard?> _applySetLock(MTGCard card, String setCode) async {
    if ((card.setCode?.toLowerCase() ?? '') == setCode) return card;
    final printings = await _fetchPrintingsForName(card.name);
    if (printings.isEmpty) return null;
    final inSetEn = printings
        .where(
          (p) =>
              p.setCode?.toLowerCase() == setCode &&
              (p.lang?.toLowerCase() ?? '') == 'en',
        )
        .toList(growable: false);
    if (inSetEn.isNotEmpty) return _chooseLatestVersion(inSetEn) ?? card;
    final inSet = printings
        .where((p) => p.setCode?.toLowerCase() == setCode)
        .toList(growable: false);
    return inSet.isEmpty ? null : (_chooseLatestVersion(inSet) ?? card);
  }

  String _resolveSetLockCode(String rawInput) {
    final value = rawInput.trim();
    if (value.isEmpty) return '';

    final trailingCodeMatch =
        RegExp(r'\(([a-zA-Z0-9]+)\)\s*$').firstMatch(value);
    if (trailingCodeMatch != null) {
      final matched = trailingCodeMatch.group(1);
      if (matched != null && matched.isNotEmpty) {
        return matched.toLowerCase();
      }
    }

    final sets = context.read<SetService>().sets;
    final lower = value.toLowerCase();
    for (final set in sets) {
      if (set.code.toLowerCase() == lower || set.name.toLowerCase() == lower) {
        return set.code.toLowerCase();
      }
    }

    return lower;
  }

  String _displaySetLockInput(String? setCode) {
    if (setCode == null || setCode.isEmpty) return '';
    final sets = context.read<SetService>().sets;
    for (final set in sets) {
      if (set.code.toLowerCase() == setCode.toLowerCase()) {
        return '${set.name} (${set.code.toUpperCase()})';
      }
    }
    return setCode.toUpperCase();
  }

  void _showSettingsDialog() {
    final setService = context.read<SetService>();
    final setController = TextEditingController(
      text: _displaySetLockInput(_lockedSetCode),
    );
    bool focusListenerAdded = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (_, setDialogState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(dialogCtx).textTheme.titleMedium,
                        ),
                        if (_availableCameras.length > 1) ...[
                          const SizedBox(height: 20),
                          Text(
                            'CAMERA',
                            style: Theme.of(dialogCtx)
                                .textTheme
                                .labelSmall
                                ?.copyWith(letterSpacing: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableCameras.map((camera) {
                              final isSelected =
                                  _selectedCamera?.name == camera.name;
                              return ChoiceChip(
                                selected: isSelected,
                                avatar: Icon(
                                    _cameraDirectionIcon(camera.lensDirection),
                                    size: 18),
                                label: Text(_cameraLabel(camera)),
                                onSelected: isSelected
                                    ? null
                                    : (_) {
                                        Navigator.of(dialogCtx).pop();
                                        _switchCamera(camera);
                                      },
                              );
                            }).toList(growable: false),
                          ),
                          const Divider(height: 24),
                        ],
                        Text(
                          'SET LOCK',
                          style: Theme.of(dialogCtx)
                              .textTheme
                              .labelSmall
                              ?.copyWith(letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search by set name or set code. Suggestions are shown by set name.',
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Autocomplete<_CardPickSetOption>(
                                optionsBuilder: (textEditingValue) {
                                  final query = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  final sets = setService.sets;
                                  if (sets.isEmpty) {
                                    return const Iterable<
                                        _CardPickSetOption>.empty();
                                  }

                                  final filtered = sets.where((set) {
                                    if (query.isEmpty) return true;
                                    return set.name
                                            .toLowerCase()
                                            .contains(query) ||
                                        set.code.toLowerCase().contains(query);
                                  });

                                  return filtered.take(40).map(
                                        (set) => _CardPickSetOption(
                                          code: set.code,
                                          name: set.name,
                                          iconSvg: setService.iconSvgBySetCode(
                                            set.code,
                                          ),
                                        ),
                                      );
                                },
                                fieldViewBuilder: (context, controller,
                                    focusNode, onSubmitted) {
                                  // Show all set suggestions when field gains focus
                                  if (!focusListenerAdded) {
                                    focusNode.addListener(() {
                                      if (focusNode.hasFocus &&
                                          controller.text.isEmpty) {
                                        // Trigger autocomplete by touching text
                                        controller.text = ' ';
                                        controller.clear();
                                      }
                                    });
                                    focusListenerAdded = true;
                                  }
                                  controller.text = setController.text;
                                  controller.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: controller.text.length),
                                  );
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Zendikar or khm',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                      suffixIcon: controller.text.isEmpty
                                          ? null
                                          : IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () {
                                                final hadLock = _lockedSetCode !=
                                                    null;
                                                setDialogState(() {
                                                  controller.clear();
                                                  setController.clear();
                                                });
                                                if (hadLock) {
                                                  setState(() {
                                                    _lockedSetCode = null;
                                                  });
                                                  AppHaptics.selection();
                                                }
                                              },
                                            ),
                                    ),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        setController.text = value;
                                      });
                                    },
                                    onSubmitted: (value) {
                                      final code = _resolveSetLockCode(value);
                                      setState(() {
                                        _lockedSetCode = code.isEmpty ? null : code;
                                      });
                                      AppHaptics.selection();
                                      Navigator.of(dialogCtx).pop();
                                    },
                                  );
                                },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                  final rendered =
                                      options.toList(growable: false);
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(10),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 280,
                                          maxWidth: 420,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: rendered.length,
                                          itemBuilder: (context, index) {
                                            final option = rendered[index];
                                            return ListTile(
                                              dense: true,
                                              leading: option.iconSvg == null
                                                  ? const Icon(Icons.style)
                                                  : SvgPicture.string(
                                                      option.iconSvg!,
                                                      width: 18,
                                                      height: 18,
                                                    ),
                                              title: Text(option.name),
                                              subtitle: Text(
                                                  option.code.toUpperCase()),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                onSelected: (selection) {
                                  final displayValue =
                                      '${selection.name} (${selection.code.toUpperCase()})';
                                  setDialogState(() {
                                    setController.text = displayValue;
                                  });
                                  setState(() {
                                    _lockedSetCode = selection.code.toLowerCase();
                                  });
                                  AppHaptics.selection();
                                  Navigator.of(dialogCtx).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ).then((_) => setController.dispose());
  }

  String _cameraLabel(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return 'Front Camera';
      case CameraLensDirection.back:
        return 'Back Camera';
      case CameraLensDirection.external:
        return 'External Camera';
    }
  }

  IconData _cameraDirectionIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.external:
        return Icons.videocam;
    }
  }

  Widget _buildFloatingMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_lockedSetCode != null)
          GestureDetector(
            onTap: () {
              setState(() {
                _lockedSetCode = null;
              });
              AppHaptics.selection();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.88),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Builder(builder: (context) {
                final setService = context.read<SetService>();
                final iconSvg = setService.iconSvgBySetCode(_lockedSetCode!);
                return SizedBox(
                  width: 24,
                  height: 24,
                  child: iconSvg != null
                      ? SvgPicture.string(
                          iconSvg,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(
                          Icons.style,
                          size: 24,
                          color: Colors.white.withOpacity(0.7),
                        ),
                );
              }),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _quickScanEnabled ? Icons.bolt : Icons.bolt_outlined,
                      color: _quickScanEnabled
                          ? Colors.greenAccent
                          : Colors.white70,
                    ),
                    tooltip: _quickScanEnabled
                        ? 'Quick Scan: ON'
                        : 'Quick Scan: OFF',
                    onPressed: _toggleQuickScan,
                  ),
                  Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _lockedSetCode != null
                          ? Colors.orangeAccent
                          : Colors.white70,
                    ),
                    tooltip: 'Settings',
                    onPressed: _showSettingsDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugPanel(_DebugScanInfo info) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug — Last Scan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          _debugRow('Path', _pathLabel(info.matchPath)),
          _debugRow('Card', info.cardName),
          if (info.resolvedSetCode != null)
            _debugRow('Resolved set', info.resolvedSetCode!.toUpperCase()),
          _debugRow(
            'OCR set codes (raw)',
            info.rawSetCodes.isEmpty ? '—' : info.rawSetCodes.join(', '),
          ),
          _debugRow(
            'OCR set codes (matched)',
            info.filteredSetCodes.isEmpty
                ? '—'
                : info.filteredSetCodes.join(', '),
          ),
          _debugRow(
            'OCR languages (raw)',
            info.rawLanguages.isEmpty ? '—' : info.rawLanguages.join(', '),
          ),
          _debugRow(
            'OCR languages (matched)',
            info.filteredLanguages.isEmpty
                ? '—'
                : info.filteredLanguages.join(', '),
          ),
          _debugRow(
            'Collector (raw)',
            info.rawCollectorNumbers.isEmpty
                ? '—'
                : info.rawCollectorNumbers.join(', '),
          ),
          _debugRow(
            'Collector (matched)',
            info.filteredCollectorNumbers.isEmpty
                ? '—'
                : info.filteredCollectorNumbers.join(', '),
          ),
          _debugRow(
            'Old-frame heuristic',
            _lastOldFrameHeuristic == null
                ? '—'
                : (_lastOldFrameHeuristic! ? 'Yes' : 'No'),
          ),
          _debugRow(
              'Foil star detected', info.foilStarDetected ? 'Yes ★' : 'No'),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _pathLabel(String path) {
    switch (path) {
      case 'ocr':
        return 'OCR hints';
      case 'symbol':
        return 'Symbol matching';
      case 'single':
        return 'Single version';
      case 'latest':
        return 'Latest by name';
      default:
        return path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final showCamera =
        !_isSettingUp && controller != null && controller.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Pick (beta)'),
        actions: [
          IconButton(
            icon: Icon(
              _showDebugOverlay ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugOverlay
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Toggle debug info',
            onPressed: () =>
                setState(() => _showDebugOverlay = !_showDebugOverlay),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showCamera)
                  CameraPreview(controller)
                else
                  const ColoredBox(
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 390,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                    ),
                  ),
                ),
                if (_quickScanEnabled)
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: _CardOutlineOverlay(
                        boundsNotifier: _cardBoundsNotifier,
                      ),
                    ),
                  ),
                if (_showDebugOverlay && _lastDebugInfo != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _buildDebugPanel(_lastDebugInfo!),
                  ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildFloatingMenu(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: (showCamera && !_isCapturing) ? _scanCard : null,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isCapturing
                        ? 'Scanning...'
                        : _quickScanEnabled
                            ? 'Quick Scan Active'
                            : 'Scan Card',
                  ),
                ),
                if (!showCamera && !_isSettingUp) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _onPermissionActionPressed,
                    icon: Icon(
                      _cameraPermissionPermanentlyDenied
                          ? Icons.settings
                          : Icons.verified_user,
                    ),
                    label: Text(
                      _cameraPermissionPermanentlyDenied
                          ? 'Open Settings'
                          : 'Grant Camera Access',
                    ),
                  ),
                ],
                if (_lastMatchedCard != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isOpeningZoom
                        ? null
                        : () => _openCardZoom(_lastMatchedCard!),
                    icon: const Icon(Icons.open_in_full),
                    label: Text('Open ${_lastMatchedCard!.name}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers (run in compute isolate)
// ---------------------------------------------------------------------------

/// Extracts a centre-crop luma image from a [CameraImage], downsampled to
/// [targetW] × [targetH]. Returns `null` if the format is not supported.
Uint8List? _extractCenterLumaFromFrame(
  CameraImage image,
  int targetW,
  int targetH,
) {
  final fw = image.width;
  final fh = image.height;
  if (fw <= 0 || fh <= 0) return null;

  // ROI: centre 72 % width × 84 % height
  final roiLeft = (fw * 0.14).round();
  final roiTop = (fh * 0.08).round();
  final roiW = fw - roiLeft * 2;
  final roiH = fh - roiTop * 2;
  if (roiW <= 0 || roiH <= 0) return null;

  final out = Uint8List(targetW * targetH);
  final scaleX = roiW / targetW;
  final scaleY = roiH / targetH;
  final format = image.format.group;

  for (var ty = 0; ty < targetH; ty++) {
    for (var tx = 0; tx < targetW; tx++) {
      final srcX = (roiLeft + tx * scaleX).round().clamp(0, fw - 1);
      final srcY = (roiTop + ty * scaleY).round().clamp(0, fh - 1);
      int luma;
      if (format == ImageFormatGroup.yuv420) {
        final plane = image.planes[0];
        final idx = srcY * plane.bytesPerRow + srcX;
        luma = idx < plane.bytes.length ? plane.bytes[idx] : 0;
      } else {
        // BGRA8888 (iOS) or similar
        final plane = image.planes[0];
        final bpp = plane.bytesPerPixel ?? 4;
        final idx = srcY * plane.bytesPerRow + srcX * bpp;
        if (bpp >= 3 && idx + 2 < plane.bytes.length) {
          final b = plane.bytes[idx];
          final g = plane.bytes[idx + 1];
          final r = plane.bytes[idx + 2];
          luma = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);
        } else {
          luma = idx < plane.bytes.length ? plane.bytes[idx] : 0;
        }
      }
      out[ty * targetW + tx] = luma.clamp(0, 255);
    }
  }
  return out;
}

/// Run in [compute]. Returns normalised card bounds when a stable, textured
/// card-like object is detected in the centre of the luma frame, or `null`.
_CardBounds? _detectCardPresenceIsolate(Map<String, Object> args) {
  final current = args['current']! as Uint8List;
  final prev = args['prev'] as Uint8List?;
  final width = args['width']! as int;
  final height = args['height']! as int;
  final cameraWidth = args['cameraWidth'] as double? ?? 1920;
  final cameraHeight = args['cameraHeight'] as double? ?? 1080;

  final cx0 = width ~/ 5;
  final cx1 = width * 4 ~/ 5;
  final cy0 = height ~/ 5;
  final cy1 = height * 4 ~/ 5;
  final halfX = (cx0 + cx1) ~/ 2;
  final halfY = (cy0 + cy1) ~/ 2;

  int peakIndex(List<double> values, int start, int end) {
    var bestIndex = start;
    var bestValue = double.negativeInfinity;
    for (var i = start; i < end; i++) {
      final value = values[i];
      if (value > bestValue) {
        bestValue = value;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  // 1. Texture: variance of centre-region luma.  Cards carry art and text
  //    → high variance; an empty background is typically low variance.
  double sum = 0;
  double sumSq = 0;
  var count = 0;
  var edgePixels = 0;
  final colEdgeEnergy = List<double>.filled(width, 0, growable: false);
  final rowEdgeEnergy = List<double>.filled(height, 0, growable: false);
  // Split-quadrant accumulators for perspective-aware corner detection —
  // computed in the same pass, no extra pixel reads.
  final colEdgeTop = List<double>.filled(width, 0, growable: false);
  final colEdgeBot = List<double>.filled(width, 0, growable: false);
  final rowEdgeLeft = List<double>.filled(height, 0, growable: false);
  final rowEdgeRight = List<double>.filled(height, 0, growable: false);
  for (var y = cy0; y < cy1; y++) {
    for (var x = cx0; x < cx1; x++) {
      final v = current[y * width + x].toDouble();
      sum += v;
      sumSq += v * v;
      count++;

      if (x > cx0 && x < cx1 - 1 && y > cy0 && y < cy1 - 1) {
        final gx =
            (current[y * width + x + 1] - current[y * width + x - 1]).abs();
        final gy =
            (current[(y + 1) * width + x] - current[(y - 1) * width + x]).abs();
        final grad = (gx + gy) / 2;
        if (grad >= 16) {
          edgePixels++;
        }
        final gxd = gx.toDouble();
        final gyd = gy.toDouble();
        colEdgeEnergy[x] += gxd;
        rowEdgeEnergy[y] += gyd;
        if (y < halfY) {
          colEdgeTop[x] += gxd;
        } else {
          colEdgeBot[x] += gxd;
        }
        if (x < halfX) {
          rowEdgeLeft[y] += gyd;
        } else {
          rowEdgeRight[y] += gyd;
        }
      }
    }
  }
  if (count == 0) return null;
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  final edgeDensity = edgePixels / count;

  // 2. Border shape check: look for strong vertical and horizontal edges in
  // opposite halves of the ROI and verify a card-like aspect ratio.
  // Full-axis peaks used only for the plausibility gate.
  final leftEdgeX = peakIndex(colEdgeEnergy, cx0, halfX);
  final rightEdgeX = peakIndex(colEdgeEnergy, halfX, cx1);
  final topEdgeY = peakIndex(rowEdgeEnergy, cy0, halfY);
  final bottomEdgeY = peakIndex(rowEdgeEnergy, halfY, cy1);

  // Quadrant-restricted peaks for the four corners (perspective / skew aware).
  final tlX = peakIndex(colEdgeTop, cx0, halfX);
  final trX = peakIndex(colEdgeTop, halfX, cx1);
  final blX = peakIndex(colEdgeBot, cx0, halfX);
  final brX = peakIndex(colEdgeBot, halfX, cx1);
  final tlY = peakIndex(rowEdgeLeft, cy0, halfY);
  final blY = peakIndex(rowEdgeLeft, halfY, cy1);
  final trY = peakIndex(rowEdgeRight, cy0, halfY);
  final brY = peakIndex(rowEdgeRight, halfY, cy1);

  final cardW = (rightEdgeX - leftEdgeX).abs();
  final cardH = (bottomEdgeY - topEdgeY).abs();
  final roiW = cx1 - cx0;
  final roiH = cy1 - cy0;
  final aspect = cardH == 0 ? 0.0 : cardW / cardH;

  final rowsSampled = (cy1 - cy0).clamp(1, height);
  final colsSampled = (cx1 - cx0).clamp(1, width);
  final leftStrength = colEdgeEnergy[leftEdgeX] / (rowsSampled * 255.0);
  final rightStrength = colEdgeEnergy[rightEdgeX] / (rowsSampled * 255.0);
  final topStrength = rowEdgeEnergy[topEdgeY] / (colsSampled * 255.0);
  final bottomStrength = rowEdgeEnergy[bottomEdgeY] / (colsSampled * 255.0);
  final borderStrength =
      (leftStrength + rightStrength + topStrength + bottomStrength) / 4.0;

  final plausibleSizeStrong =
      cardW >= (roiW * 0.40) && cardH >= (roiH * 0.48) && cardH > cardW;
  final plausibleAspectStrong = aspect >= 0.50 && aspect <= 1.00;
  final hasCardBorderStrong =
      plausibleSizeStrong && plausibleAspectStrong && borderStrength >= 0.10;

  final plausibleSizeLoose =
      cardW >= (roiW * 0.30) && cardH >= (roiH * 0.38) && cardH > cardW;
  final plausibleAspectLoose = aspect >= 0.45 && aspect <= 1.10;
  final hasCardBorderLoose =
      plausibleSizeLoose && plausibleAspectLoose && borderStrength >= 0.07;

  // 3. Motion: mean absolute difference vs previous frame.
  //    Low motion means the card is held still — ready to scan.
  double motionMean = 0;
  if (prev != null && prev.length == current.length) {
    var motionSum = 0.0;
    for (var y = cy0; y < cy1; y++) {
      for (var x = cx0; x < cx1; x++) {
        motionSum += (current[y * width + x] - prev[y * width + x]).abs();
      }
    }
    motionMean = motionSum / count;
  }

  final textureStrong = variance > 280 && edgeDensity > 0.11;
  final textureModerate = variance > 180 && edgeDensity > 0.08;

  final jitterTolerantSteady = motionMean < 20 ||
      (motionMean < 28 && textureStrong && hasCardBorderStrong);

  // Card present: enough texture plus a card-like border profile, with
  // tolerance for natural hand tremor.
  if (!(jitterTolerantSteady &&
      ((textureStrong && hasCardBorderLoose) ||
          (textureModerate && hasCardBorderStrong)))) {
    return null;
  }

  return _CardBounds(
    // Normalised 0..1 within the luma frame (80×112)
    tlX: tlX / width, tlY: tlY / height,
    trX: trX / width, trY: trY / height,
    brX: brX / width, brY: brY / height,
    blX: blX / width, blY: blY / height,
    cameraWidth: cameraWidth,
    cameraHeight: cameraHeight,
  );
}

class _CardNameIndex {
  final MTGCard card;
  final String normalizedName;

  const _CardNameIndex({
    required this.card,
    required this.normalizedName,
  });
}

// ---------------------------------------------------------------------------
// Card outline overlay — drawn from detection edge data, smooth lerp at 60fps
// ---------------------------------------------------------------------------

/// Four-corner card bounds returned from the detection isolate.
/// Each coordinate is normalised 0..1 within the 80×112 luma thumbnail.
class _CardBounds {
  final double tlX, tlY; // top-left
  final double trX, trY; // top-right
  final double brX, brY; // bottom-right
  final double blX, blY; // bottom-left
  final double cameraWidth;
  final double cameraHeight;

  const _CardBounds({
    required this.tlX,
    required this.tlY,
    required this.trX,
    required this.trY,
    required this.brX,
    required this.brY,
    required this.blX,
    required this.blY,
    required this.cameraWidth,
    required this.cameraHeight,
  });

  /// Map a luma-normalised point to screen-space, accounting for the
  /// extraction ROI and BoxFit.cover aspect-ratio scaling.
  Offset _lumaToScreen(double lx, double ly, Size size) {
    // ROI constants (mirror _extractCenterLumaFromFrame)
    const roiL = 0.14;
    const roiT = 0.08;
    const roiW = 0.72;
    const roiH = 0.84;
    final camFracX = roiL + lx * roiW;
    final camFracY = roiT + ly * roiH;
    final scaleX = size.width / cameraWidth;
    final scaleY = size.height / cameraHeight;
    final scale = math.max(scaleX, scaleY);
    final dx = (size.width - cameraWidth * scale) / 2;
    final dy = (size.height - cameraHeight * scale) / 2;
    return Offset(
      camFracX * cameraWidth * scale + dx,
      camFracY * cameraHeight * scale + dy,
    );
  }

  /// Returns the four screen-space corners: TL, TR, BR, BL.
  List<Offset> toScreenCorners(Size size) => [
        _lumaToScreen(tlX, tlY, size),
        _lumaToScreen(trX, trY, size),
        _lumaToScreen(brX, brY, size),
        _lumaToScreen(blX, blY, size),
      ];
}

class _CardOutlineOverlay extends StatefulWidget {
  final ValueNotifier<_CardBounds?> boundsNotifier;

  const _CardOutlineOverlay({required this.boundsNotifier});

  @override
  State<_CardOutlineOverlay> createState() => _CardOutlineOverlayState();
}

class _CardOutlineOverlayState extends State<_CardOutlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final _CardBoundsPainter _painter;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), // only used as a vsync tick source
    );
    _painter = _CardBoundsPainter(
      repaint: _ticker,
      boundsNotifier: widget.boundsNotifier,
    );
    widget.boundsNotifier.addListener(_onBoundsChanged);
  }

  void _onBoundsChanged() {
    if (widget.boundsNotifier.value != null) {
      _stopTimer?.cancel();
      _stopTimer = null;
      if (!_ticker.isAnimating) _ticker.repeat();
    } else {
      // Let the painter fade out, then stop ticking
      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _ticker.stop();
      });
    }
  }

  @override
  void dispose() {
    widget.boundsNotifier.removeListener(_onBoundsChanged);
    _stopTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      size: Size.infinite,
    );
  }
}

class _CardBoundsPainter extends CustomPainter {
  final ValueNotifier<_CardBounds?> boundsNotifier;

  _CardBoundsPainter({
    required Listenable repaint,
    required this.boundsNotifier,
  }) : super(repaint: repaint);

  List<Offset>? _drawCorners;
  double _opacity = 0;

  static const double _lerpFactor = 0.12;
  static const double _fadeFactor = 0.10;
  static const double _cornerRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final target = boundsNotifier.value;
    final targetOpacity = target != null ? 1.0 : 0.0;
    _opacity = ui.lerpDouble(_opacity, targetOpacity, _fadeFactor)!;

    if (target != null) {
      final sc = target.toScreenCorners(size);
      final cur = _drawCorners;
      _drawCorners = cur == null
          ? sc
          : List.generate(4, (i) => Offset.lerp(cur[i], sc[i], _lerpFactor)!);
    } else if (_opacity < 0.01) {
      _drawCorners = null;
      return;
    }

    final corners = _drawCorners;
    if (corners == null) return;

    final path = _roundedQuadPath(corners, _cornerRadius);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.greenAccent.withOpacity(_opacity * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Builds a closed [Path] through [pts] with rounded corners via
  /// quadratic Bézier arcs, matching card-edge roundness.
  static Path _roundedQuadPath(List<Offset> pts, double radius) {
    final path = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n];
      final curr = pts[i];
      final next = pts[(i + 1) % n];
      final toPrev = prev - curr;
      final toNext = next - curr;
      final lenPrev = toPrev.distance;
      final lenNext = toNext.distance;
      if (lenPrev == 0 || lenNext == 0) continue;
      final r = math.min(radius, math.min(lenPrev, lenNext) * 0.45);
      final p1 = curr + toPrev / lenPrev * r;
      final p2 = curr + toNext / lenNext * r;
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_CardBoundsPainter old) => true;
}

class _NameMatchScore {
  final MTGCard card;
  final int score;
  final int margin;

  const _NameMatchScore({
    required this.card,
    required this.score,
    required this.margin,
  });
}

class _CardPickSetOption {
  final String code;
  final String name;
  final String? iconSvg;

  const _CardPickSetOption({
    required this.code,
    required this.name,
    this.iconSvg,
  });
}

class _SymbolCropSpec {
  final double centerX;
  final double centerY;
  final double sizeFactor;

  const _SymbolCropSpec({
    required this.centerX,
    required this.centerY,
    required this.sizeFactor,
  });
}

class _PrintingHints {
  final Set<String> setCodes;
  final Set<String> languages;
  final Set<String> collectorNumbers;
  final bool foilStarDetected;
  final Set<String> rawSetCodes;
  final Set<String> rawLanguages;
  final Set<String> rawCollectorNumbers;

  const _PrintingHints({
    this.setCodes = const <String>{},
    this.languages = const <String>{},
    this.collectorNumbers = const <String>{},
    this.foilStarDetected = false,
    this.rawSetCodes = const <String>{},
    this.rawLanguages = const <String>{},
    this.rawCollectorNumbers = const <String>{},
  });

  _PrintingHints copyWith({
    Set<String>? setCodes,
    Set<String>? languages,
    Set<String>? collectorNumbers,
    bool? foilStarDetected,
    Set<String>? rawSetCodes,
    Set<String>? rawLanguages,
    Set<String>? rawCollectorNumbers,
  }) {
    return _PrintingHints(
      setCodes: setCodes ?? this.setCodes,
      languages: languages ?? this.languages,
      collectorNumbers: collectorNumbers ?? this.collectorNumbers,
      foilStarDetected: foilStarDetected ?? this.foilStarDetected,
      rawSetCodes: rawSetCodes ?? this.rawSetCodes,
      rawLanguages: rawLanguages ?? this.rawLanguages,
      rawCollectorNumbers: rawCollectorNumbers ?? this.rawCollectorNumbers,
    );
  }

  bool get hasPrimaryHints =>
      setCodes.isNotEmpty ||
      languages.isNotEmpty ||
      collectorNumbers.isNotEmpty ||
      foilStarDetected;
}

class _DebugScanInfo {
  final String cardName;
  final String? resolvedSetCode;
  final Set<String> rawSetCodes;
  final Set<String> filteredSetCodes;
  final Set<String> rawLanguages;
  final Set<String> filteredLanguages;
  final Set<String> rawCollectorNumbers;
  final Set<String> filteredCollectorNumbers;
  final bool foilStarDetected;
  final String matchPath;

  const _DebugScanInfo({
    required this.cardName,
    this.resolvedSetCode,
    this.rawSetCodes = const {},
    this.filteredSetCodes = const {},
    this.rawLanguages = const {},
    this.filteredLanguages = const {},
    this.rawCollectorNumbers = const {},
    this.filteredCollectorNumbers = const {},
    this.foilStarDetected = false,
    required this.matchPath,
  });
}
