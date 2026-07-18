import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrueFalseEditor extends StatefulWidget {
  final QuizQuestion? question;
  final ValueChanged<QuizQuestion> onQuestionChanged;

  const TrueFalseEditor({
    super.key,
    this.question,
    required this.onQuestionChanged,
  });

  @override
  State<TrueFalseEditor> createState() => _TrueFalseEditorState();
}

class _TrueFalseEditorState extends State<TrueFalseEditor> {
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();

  ImageRef? _questionImage;
  bool? _correctBool;
  final ImagePicker _picker = ImagePicker();
  // decode width target for local images (smaller -> less memory)
  static const int _localDecodeWidth = 1200;

  Widget _buildImageWidget(ImageRef ref, double height, ResponsiveInfo info) {
    // If XFile exists prefer reading bytes (works with content URIs and web)
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

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _questionCtrl.text = widget.question!.question;
      _pointsCtrl.text = widget.question!.points.toString();
      _explanationCtrl.text = widget.question!.explanation ?? '';
      _questionImage = widget.question!.questionImage;
      _correctBool = widget.question!.correctBool;
    } else {
      _pointsCtrl.text = '1';
    }

    _updateQuestion();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _pointsCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  void _updateQuestion() {
    final question = QuizQuestion(
      id: widget.question?.id,
      type: QuestionType.trueFalse,
      question: _questionCtrl.text,
      questionImage: _questionImage,
      correctBool: _correctBool,
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
              hint: 'Enter your true/false question',
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
                      _questionImage!,
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
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
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

          // Correct Answer
          InputStyles.fieldLabel('Correct Answer'),
          SizedBox(height: info.scale(12)),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: _correctBool == true
                      ? Colors.green.withValues(alpha: 0.1)
                      : null,
                  child: InkWell(
                    onTap: () {
                      setState(() => _correctBool = true);
                      _updateQuestion();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(16)),
                      child: Column(
                        children: [
                          Icon(
                            _correctBool == true
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: info.scale(48),
                            color: _correctBool == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                          SizedBox(height: info.scale(8)),
                          Text(
                            'TRUE',
                            style: TextStyle(
                              fontSize: info.scaleFont(18),
                              fontWeight: FontWeight.bold,
                              color: _correctBool == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: info.scale(16)),
              Expanded(
                child: Card(
                  color: _correctBool == false
                      ? Colors.red.withValues(alpha: 0.1)
                      : null,
                  child: InkWell(
                    onTap: () {
                      setState(() => _correctBool = false);
                      _updateQuestion();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(16)),
                      child: Column(
                        children: [
                          Icon(
                            _correctBool == false
                                ? Icons.cancel
                                : Icons.cancel_outlined,
                            size: info.scale(48),
                            color: _correctBool == false
                                ? Colors.red
                                : Colors.grey,
                          ),
                          SizedBox(height: info.scale(8)),
                          Text(
                            'FALSE',
                            style: TextStyle(
                              fontSize: info.scaleFont(18),
                              fontWeight: FontWeight.bold,
                              color: _correctBool == false
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: info.scale(24)),

          // Points and Explanation
          InputStyles.fieldLabel('Points'),
          SizedBox(height: info.scale(4)),
          TextFormField(
            controller: _pointsCtrl,
            decoration: InputStyles.decoration(label: 'Points', hint: '1'),
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateQuestion(),
            validator: (v) => validateRequired(v, fieldName: 'Points'),
          ),
          SizedBox(height: info.scale(16)),

          InputStyles.fieldLabel('Explanation (Optional)'),
          SizedBox(height: info.scale(4)),
          TextFormField(
            controller: _explanationCtrl,
            decoration: InputStyles.decoration(
              label: 'Explanation',
              hint: 'Why is this true/false?',
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            onChanged: (_) => _updateQuestion(),
          ),

          // Answer Selection Hint
          if (_correctBool == null)
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
                        'Please select TRUE or FALSE as the correct answer',
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
