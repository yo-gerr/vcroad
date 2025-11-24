// lib/shared/models/questions.dart
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

enum QuestionType { multipleChoice, trueFalse, identification, matchingType }

/// Enum extension for safer (de)serialization
extension QuestionTypeX on QuestionType {
  String get name => toString().split('.').last;

  static QuestionType fromName(String name) {
    return QuestionType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => QuestionType.identification,
    );
  }

  // Add display names for UI
  String get displayName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True or False';
      case QuestionType.identification:
        return 'Identification';
      case QuestionType.matchingType:
        return 'Matching Type';
    }
  }

  // Add icons for UI
  String get iconName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'radio_button_checked';
      case QuestionType.trueFalse:
        return 'check_circle';
      case QuestionType.identification:
        return 'edit';
      case QuestionType.matchingType:
        return 'compare_arrows';
    }
  }
}

/// Validation result with optional error message
class ValidationResult {
  final bool isValid;
  final String? message;

  const ValidationResult.valid() : isValid = true, message = null;
  const ValidationResult.invalid(this.message) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $message';
}

/// Image reference with support for local and remote URLs
class ImageRef {
  final String? localPath;
  final String? remoteUrl;
  final Uint8List? localBytes;
  final XFile? xFile;

  const ImageRef({this.localPath, this.remoteUrl, this.localBytes, this.xFile});

  bool get hasLocal =>
      localBytes != null || (localPath?.isNotEmpty ?? false) || xFile != null;

  bool get hasRemote => remoteUrl != null && remoteUrl!.isNotEmpty;

  bool get isEmpty => !hasLocal && !hasRemote;

  // Get displayable URL/path for preview
  String? get previewPath => remoteUrl ?? localPath;

  ImageRef copyWith({
    String? localPath,
    String? remoteUrl,
    Uint8List? localBytes,
    XFile? xFile,
  }) {
    return ImageRef(
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localBytes: localBytes ?? this.localBytes,
      xFile: xFile ?? this.xFile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (localPath != null) 'localPath': localPath,
      if (remoteUrl != null) 'remoteUrl': remoteUrl,
    };
  }

  factory ImageRef.fromJson(Map<String, dynamic> json) {
    return ImageRef(
      localPath: json['localPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageRef &&
          runtimeType == other.runtimeType &&
          localPath == other.localPath &&
          remoteUrl == other.remoteUrl;

  @override
  int get hashCode => localPath.hashCode ^ remoteUrl.hashCode;
}

/// Strongly typed pair for Matching questions
class MatchingPair {
  final String id;
  final ImageRef image;
  final String meaning;

  MatchingPair({String? id, required this.image, required this.meaning})
    : id = id ?? const Uuid().v4();

  String get imageUrl => image.remoteUrl ?? image.localPath ?? '';

  bool get isValid => !image.isEmpty && meaning.trim().isNotEmpty;

  MatchingPair copyWith({String? id, ImageRef? image, String? meaning}) {
    return MatchingPair(
      id: id ?? this.id,
      image: image ?? this.image,
      meaning: meaning ?? this.meaning,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image.toJson(),
    'meaning': meaning,
  };

  factory MatchingPair.fromJson(Map<String, dynamic> json) {
    final imageJson = json['image'];
    ImageRef imageRef;

    if (imageJson is Map<String, dynamic>) {
      imageRef = ImageRef.fromJson(imageJson);
    } else {
      final fallback = json['imageUrl'] ?? json['imagePath'] ?? '';
      if (fallback is String && fallback.isNotEmpty) {
        imageRef = fallback.startsWith('http')
            ? ImageRef(remoteUrl: fallback)
            : ImageRef(localPath: fallback);
      } else {
        imageRef = const ImageRef();
      }
    }

    return MatchingPair(
      id: json['id'] as String?,
      image: imageRef,
      meaning: (json['meaning'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchingPair &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class QuizQuestion {
  final String id;
  final QuestionType type;
  final String question;
  final ImageRef? questionImage; // Separate question image

  // Multiple Choice fields
  final List<String>? options;
  final List<ImageRef?>? optionImages;
  final int? correctIndex;

  // True/False fields
  final bool? correctBool;

  // Identification fields
  final String? correctAnswer;

  // Matching Type fields
  final List<MatchingPair>? matchingPairs;

  // Metadata
  final int points; // Points for this question
  final String? explanation; // Optional explanation for correct answer

  QuizQuestion({
    String? id,
    required this.type,
    required this.question,
    this.questionImage,
    this.options,
    this.optionImages,
    this.correctIndex,
    this.correctBool,
    this.correctAnswer,
    this.matchingPairs,
    this.points = 1,
    this.explanation,
  }) : id = id ?? const Uuid().v4();

  QuizQuestion copyWith({
    String? id,
    QuestionType? type,
    String? question,
    ImageRef? questionImage,
    List<String>? options,
    List<ImageRef?>? optionImages,
    int? correctIndex,
    bool? correctBool,
    String? correctAnswer,
    List<MatchingPair>? matchingPairs,
    int? points,
    String? explanation,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      question: question ?? this.question,
      questionImage: questionImage ?? this.questionImage,
      options: options ?? this.options,
      optionImages: optionImages ?? this.optionImages,
      correctIndex: correctIndex ?? this.correctIndex,
      correctBool: correctBool ?? this.correctBool,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      matchingPairs: matchingPairs ?? this.matchingPairs,
      points: points ?? this.points,
      explanation: explanation ?? this.explanation,
    );
  }

  /// Validation depending on type
  ValidationResult validate() {
    // Skip question text check for matching type
    if (type != QuestionType.matchingType && question.trim().isEmpty) {
      return const ValidationResult.invalid("Question text is required");
    }

    switch (type) {
      case QuestionType.multipleChoice:
        if (options == null || options!.length < 2) {
          return const ValidationResult.invalid("At least 2 options required");
        }

        // Check if at least one option has content
        bool hasContent = false;
        for (int i = 0; i < options!.length; i++) {
          final hasText = options![i].trim().isNotEmpty;
          final hasImage =
              optionImages != null &&
              i < optionImages!.length &&
              optionImages![i] != null &&
              !optionImages![i]!.isEmpty;

          if (hasText || hasImage) {
            hasContent = true;
          }
        }

        if (!hasContent) {
          return const ValidationResult.invalid(
            "At least one option must have text or image",
          );
        }

        if (correctIndex == null ||
            correctIndex! < 0 ||
            correctIndex! >= options!.length) {
          return const ValidationResult.invalid(
            "Valid correct option required",
          );
        }
        return const ValidationResult.valid();

      case QuestionType.trueFalse:
        if (correctBool == null) {
          return const ValidationResult.invalid("True/False answer required");
        }
        return const ValidationResult.valid();

      case QuestionType.identification:
        if (correctAnswer == null || correctAnswer!.trim().isEmpty) {
          return const ValidationResult.invalid("Answer required");
        }
        return const ValidationResult.valid();

      case QuestionType.matchingType:
        if (matchingPairs == null || matchingPairs!.length < 2) {
          return const ValidationResult.invalid(
            "At least 2 matching pairs required",
          );
        }

        for (int i = 0; i < matchingPairs!.length; i++) {
          if (!matchingPairs![i].isValid) {
            return ValidationResult.invalid(
              "Matching pair ${i + 1} must have image and meaning",
            );
          }
        }

        // Check for duplicate meanings
        final meanings = matchingPairs!.map((p) => p.meaning.trim()).toSet();
        if (meanings.length != matchingPairs!.length) {
          return const ValidationResult.invalid(
            "Duplicate meanings not allowed",
          );
        }

        return const ValidationResult.valid();
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'type': type.name,
      'question': question,
      'points': points,
    };

    if (questionImage != null && !questionImage!.isEmpty) {
      data['questionImage'] = questionImage!.toJson();
    }

    if (explanation != null && explanation!.isNotEmpty) {
      data['explanation'] = explanation;
    }

    switch (type) {
      case QuestionType.multipleChoice:
        data.addAll({'options': options, 'correctIndex': correctIndex});
        if (optionImages != null && optionImages!.isNotEmpty) {
          data['optionImages'] = optionImages!
              .map((img) => img?.toJson() ?? {})
              .toList(growable: false);
        }
        break;

      case QuestionType.trueFalse:
        data.addAll({'correctBool': correctBool});
        break;

      case QuestionType.identification:
        data.addAll({'correctAnswer': correctAnswer});
        break;

      case QuestionType.matchingType:
        data.addAll({
          'matchingPairs': matchingPairs
              ?.map((p) => p.toJson())
              .toList(growable: false),
        });
        break;
    }

    return data;
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'identification';
    final type = QuestionTypeX.fromName(typeStr);

    ImageRef? questionImage;
    if (json['questionImage'] != null) {
      questionImage = ImageRef.fromJson(
        Map<String, dynamic>.from(json['questionImage']),
      );
    }

    List<ImageRef?>? optionImages;
    if (json['optionImages'] != null) {
      optionImages = (json['optionImages'] as List<dynamic>).map((e) {
        if (e == null || (e is Map && e.isEmpty)) return null;
        return ImageRef.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    return QuizQuestion(
      id: json['id'] as String?,
      type: type,
      question: (json['question'] as String?) ?? '',
      questionImage: questionImage,
      options: (json['options'] as List?)?.map((o) => o.toString()).toList(),
      optionImages: optionImages,
      correctIndex: json['correctIndex'] is int
          ? json['correctIndex']
          : int.tryParse("${json['correctIndex'] ?? ''}"),
      correctBool: json['correctBool'] is bool
          ? json['correctBool']
          : (json['correctBool']?.toString().toLowerCase() == 'true'),
      correctAnswer: json['correctAnswer'] as String?,
      matchingPairs: (json['matchingPairs'] as List<dynamic>?)
          ?.map((e) => MatchingPair.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      points: (json['points'] as num?)?.toInt() ?? 1,
      explanation: json['explanation'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizQuestion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuizQuestion(id: $id, type: ${type.displayName})';
}
