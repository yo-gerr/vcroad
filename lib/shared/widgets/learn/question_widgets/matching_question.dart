import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

class MatchingQuestion extends StatefulWidget {
  final QuizQuestion question;

  const MatchingQuestion({super.key, required this.question});

  @override
  State<MatchingQuestion> createState() => _MatchingQuestionState();
}

class _MatchingQuestionState extends State<MatchingQuestion> {
  final Map<String, String> _matches = {}; // imageId -> meaningId
  final Map<String, bool> _pairResults = {}; // imageId -> correct?
  bool _isAnswered = false;
  bool? _isCorrect;
  List<MatchingPair> _shuffledMeanings = [];
  bool _isProcessing = false;
  String? _selectedImageId;

  // palette of friendly colors for pairing (keeps memory and CPU cheap)
  static const List<Color> _palette = [
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFFFF9800), // orange
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // teal
    Color(0xFFFF5722), // deep orange
    Color(0xFF3F51B5), // indigo
  ];

  @override
  void initState() {
    super.initState();
    _shuffledMeanings = List.from(widget.question.matchingPairs ?? [])
      ..shuffle(Random());
  }

  Future<void> _submitAnswer() async {
    final provider = context.read<LearningProvider>();
    if (provider.isTimeExpired) return;
    if (_matches.length != widget.question.matchingPairs!.length) return;
    final isCorrect = await provider.submitAnswer(
      Map<String, String>.from(_matches),
    );

    // compute per-pair correctness locally (cheap O(n) pass)
    final results = <String, bool>{};
    final pairs = widget.question.matchingPairs ?? [];
    for (final pair in pairs) {
      final matchedMeaningId = _matches[pair.id];
      results[pair.id] =
          matchedMeaningId != null && matchedMeaningId == pair.id;
    }

    if (!mounted) return;
    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
      _pairResults
        ..clear()
        ..addAll(results);
    });
  }

  Future<void> _nextQuestion() async {
    final provider = context.read<LearningProvider>();

    if (provider.currentQuestionIndex <
        provider.currentLesson!.questions.length - 1) {
      provider.nextQuestion();
      if (!mounted) return;
      setState(() {
        _matches.clear();
        _pairResults.clear();
        _isAnswered = false;
        _isCorrect = null;
        _shuffledMeanings = List.from(widget.question.matchingPairs ?? [])
          ..shuffle(Random());
        _selectedImageId = null;
      });
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await provider.completeLesson();
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  // Build a fast lookup of pair id -> index for deterministic colors
  Map<String, int> _buildIdIndexMap(List<MatchingPair> pairs) {
    final map = <String, int>{};
    for (var i = 0; i < pairs.length; i++) {
      map[pairs[i].id] = i;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final pairs = widget.question.matchingPairs ?? [];
    final idIndex = _buildIdIndexMap(pairs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Card
        Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(info.scale(16)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(info.scale(8)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF001278).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.connect_without_contact,
                    color: const Color(0xFF001278),
                    size: info.scale(20),
                  ),
                ),
                SizedBox(width: info.scale(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matching Type',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Match each image with its correct meaning',
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: info.scale(8),
                    vertical: info.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pointsLabel(widget.question.points),
                    style: TextStyle(
                      fontSize: info.scaleFont(11),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: info.scale(16)),

        // Instructions
        Container(
          padding: EdgeInsets.all(info.scale(12)),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: info.scale(18),
              ),
              SizedBox(width: info.scale(8)),
              Expanded(
                child: Text(
                  'Tap an image, then tap its matching meaning',
                  style: TextStyle(
                    fontSize: info.scaleFont(12),
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: info.scale(16)),

        // Matching Interface
        if (info.isMobile)
          _MobileMatchingLayout(
            pairs: pairs,
            shuffledMeanings: _shuffledMeanings,
            matches: _matches,
            idIndex: idIndex,
            pairResults: _pairResults,
            isAnswered: _isAnswered,
            isProcessing: _isProcessing,
            selectedImageId: _selectedImageId,
            onSelectImage: (id) {
              if (!_isAnswered && !_isProcessing) {
                setState(() {
                  _selectedImageId = _selectedImageId == id ? null : id;
                });
              }
            },
            onMatchChanged: (imageId, meaningId) {
              if (!_isAnswered && !_isProcessing) {
                setState(() {
                  if (_matches[imageId] == meaningId) {
                    _matches.remove(imageId);
                  } else {
                    // ensure meaning is not already assigned; if so, remove previous
                    final prevImage = _matches.entries
                        .firstWhere(
                          (e) => e.value == meaningId,
                          orElse: () => const MapEntry('', ''),
                        )
                        .key;
                    if (prevImage.isNotEmpty) _matches.remove(prevImage);
                    _matches[imageId] = meaningId;
                  }
                  _selectedImageId = null;
                });
              }
            },
          )
        else
          _DesktopMatchingLayout(
            pairs: pairs,
            shuffledMeanings: _shuffledMeanings,
            matches: _matches,
            idIndex: idIndex,
            pairResults: _pairResults,
            isAnswered: _isAnswered,
            isProcessing: _isProcessing,
            selectedImageId: _selectedImageId,
            onSelectImage: (id) {
              if (!_isAnswered && !_isProcessing) {
                setState(() {
                  _selectedImageId = _selectedImageId == id ? null : id;
                });
              }
            },
            onMatchChanged: (imageId, meaningId) {
              if (!_isAnswered && !_isProcessing) {
                setState(() {
                  if (_matches[imageId] == meaningId) {
                    _matches.remove(imageId);
                  } else {
                    final prevImage = _matches.entries
                        .firstWhere(
                          (e) => e.value == meaningId,
                          orElse: () => const MapEntry('', ''),
                        )
                        .key;
                    if (prevImage.isNotEmpty) _matches.remove(prevImage);
                    _matches[imageId] = meaningId;
                  }
                  _selectedImageId = null;
                });
              }
            },
          ),

        if (_isAnswered) ...[
          SizedBox(height: info.scale(16)),
          Container(
            padding: EdgeInsets.all(info.scale(16)),
            decoration: BoxDecoration(
              color: (_isCorrect! ? Colors.green : Colors.red).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCorrect! ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: _isCorrect! ? Colors.green : Colors.red,
                  size: info.scale(32),
                ),
                SizedBox(width: info.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCorrect! ? 'Perfect Match!' : 'Not quite right',
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          fontWeight: FontWeight.bold,
                          color: _isCorrect! ? Colors.green : Colors.red,
                        ),
                      ),
                      if (widget.question.explanation != null) ...[
                        SizedBox(height: info.scale(4)),
                        Text(
                          widget.question.explanation!,
                          style: TextStyle(
                            fontSize: info.scaleFont(13),
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: info.scale(24)),

        SizedBox(
          width: double.infinity,
          child: _isProcessing
              ? SizedBox(
                  height: info.scale(56),
                  child: const Center(child: CircularProgressIndicator()),
                )
              : ElevatedButton(
                  onPressed: _isAnswered
                      ? _nextQuestion
                      : ((_matches.length == pairs.length &&
                                !context.read<LearningProvider>().isTimeExpired)
                            ? _submitAnswer
                            : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001278),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: info.scale(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isAnswered
                        ? 'Continue'
                        : 'Submit (${_matches.length}/${pairs.length})',
                    style: TextStyle(
                      fontSize: info.scaleFont(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// Mobile/Layout implementations with coloring & correctness support
class _MobileMatchingLayout extends StatelessWidget {
  final List<MatchingPair> pairs;
  final List<MatchingPair> shuffledMeanings;
  final Map<String, String> matches;
  final Map<String, int> idIndex;
  final Map<String, bool> pairResults;
  final bool isAnswered;
  final bool isProcessing;
  final String? selectedImageId;
  final ValueChanged<String?> onSelectImage;
  final void Function(String, String) onMatchChanged;

  const _MobileMatchingLayout({
    required this.pairs,
    required this.shuffledMeanings,
    required this.matches,
    required this.idIndex,
    required this.pairResults,
    required this.isAnswered,
    required this.isProcessing,
    required this.selectedImageId,
    required this.onSelectImage,
    required this.onMatchChanged,
  });

  Color? _pairColor(String imageId) {
    final idx = idIndex[imageId];
    if (idx == null) return null;
    return _MatchingQuestionState._palette[idx %
        _MatchingQuestionState._palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    // helper to safely find meaning text by id without creating a dummy MatchingPair
    String meaningFor(String? id) {
      if (id == null || id.isEmpty) return '';
      try {
        return shuffledMeanings.firstWhere((m) => m.id == id).meaning;
      } catch (_) {
        return '';
      }
    }

    return Column(
      children: [
        ...pairs.map((pair) {
          final isSelected = selectedImageId == pair.id;
          final matchedMeaningId = matches[pair.id];
          final isMatched = matchedMeaningId != null;
          final color = isMatched ? _pairColor(pair.id) : null;
          final correct = pairResults[pair.id]; // may be null pre-submit
          final isCorrect = correct == true;
          final isWrong = correct == false;

          // visual priority: correctness (green/red) overrides palette; else palette when matched; else default
          Color borderColor;
          Color? bgColor;
          if (isCorrect) {
            borderColor = Colors.green;
            bgColor = Colors.green.withValues(alpha: 0.08);
          } else if (isWrong) {
            borderColor = Colors.red;
            bgColor = Colors.red.withValues(alpha: 0.06);
          } else if (color != null) {
            borderColor = color;
            bgColor = color.withValues(alpha: 0.08);
          } else if (isSelected) {
            borderColor = const Color(0xFF001278);
            bgColor = null;
          } else {
            borderColor = Colors.grey[300]!;
            bgColor = null;
          }

          return Padding(
            padding: EdgeInsets.only(bottom: info.scale(12)),
            child: Card(
              elevation: isSelected ? 4 : 1,
              color: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 2),
              ),
              child: InkWell(
                onTap: isAnswered || isProcessing
                    ? null
                    : () => onSelectImage(isSelected ? null : pair.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(info.scale(12)),
                  child: Column(
                    children: [
                      // row with optional colored indicator and image
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // colored indicator (use palette color only, not correctness color)
                          Container(
                            width: info.scale(6),
                            height: info.scale(80),
                            decoration: BoxDecoration(
                              color: (isMatched && !_isNullOrFalse(correct))
                                  ? _pairColor(pair.id)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: info.scale(8)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: pair.image.remoteUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: pair.image.remoteUrl!,
                                      height: info.scale(150),
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      placeholder: (ctx, url) => SizedBox(
                                        height: info.scale(150),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (ctx, url, err) => SizedBox(
                                        height: info.scale(150),
                                        child: const Center(
                                          child: Icon(Icons.broken_image),
                                        ),
                                      ),
                                    )
                                  : pair.image.hasLocal
                                  ? Image(
                                      image: ResizeImage(
                                        FileImage(File(pair.image.localPath!)),
                                        width: info.isMobile ? 800 : 1200,
                                      ),
                                      height: info.scale(150),
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    )
                                  : Container(
                                      height: info.scale(150),
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.image),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      if (isMatched) ...[
                        SizedBox(height: info.scale(12)),
                        Row(
                          children: [
                            // correctness badge: check or close if submitted, else link icon with palette color
                            Container(
                              padding: EdgeInsets.all(info.scale(8)),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green
                                    : isWrong
                                    ? Colors.red
                                    : (color ?? Colors.grey[300]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCorrect
                                    ? Icons.check
                                    : isWrong
                                    ? Icons.close
                                    : Icons.link,
                                color: Colors.white,
                                size: info.scale(16),
                              ),
                            ),
                            SizedBox(width: info.scale(8)),
                            Expanded(
                              child: Text(
                                meaningFor(matchedMeaningId),
                                style: TextStyle(
                                  fontSize: info.scaleFont(13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isAnswered)
                              TextButton(
                                onPressed: isProcessing
                                    ? null
                                    : () {
                                        // unmatch on button press
                                        onMatchChanged(
                                          pair.id,
                                          matchedMeaningId,
                                        );
                                      },
                                child: const Text('Unmatch'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        if (selectedImageId != null && !isAnswered && !isProcessing) ...[
          SizedBox(height: info.scale(8)),
          Container(
            padding: EdgeInsets.all(info.scale(12)),
            decoration: BoxDecoration(
              color: const Color(0xFF001278).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Select a meaning below',
              style: TextStyle(
                fontSize: info.scaleFont(12),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF001278),
              ),
            ),
          ),
          SizedBox(height: info.scale(12)),

          ...shuffledMeanings.map((meaning) {
            final isUsed = matches.containsValue(meaning.id);
            final isSelectedForImage = matches[selectedImageId] == meaning.id;
            final color = selectedImageId != null
                ? _pairColor(selectedImageId!)
                : null;

            return Padding(
              padding: EdgeInsets.only(bottom: info.scale(8)),
              child: Card(
                color: isSelectedForImage
                    ? (color?.withValues(alpha: 0.12) ?? Colors.grey[100])
                    : null,
                child: InkWell(
                  onTap: isUsed && !isSelectedForImage
                      ? null
                      : () => onMatchChanged(selectedImageId!, meaning.id),
                  child: Padding(
                    padding: EdgeInsets.all(info.scale(12)),
                    child: Row(
                      children: [
                        Icon(
                          isSelectedForImage
                              ? Icons.check_circle
                              : isUsed
                              ? Icons.block
                              : Icons.circle_outlined,
                          color: isSelectedForImage
                              ? (color ?? const Color(0xFF001278))
                              : Colors.grey[400],
                          size: info.scale(20),
                        ),
                        SizedBox(width: info.scale(12)),
                        Expanded(
                          child: Text(
                            meaning.meaning,
                            style: TextStyle(
                              fontSize: info.scaleFont(13),
                              color: isUsed && !isSelectedForImage
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // used only for indicator decision
  bool _isNullOrFalse(bool? v) => v == null || v == false;
}

class _DesktopMatchingLayout extends StatelessWidget {
  final List<MatchingPair> pairs;
  final List<MatchingPair> shuffledMeanings;
  final Map<String, String> matches;
  final Map<String, int> idIndex;
  final Map<String, bool> pairResults;
  final bool isAnswered;
  final bool isProcessing;
  final String? selectedImageId;
  final ValueChanged<String?> onSelectImage;
  final void Function(String, String) onMatchChanged;

  const _DesktopMatchingLayout({
    required this.pairs,
    required this.shuffledMeanings,
    required this.matches,
    required this.idIndex,
    required this.pairResults,
    required this.isAnswered,
    required this.isProcessing,
    required this.selectedImageId,
    required this.onSelectImage,
    required this.onMatchChanged,
  });

  Color? _pairColor(String imageId) {
    final idx = idIndex[imageId];
    if (idx == null) return null;
    return _MatchingQuestionState._palette[idx %
        _MatchingQuestionState._palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: pairs.map((pair) {
              final isSelected = selectedImageId == pair.id;
              final matchedMeaningId = matches[pair.id];
              final isMatched = matchedMeaningId != null;
              final color = isMatched ? _pairColor(pair.id) : null;
              final correct = pairResults[pair.id];
              final isCorrect = correct == true;
              final isWrong = correct == false;

              Color borderColor;
              Color? bgColor;
              if (isCorrect) {
                borderColor = Colors.green;
                bgColor = Colors.green.withValues(alpha: 0.08);
              } else if (isWrong) {
                borderColor = Colors.red;
                bgColor = Colors.red.withValues(alpha: 0.06);
              } else if (color != null) {
                borderColor = color;
                bgColor = color.withValues(alpha: 0.08);
              } else if (isSelected) {
                borderColor = const Color(0xFF001278);
                bgColor = null;
              } else {
                borderColor = Colors.grey[300]!;
                bgColor = null;
              }

              return Padding(
                padding: EdgeInsets.only(bottom: info.scale(12)),
                child: Card(
                  elevation: isSelected ? 4 : 1,
                  color: bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 2),
                  ),
                  child: InkWell(
                    onTap: isAnswered || isProcessing
                        ? null
                        : () => onSelectImage(isSelected ? null : pair.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: pair.image.remoteUrl != null
                            ? CachedNetworkImage(
                                imageUrl: pair.image.remoteUrl!,
                                height: info.scale(120),
                                width: double.infinity,
                                fit: BoxFit.contain,
                                placeholder: (ctx, url) => SizedBox(
                                  height: info.scale(120),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (ctx, url, err) => SizedBox(
                                  height: info.scale(120),
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                              )
                            : pair.image.hasLocal
                            ? Image(
                                image: ResizeImage(
                                  FileImage(File(pair.image.localPath!)),
                                  width: info.isMobile ? 800 : 1200,
                                ),
                                height: info.scale(120),
                                width: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : Container(
                                height: info.scale(120),
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.image)),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(width: info.scale(16)),
        Expanded(
          child: Column(
            children: shuffledMeanings.map((meaning) {
              final isUsed = matches.containsValue(meaning.id);
              final imageId = matches.entries
                  .firstWhere(
                    (e) => e.value == meaning.id,
                    orElse: () => const MapEntry('', ''),
                  )
                  .key;
              final color = imageId.isNotEmpty ? _pairColor(imageId) : null;
              final correct = imageId.isNotEmpty ? pairResults[imageId] : null;
              final isCorrect = correct == true;
              final isWrong = correct == false;

              Color borderColor;
              Color? bgColor;
              if (isCorrect) {
                borderColor = Colors.green;
                bgColor = Colors.green.withValues(alpha: 0.08);
              } else if (isWrong) {
                borderColor = Colors.red;
                bgColor = Colors.red.withValues(alpha: 0.06);
              } else if (color != null) {
                borderColor = color;
                bgColor = color.withValues(alpha: 0.08);
              } else if (isUsed) {
                borderColor = Colors.blue;
                bgColor = Colors.blue.withValues(alpha: 0.03);
              } else {
                borderColor = Colors.grey[300]!;
                bgColor = null;
              }

              return Padding(
                padding: EdgeInsets.only(bottom: info.scale(12)),
                child: Card(
                  elevation: 1,
                  color: bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 2),
                  ),
                  child: InkWell(
                    onTap: isAnswered || isProcessing || selectedImageId == null
                        ? null
                        : () => onMatchChanged(selectedImageId!, meaning.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(16)),
                      child: Row(
                        children: [
                          Icon(
                            isUsed
                                ? (isCorrect
                                      ? Icons.check_circle
                                      : (isWrong ? Icons.cancel : Icons.link))
                                : Icons.circle_outlined,
                            color: isCorrect
                                ? Colors.green
                                : isWrong
                                ? Colors.red
                                : (color ??
                                      (isUsed
                                          ? Colors.blue
                                          : Colors.grey[400])),
                            size: info.scale(20),
                          ),
                          SizedBox(width: info.scale(12)),
                          Expanded(
                            child: Text(
                              meaning.meaning,
                              style: TextStyle(
                                fontSize: info.scaleFont(14),
                                fontWeight: isUsed
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (imageId.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: info.scale(8),
                                vertical: info.scale(6),
                              ),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green
                                    : (isWrong
                                          ? Colors.red
                                          : (color ?? Colors.grey[300])),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCorrect
                                        ? Icons.check
                                        : (isWrong ? Icons.close : Icons.link),
                                    color: Colors.white,
                                    size: info.scale(12),
                                  ),
                                  SizedBox(width: info.scale(6)),
                                  Text(
                                    isCorrect
                                        ? 'Correct'
                                        : (isWrong ? 'Wrong' : 'Matched'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: info.scaleFont(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
