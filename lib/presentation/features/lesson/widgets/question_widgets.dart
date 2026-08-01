import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

Widget buildQuestionPreview(QuizQuestion q, BuildContext context) {
  final typeLabel = q.type.displayName;
  final icon = _typeIcon(q.type);
  final preview = q.questionText.length > 60
      ? '${q.questionText.substring(0, 60)}...'
      : q.questionText;
  return Row(
    children: [
      Icon(icon, size: context.scale(18), color: AppColors.primaryAdaptive(context)),
      SizedBox(width: context.scale(8)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: context.scale(6), vertical: context.scale(2)),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(typeLabel, style: TextStyle(fontSize: context.scaleFont(11), fontWeight: FontWeight.w600, color: AppColors.primaryAdaptive(context))),
      ),
      SizedBox(width: context.scale(8)),
      Expanded(child: Text(preview, style: TextStyle(fontSize: context.scaleFont(14)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      SizedBox(width: context.scale(8)),
      Text('${q.points}pt', style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
    ],
  );
}

IconData _typeIcon(QuestionType type) {
  switch (type) {
    case QuestionType.multipleChoice: return Icons.checklist;
    case QuestionType.trueFalse: return Icons.toggle_on;
    case QuestionType.identification: return Icons.short_text;
    case QuestionType.matchingType: return Icons.compare_arrows;
  }
}

class QuestionEditDialog extends StatefulWidget {
  final QuizQuestion? question;
  final String lessonId;
  final int order;

  const QuestionEditDialog({super.key, this.question, required this.lessonId, this.order = 0});

  @override
  State<QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<QuestionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late QuestionType _type;
  late TextEditingController _textCtrl;
  late TextEditingController _pointsCtrl;
  late TextEditingController _explainCtrl;
  late TextEditingController _answerCtrl;

  List<TextEditingController> _optionCtrls = [];
  List<ImageRef?> _optionImages = [];
  int? _correctIndex;
  bool? _correctBool;
  List<_PairData> _pairs = [];
  ImageRef? _questionImage;

  bool get _editing => widget.question != null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _type = q?.type ?? QuestionType.multipleChoice;
    _textCtrl = TextEditingController(text: q?.questionText ?? '');
    _pointsCtrl = TextEditingController(text: (q?.points ?? 1).toString());
    _explainCtrl = TextEditingController(text: q?.explanation ?? '');
    _answerCtrl = TextEditingController(text: q?.correctAnswer ?? '');
    _questionImage = q?.questionImage;

    if (q?.options != null) {
      _optionCtrls = q!.options!.map((o) => TextEditingController(text: o)).toList();
    }
    if (q?.optionImages != null) {
      _optionImages = List<ImageRef?>.of(q!.optionImages!);
    }
    while (_optionImages.length < _optionCtrls.length) {
      _optionImages.add(null);
    }
    _correctIndex = q?.correctIndex;
    _correctBool = q?.correctBool;

    if (q?.matchingPairs != null) {
      _pairs = q!.matchingPairs!.map((p) => _PairData(
        meaningCtrl: TextEditingController(text: p.meaning),
        image: p.image,
      )).toList();
    }

    if (_optionCtrls.isEmpty && _type == QuestionType.multipleChoice) {
      _addOption();
      _addOption();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _pointsCtrl.dispose();
    _explainCtrl.dispose();
    _answerCtrl.dispose();
    for (final c in _optionCtrls) { c.dispose(); }
    for (final p in _pairs) { p.meaningCtrl.dispose(); }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(TextEditingController());
      _optionImages.add(null);
    });
  }

  void _removeOption(int i) {
    if (_optionCtrls.length <= 2) return;
    _optionCtrls[i].dispose();
    setState(() {
      _optionCtrls.removeAt(i);
      _optionImages.removeAt(i);
      if (_correctIndex != null) {
        if (_correctIndex == i) {
          _correctIndex = null;
        } else if (_correctIndex! > i) {
          _correctIndex = _correctIndex! - 1;
        }
      }
    });
  }

  void _addPair() {
    setState(() => _pairs.add(_PairData(meaningCtrl: TextEditingController())));
  }

  void _removePair(int i) {
    _pairs[i].meaningCtrl.dispose();
    setState(() => _pairs.removeAt(i));
  }

  /// Picks an image and reads its bytes so the preview and upload work on web
  /// (where dart:io File operations are unavailable) and on native.
  Future<ImageRef?> _pickImageRef() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return null;
    Uint8List? bytes;
    try {
      bytes = await xFile.readAsBytes();
    } catch (e) {
      debugPrint('QuestionEditDialog: readAsBytes failed: $e');
    }
    return ImageRef(localPath: xFile.path, xFile: xFile, localBytes: bytes);
  }

  Future<void> _pickImage(int pairIndex) async {
    final image = await _pickImageRef();
    if (image != null) {
      setState(() => _pairs[pairIndex].image = image);
    }
  }

  Future<void> _pickQuestionImage() async {
    final image = await _pickImageRef();
    if (image != null) {
      setState(() => _questionImage = image);
    }
  }

  Future<void> _pickOptionImage(int index) async {
    final image = await _pickImageRef();
    if (image != null) {
      setState(() => _optionImages[index] = image);
    }
  }

  QuizQuestion _buildQuestion() {
    return QuizQuestion(
      id: widget.question?.id,
      lessonId: widget.lessonId,
      type: _type,
      questionText: _textCtrl.text.trim(),
      questionImage: _questionImage,
      options: _type == QuestionType.multipleChoice ? _optionCtrls.map((c) => c.text).toList() : null,
      optionImages: _type == QuestionType.multipleChoice ? _optionImages : null,
      correctIndex: _type == QuestionType.multipleChoice ? _correctIndex : null,
      correctBool: _type == QuestionType.trueFalse ? _correctBool : null,
      correctAnswer: _type == QuestionType.identification ? _answerCtrl.text.trim() : null,
      matchingPairs: _type == QuestionType.matchingType
          ? _pairs.map((p) => MatchingPair(
              image: p.image ?? const ImageRef(),
              meaning: p.meaningCtrl.text.trim(),
            )).toList()
          : null,
      points: int.tryParse(_pointsCtrl.text) ?? 1,
      explanation: _explainCtrl.text.trim(),
      order: widget.order,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(context.scale(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: context.scale(700)),
        child: Padding(
          padding: EdgeInsets.all(context.scale(20)),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_editing ? 'Edit Question' : 'New Question', style: TextStyle(fontSize: context.scaleFont(18), fontWeight: FontWeight.bold)),
                  SizedBox(height: context.scale(12)),
                  DropdownButtonFormField<QuestionType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Question Type', border: OutlineInputBorder()),
                    items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
                        if (v == QuestionType.multipleChoice && _optionCtrls.isEmpty) {
                          _addOption(); _addOption();
                        }
                      });
                    },
                  ),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _textCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      hintText: 'Type the question here',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Question text is required'
                        : null,
                  ),
                  SizedBox(height: context.scale(12)),
                  if (_type != QuestionType.matchingType) _buildQuestionImagePicker(context),
                  if (_type == QuestionType.multipleChoice) _buildOptionsEditor(context),
                  if (_type == QuestionType.trueFalse) _buildTrueFalseEditor(context),
                  if (_type == QuestionType.identification) _buildIdentificationEditor(context),
                  if (_type == QuestionType.matchingType) _buildMatchingEditor(context),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points (XP)',
                      hintText: '1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val < 1) return 'At least 1';
                      return null;
                    },
                  ),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _explainCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Explanation (optional)',
                      hintText: 'Shown after the user answers',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  SizedBox(height: context.scale(20)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      SizedBox(width: context.scale(12)),
                      ElevatedButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          final q = _buildQuestion();
                          final result = q.validate();
                          if (!result.isValid) {
                            SnackbarUtils.showError(context, result.message ?? 'Invalid');
                            return;
                          }
                          Navigator.pop(context, q);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionImagePicker(BuildContext context) {
    final hasImage = _questionImage != null;
    return Row(
      children: [
        _ImagePickerTile(
          image: _questionImage,
          size: context.scale(72),
          label: 'question image',
          onTap: _pickQuestionImage,
        ),
        SizedBox(width: context.scale(12)),
        Expanded(
          child: Text(
            hasImage ? 'Image selected' : 'Add a question image (optional)',
            style: TextStyle(fontSize: context.scaleFont(13), color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        if (hasImage)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Remove image',
            onPressed: () => setState(() => _questionImage = null),
          ),
      ],
    );
  }

  Widget _buildOptionsEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(14))),
        SizedBox(height: context.scale(4)),
        Text(
          'Select the correct answer',
          style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: context.scale(8)),
        ...List.generate(_optionCtrls.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: context.scale(8)),
            child: Row(
              children: [
                // ignore: deprecated_member_use
                Radio<int?>(value: i, groupValue: _correctIndex, onChanged: (v) => setState(() => _correctIndex = v)),
                _ImagePickerTile(
                  image: _optionImages[i],
                  size: context.scale(48),
                  label: 'image for option ${String.fromCharCode(65 + i)}',
                  onTap: () => _pickOptionImage(i),
                ),
                SizedBox(width: context.scale(8)),
                Expanded(
                  child: TextFormField(
                    controller: _optionCtrls[i],
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Option ${String.fromCharCode(65 + i)}',
                      border: const OutlineInputBorder(),
                      suffixIcon: _optionCtrls.length > 2
                          ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeOption(i))
                          : null,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) && _optionImages[i] == null
                            ? 'Text or image required'
                            : null,
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Option'),
          onPressed: _addOption,
        ),
      ],
    );
  }

  Widget _buildTrueFalseEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Correct Answer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(14))),
        SizedBox(height: context.scale(8)),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('True')),
            ButtonSegment(value: false, label: Text('False')),
          ],
          selected: {?_correctBool},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) =>
              setState(() => _correctBool = s.isEmpty ? null : s.first),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentificationEditor(BuildContext context) {
    return TextFormField(
      controller: _answerCtrl,
      textCapitalization: TextCapitalization.none,
      decoration: const InputDecoration(
        labelText: 'Answer',
        hintText: 'e.g., Yield Sign',
        helperText: 'Separate multiple accepted answers with commas',
        border: OutlineInputBorder(),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Answer is required'
          : null,
    );
  }

  Widget _buildMatchingEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Matching Pairs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(14))),
        SizedBox(height: context.scale(4)),
        Text(
          'Users match each image to its meaning',
          style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: context.scale(8)),
        ...List.generate(_pairs.length, (i) {
          return Card(
            margin: EdgeInsets.only(bottom: context.scale(8)),
            child: Padding(
              padding: EdgeInsets.all(context.scale(8)),
              child: Row(
                children: [
                  _ImagePickerTile(
                    image: _pairs[i].image,
                    size: context.scale(60),
                    label: 'matching image',
                    onTap: () => _pickImage(i),
                  ),
                  SizedBox(width: context.scale(8)),
                  Expanded(
                    child: TextFormField(
                      controller: _pairs[i].meaningCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Meaning',
                        hintText: 'What does this sign mean?',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Meaning required'
                          : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: _pairs.length > 2 ? () => _removePair(i) : null,
                  ),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Pair'),
          onPressed: _addPair,
        ),
      ],
    );
  }
}

class _PairData {
  final TextEditingController meaningCtrl;
  ImageRef? image;
  _PairData({required this.meaningCtrl, this.image});
}

class _ImagePickerTile extends StatelessWidget {
  final ImageRef? image;
  final double size;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.image,
    required this.size,
    required this.label,
    required this.onTap,
  });

  ImageProvider? _resolveProvider() {
    final img = image;
    if (img == null) return null;
    if (img.hasRemote) return NetworkImage(img.remoteUrl!);
    if (img.localBytes != null) return MemoryImage(img.localBytes!);
    if (!kIsWeb && (img.localPath?.isNotEmpty ?? false)) {
      return FileImage(File(img.localPath!));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _resolveProvider();
    return Semantics(
      button: true,
      label: provider != null ? '$label selected' : 'Add $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            image: provider != null
                ? DecorationImage(image: provider, fit: BoxFit.cover)
                : null,
          ),
          child: provider == null
              ? Icon(
                  Icons.add_photo_alternate,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: size * 0.4,
                )
              : null,
        ),
      ),
    );
  }
}
