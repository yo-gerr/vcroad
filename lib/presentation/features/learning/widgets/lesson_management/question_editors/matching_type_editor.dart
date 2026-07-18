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
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';

class MatchingTypeEditor extends StatefulWidget {
  final QuizQuestion? question;
  final ValueChanged<QuizQuestion> onQuestionChanged;

  const MatchingTypeEditor({
    super.key,
    this.question,
    required this.onQuestionChanged,
  });

  @override
  State<MatchingTypeEditor> createState() => _MatchingTypeEditorState();
}

class _MatchingTypeEditorState extends State<MatchingTypeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _pointsCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  final List<_MatchingPairData> _pairs = [];
  final ImagePicker _picker = ImagePicker();
  static const int _localDecodeWidth = 1200;

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _pointsCtrl.text = widget.question!.points.toString();
      _explanationCtrl.text = widget.question!.explanation ?? '';

      if (widget.question!.matchingPairs != null) {
        for (final pair in widget.question!.matchingPairs!) {
          _pairs.add(
            _MatchingPairData(
              meaningCtrl: TextEditingController(text: pair.meaning),
              imageRef: pair.image,
              matchingPair: pair,
            ),
          );
        }
      }
    } else {
      _pointsCtrl.text = '1';
      // Start with 3 empty pairs
      for (int i = 0; i < 3; i++) {
        _addPair();
      }
    }

    _updateQuestion();
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _explanationCtrl.dispose();
    for (var pair in _pairs) {
      pair.meaningCtrl.dispose();
    }
    super.dispose();
  }

  void _updateQuestion() {
    final matchingPairs = _pairs.map((p) {
      return MatchingPair(
        id: p.matchingPair?.id,
        image: p.imageRef ?? const ImageRef(),
        meaning: p.meaningCtrl.text,
      );
    }).toList();

    final question = QuizQuestion(
      id: widget.question?.id,
      type: QuestionType.matchingType,
      question: '', // Matching type doesn't need question text
      matchingPairs: matchingPairs,
      points: int.tryParse(_pointsCtrl.text) ?? 1,
      explanation: _explanationCtrl.text.isEmpty ? null : _explanationCtrl.text,
    );
    widget.onQuestionChanged(question);
  }

  void _addPair() {
    setState(() {
      _pairs.add(
        _MatchingPairData(
          meaningCtrl: TextEditingController(),
          imageRef: null,
          matchingPair: null,
        ),
      );
    });
    _updateQuestion();
  }

  void _removePair(int index) {
    if (_pairs.length <= 2) {
      SnackbarUtils.showWarning(context, 'At least 2 pairs required');
      return;
    }

    setState(() {
      _pairs[index].meaningCtrl.dispose();
      _pairs.removeAt(index);
    });
    _updateQuestion();
  }

  /// Remove image for a specific pair and update question state
  void _removeImage(int index) {
    if (index < 0 || index >= _pairs.length) return;
    setState(() {
      _pairs[index].imageRef = null;
    });
    _updateQuestion();
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _pairs[index].imageRef = ImageRef(localPath: image.path, xFile: image);
      });
      _updateQuestion();
    }
  }

  Widget _buildImageWidget(ImageRef? ref, double height, ResponsiveInfo info) {
    if (ref == null) return Container(height: height);

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
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(info.scale(20)),
        children: [
          // Info Header
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
                  size: info.scale(20),
                ),
                SizedBox(width: info.scale(8)),
                Expanded(
                  child: Text(
                    'Create pairs of images and their meanings. Users will match them.',
                    style: TextStyle(
                      fontSize: info.scaleFont(12),
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: info.scale(24)),

          // Pairs Header
          Row(
            children: [
              Text(
                'Matching Pairs (${_pairs.length})',
                style: TextStyle(
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_pairs.length < 10)
                TextButton.icon(
                  onPressed: _addPair,
                  icon: Icon(Icons.add, size: info.scale(18)),
                  label: const Text('Add Pair'),
                ),
            ],
          ),
          SizedBox(height: info.scale(12)),

          // Pairs List
          ..._pairs.asMap().entries.map((entry) {
            final index = entry.key;
            final pairData = entry.value;

            return Card(
              margin: EdgeInsets.only(bottom: info.scale(16)),
              child: Padding(
                padding: EdgeInsets.all(info.scale(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pair Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: info.scale(12),
                            vertical: info.scale(6),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF001278),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pair ${index + 1}',
                            style: TextStyle(
                              fontSize: info.scaleFont(12),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_pairs.length > 2)
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: info.scale(20),
                              color: Colors.red,
                            ),
                            onPressed: () => _removePair(index),
                            tooltip: 'Remove pair',
                          ),
                      ],
                    ),
                    SizedBox(height: info.scale(16)),

                    // Image Section
                    InputStyles.fieldLabel('Image'),
                    SizedBox(height: info.scale(8)),
                    if (pairData.imageRef != null)
                      Stack(
                        children: [
                          SizedBox(
                            height: info.scale(180),
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImageWidget(
                                pairData.imageRef,
                                info.scale(180),
                                info,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => _removeImage(index),
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
                        onPressed: () => _pickImage(index),
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Image'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(info.scale(48)),
                        ),
                      ),
                    SizedBox(height: info.scale(16)),

                    // Meaning Section
                    InputStyles.fieldLabel('Meaning / Description'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: pairData.meaningCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Meaning',
                        hint: 'Enter the meaning or description',
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _updateQuestion(),
                      validator: (v) => validateRequired(
                        v,
                        fieldName: 'Meaning for Pair ${index + 1}',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          SizedBox(height: info.scale(16)),

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
              hint: 'Add any additional context',
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            onChanged: (_) => _updateQuestion(),
          ),

          // Validation Warning
          if (_pairs.length < 2)
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
                        'At least 2 matching pairs are required',
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

class _MatchingPairData {
  final TextEditingController meaningCtrl;
  ImageRef? imageRef;
  final MatchingPair? matchingPair;

  _MatchingPairData({
    required this.meaningCtrl,
    this.imageRef,
    this.matchingPair,
  });
}
