import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/input/input_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_validation.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';

class MultipleChoiceEditor extends StatefulWidget {
  final QuizQuestion? question;
  final ValueChanged<QuizQuestion> onQuestionChanged;

  const MultipleChoiceEditor({
    super.key,
    this.question,
    required this.onQuestionChanged,
  });

  @override
  State<MultipleChoiceEditor> createState() => _MultipleChoiceEditorState();
}

class _MultipleChoiceEditorState extends State<MultipleChoiceEditor> {
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [];

  ImageRef? _questionImage;
  List<ImageRef?> _optionImages = [];
  int? _correctIndex;
  final ImagePicker _picker = ImagePicker();
  static const int _localDecodeWidth = 1200;

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _questionCtrl.text = widget.question!.question;
      _pointsCtrl.text = widget.question!.points.toString();
      _explanationCtrl.text = widget.question!.explanation ?? '';
      _questionImage = widget.question!.questionImage;
      _correctIndex = widget.question!.correctIndex;

      final options = widget.question!.options ?? ['', '', '', ''];
      for (int i = 0; i < options.length; i++) {
        _optionCtrls.add(TextEditingController(text: options[i]));
      }

      _optionImages = List.from(widget.question!.optionImages ?? []);
      while (_optionImages.length < _optionCtrls.length) {
        _optionImages.add(null);
      }
    } else {
      _pointsCtrl.text = '1';
      for (int i = 0; i < 4; i++) {
        _optionCtrls.add(TextEditingController());
        _optionImages.add(null);
      }
    }

    _updateQuestion();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _pointsCtrl.dispose();
    _explanationCtrl.dispose();
    for (var ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _updateQuestion() {
    final question = QuizQuestion(
      id: widget.question?.id,
      type: QuestionType.multipleChoice,
      question: _questionCtrl.text,
      questionImage: _questionImage,
      options: _optionCtrls.map((c) => c.text).toList(),
      optionImages: _optionImages,
      correctIndex: _correctIndex,
      points: int.tryParse(_pointsCtrl.text) ?? 1,
      explanation: _explanationCtrl.text.isEmpty ? null : _explanationCtrl.text,
    );
    widget.onQuestionChanged(question);
  }

  Future<void> _pickQuestionImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _questionImage = ImageRef(localPath: image.path, xFile: image);
      });
      _updateQuestion();
    }
  }

  void _removeQuestionImage() {
    setState(() => _questionImage = null);
    _updateQuestion();
  }

  Future<void> _pickOptionImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _optionImages[index] = ImageRef(localPath: image.path, xFile: image);
      });
      _updateQuestion();
    }
  }

  void _removeOptionImage(int index) {
    if (index < 0 || index >= _optionImages.length) return;
    setState(() => _optionImages[index] = null);
    _updateQuestion();
  }

  Widget _buildImageWidget(ImageRef? ref, double height, ResponsiveInfo info) {
    if (ref == null) return Container(height: height);

    // If we have an XFile (picked file) prefer reading bytes and rendering via Image.memory.
    // This avoids FileImage issues for content URIs or web builds.
    if (ref.xFile != null) {
      return FutureBuilder<Uint8List>(
        future: ref.xFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return SizedBox(
              height: height,
              child: const Center(child: Icon(Icons.broken_image)),
            );
          }
          return Image.memory(
            snapshot.data!,
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
          );
        },
      );
    }

    if (ref.hasLocal && ref.localPath != null && ref.localPath!.isNotEmpty) {
      final provider = ResizeImage(
        FileImage(File(ref.localPath!)),
        width: info.isMobile ? 800 : _localDecodeWidth,
      );
      return Image(
        image: provider,
        height: height,
        width: double.infinity,
        fit: BoxFit.contain,
      );
    }

    if (ref.remoteUrl != null && ref.remoteUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ref.remoteUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (ctx, url) => SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (ctx, url, err) => SizedBox(
          height: height,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    }

    return Container(
      height: height,
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image)),
    );
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(TextEditingController());
      _optionImages.add(null);
    });
    _updateQuestion();
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) {
      SnackbarUtils.showWarning(context, 'At least 2 options required');
      return;
    }

    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
      _optionImages.removeAt(index);

      if (_correctIndex == index) {
        _correctIndex = null;
      } else if (_correctIndex != null && _correctIndex! > index) {
        _correctIndex = _correctIndex! - 1;
      }
    });
    _updateQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(info.scale(20)),
        children: [
          // Question Text
          InputStyles.fieldLabel('Question'),
          SizedBox(height: info.scale(4)),
          TextFormField(
            controller: _questionCtrl,
            decoration: InputStyles.decoration(
              label: 'Question',
              hint: 'Enter your question',
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _updateQuestion(),
            validator: (v) => validateRequired(v, fieldName: 'Question'),
          ),
          SizedBox(height: info.scale(16)),

          // Question Image
          InputStyles.fieldLabel('Question Image (Optional)'),
          SizedBox(height: info.scale(8)),
          if (_questionImage != null)
            Stack(
              children: [
                SizedBox(
                  height: info.scale(200),
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(
                      _questionImage,
                      info.scale(200),
                      info,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _removeQuestionImage,
                    tooltip: 'Remove image',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickQuestionImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Image'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(info.scale(48)),
              ),
            ),
          SizedBox(height: info.scale(24)),

          // Options Header
          Row(
            children: [
              Text(
                'Answer Options',
                style: TextStyle(
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_optionCtrls.length < 6)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: Icon(Icons.add, size: info.scale(18)),
                  label: const Text('Add Option'),
                ),
            ],
          ),
          SizedBox(height: info.scale(12)),

          // Options List
          ..._optionCtrls.asMap().entries.map((entry) {
            final index = entry.key;
            final ctrl = entry.value;
            final optionImage = _optionImages[index];

            return Card(
              margin: EdgeInsets.only(bottom: info.scale(12)),
              child: Padding(
                padding: EdgeInsets.all(info.scale(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Radio API deprecated (groupValue/onChanged). Use a simple tappable icon
                        // to represent selection to avoid deprecated usage while keeping UX.
                        InkWell(
                          onTap: () {
                            setState(() {
                              _correctIndex = index;
                            });
                            _updateQuestion();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: EdgeInsets.all(info.scale(8)),
                            child: Icon(
                              _correctIndex == index
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: info.scale(20),
                              color: _correctIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Option ${String.fromCharCode(65 + index)}',
                            style: TextStyle(
                              fontSize: info.scaleFont(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_optionCtrls.length > 2)
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: info.scale(20),
                              color: Colors.red,
                            ),
                            onPressed: () => _removeOption(index),
                            tooltip: 'Remove option',
                          ),
                      ],
                    ),
                    SizedBox(height: info.scale(8)),
                    TextFormField(
                      controller: ctrl,
                      decoration: InputStyles.decoration(
                        label: 'Option text',
                        hint: 'Enter option text',
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _updateQuestion(),
                    ),
                    SizedBox(height: info.scale(12)),
                    if (optionImage != null)
                      Stack(
                        children: [
                          SizedBox(
                            height: info.scale(120),
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImageWidget(
                                optionImage,
                                info.scale(120),
                                info,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => _removeOptionImage(index),
                              tooltip: 'Remove image',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _pickOptionImage(index),
                        icon: Icon(Icons.image, size: info.scale(16)),
                        label: const Text('Add Image'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(info.scale(36)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: info.scale(16)),

          // Points and Explanation Row
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InputStyles.fieldLabel('Points'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _pointsCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Points',
                        hint: '1',
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateQuestion(),
                      validator: (v) =>
                          validateRequired(v, fieldName: 'Points'),
                    ),
                  ],
                ),
              ),
              SizedBox(width: info.scale(16)),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InputStyles.fieldLabel('Explanation (Optional)'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _explanationCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Explanation',
                        hint: 'Why is this correct?',
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      onChanged: (_) => _updateQuestion(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Correct Answer Hint
          if (_correctIndex == null)
            Padding(
              padding: EdgeInsets.only(top: info.scale(16)),
              child: Container(
                padding: EdgeInsets.all(info.scale(12)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: info.scale(20),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        'Please select the correct answer',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
