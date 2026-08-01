import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';


class QuestionDisplayWidget extends StatefulWidget {
  final QuizQuestion question;
  final dynamic currentAnswer;
  final ValueChanged<dynamic> onAnswerChanged;

  const QuestionDisplayWidget({
    super.key,
    required this.question,
    this.currentAnswer,
    required this.onAnswerChanged,
  });

  @override
  State<QuestionDisplayWidget> createState() => _QuestionDisplayWidgetState();
}

class _QuestionDisplayWidgetState extends State<QuestionDisplayWidget> {
  dynamic _answer;

  @override
  void initState() {
    super.initState();
    _answer = widget.currentAnswer;
  }

  @override
  void didUpdateWidget(QuestionDisplayWidget old) {
    super.didUpdateWidget(old);
    if (widget.question.id != old.question.id) {
      _answer = widget.currentAnswer;
    }
  }

  void _updateAnswer(dynamic val) {
    setState(() => _answer = val);
    widget.onAnswerChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.scale(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.questionImage?.hasRemote ?? false)
            Padding(
              padding: EdgeInsets.only(bottom: context.scale(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: q.questionImage!.remoteUrl!,
                  height: context.scale(180),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Container(
                    height: context.scale(120),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Center(child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              ),
            ),
          Text(
            q.questionText,
            style: TextStyle(fontSize: context.scaleFont(17), fontWeight: FontWeight.w600, height: 1.4),
          ),
          SizedBox(height: context.scale(16)),
          _buildAnswerArea(context),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(BuildContext context) {
    switch (widget.question.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoice(context);
      case QuestionType.trueFalse:
        return _buildTrueFalse(context);
      case QuestionType.identification:
        return _buildIdentification(context);
      case QuestionType.matchingType:
        return _buildMatchingType(context);
    }
  }

  Widget _buildMultipleChoice(BuildContext context) {
    final q = widget.question;
    final opts = q.options ?? [];
    return Column(
      children: List.generate(opts.length, (i) {
        final isSelected = _answer == i;
        return Padding(
          padding: EdgeInsets.only(bottom: context.scale(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _updateAnswer(i),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.scale(14)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Theme.of(context).cardColor,
              ),
              child: Row(
                children: [
                  // ignore: deprecated_member_use
                  Radio<int?>(value: i, groupValue: _answer, onChanged: (v) => _updateAnswer(v)),
                  SizedBox(width: context.scale(8)),
                  if (q.optionImages != null && i < q.optionImages!.length && q.optionImages![i]?.hasRemote == true)
                    Padding(
                      padding: EdgeInsets.only(right: context.scale(8)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: q.optionImages![i]!.remoteUrl!,
                          width: context.scale(48),
                          height: context.scale(48),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      opts[i],
                      style: TextStyle(fontSize: context.scaleFont(15)),
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: context.scale(20)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTrueFalse(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _tfButton(context, true, 'True', Icons.check_circle_outline),
        ),
        SizedBox(width: context.scale(16)),
        Expanded(
          child: _tfButton(context, false, 'False', Icons.cancel_outlined),
        ),
      ],
    );
  }

  Widget _tfButton(BuildContext context, bool value, String label, IconData icon) {
    final isSelected = _answer == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _updateAnswer(value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.scale(24)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (value ? Colors.green : Colors.red)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          color: isSelected
              ? (value ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08))
              : Theme.of(context).cardColor,
        ),
        child: Column(
          children: [
            Icon(icon, size: context.scale(36), color: isSelected ? (value ? Colors.green : Colors.red) : Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: context.scale(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.scaleFont(16),
                fontWeight: FontWeight.w600,
                color: isSelected ? (value ? Colors.green : Colors.red) : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentification(BuildContext context) {
    return TextField(
      controller: _answer is TextEditingController ? _answer : null,
      onChanged: (v) => _updateAnswer(v),
      decoration: InputDecoration(
        hintText: 'Type your answer...',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      maxLines: 3,
      autofocus: true,
    );
  }

  Widget _buildMatchingType(BuildContext context) {
    final q = widget.question;
    final pairs = q.matchingPairs ?? [];
    if (pairs.isEmpty) return const SizedBox.shrink();

    final userMap = _answer is Map ? Map<String, String>.from(_answer as Map) : <String, String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tap an image, then tap its meaning:', style: TextStyle(fontSize: context.scaleFont(14), color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: context.scale(12)),
        ...List.generate(pairs.length, (i) {
          final pair = pairs[i];
          final matchedMeaning = userMap[pair.id];
          final isMatched = matchedMeaning != null;


          return Padding(
            padding: EdgeInsets.only(bottom: context.scale(10)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _handleMatchingTap(userMap, pair.id, null, pairs),
                  child: Container(
                    width: context.scale(80),
                    height: context.scale(80),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMatched ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                        width: isMatched ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: pair.image.hasRemote
                          ? CachedNetworkImage(
                              imageUrl: pair.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _imagePlaceholder(context),
                            )
                          : _imagePlaceholder(context),
                    ),
                  ),
                ),
                SizedBox(width: context.scale(8)),
                Expanded(child: _buildMeaningDropdown(context, pair.id, userMap, pairs)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Center(child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSurfaceVariant, size: context.scale(28))));
  }

  Widget _buildMeaningDropdown(BuildContext context, String pairId, Map<String, String> userMap, List<MatchingPair> allPairs) {
    final matchedMeaning = userMap[pairId];
    final allMeanings = allPairs.map((p) => p.meaning).toList()..shuffle();

    return DropdownButtonFormField<String>(
      initialValue: matchedMeaning,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: context.scale(12), vertical: context.scale(12)),
        hintText: 'Select meaning...',
        isDense: true,
      ),
      isExpanded: true,
      items: [
        DropdownMenuItem(value: null, child: Text('—', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ...allMeanings.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => _handleMatchingTap(userMap, pairId, v, allPairs),
    );
  }

  void _handleMatchingTap(Map<String, String> userMap, String pairId, String? meaning, List<MatchingPair> allPairs) {
    final updated = Map<String, String>.from(userMap);

    if (meaning == null) {
      if (updated.containsKey(pairId)) {
        final removed = updated.remove(pairId);
        if (removed != null) {
          _releaseMeaning(updated, removed);
        }
      } else {
        return;
      }
    } else {
      _releaseMeaning(updated, meaning);
      updated[pairId] = meaning;
    }

    _updateAnswer(updated);
  }

  void _releaseMeaning(Map<String, String> map, String meaning) {
    final toRemove = map.entries.where((e) => e.value == meaning).map((e) => e.key).toList();
    for (final k in toRemove) {
      map.remove(k);
    }
  }
}
