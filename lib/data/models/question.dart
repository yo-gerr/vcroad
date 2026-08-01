import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

enum QuestionType { multipleChoice, trueFalse, identification, matchingType }

extension QuestionTypeX on QuestionType {
  String get name => toString().split('.').last;

  static QuestionType fromName(String name) {
    return QuestionType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => QuestionType.identification,
    );
  }

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
}

class ValidationResult {
  final bool isValid;
  final String? message;

  const ValidationResult.valid() : isValid = true, message = null;
  const ValidationResult.invalid(this.message) : isValid = false;
}

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
  final String lessonId;
  final QuestionType type;
  final String questionText;
  final ImageRef? questionImage;
  final List<String>? options;
  final List<ImageRef?>? optionImages;
  final int? correctIndex;
  final bool? correctBool;
  final String? correctAnswer;
  final List<MatchingPair>? matchingPairs;
  final int points;
  final String? explanation;
  final int order;
  final int timesAnswered;
  final int timesCorrect;

  QuizQuestion({
    String? id,
    required this.lessonId,
    required this.type,
    required this.questionText,
    this.questionImage,
    this.options,
    this.optionImages,
    this.correctIndex,
    this.correctBool,
    this.correctAnswer,
    this.matchingPairs,
    this.points = 1,
    this.explanation,
    this.order = 0,
    this.timesAnswered = 0,
    this.timesCorrect = 0,
  }) : id = id ?? const Uuid().v4();

  QuizQuestion copyWith({
    String? id,
    String? lessonId,
    QuestionType? type,
    String? questionText,
    ImageRef? questionImage,
    List<String>? options,
    List<ImageRef?>? optionImages,
    int? correctIndex,
    bool? correctBool,
    String? correctAnswer,
    List<MatchingPair>? matchingPairs,
    int? points,
    String? explanation,
    int? order,
    int? timesAnswered,
    int? timesCorrect,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      type: type ?? this.type,
      questionText: questionText ?? this.questionText,
      questionImage: questionImage ?? this.questionImage,
      options: options ?? this.options,
      optionImages: optionImages ?? this.optionImages,
      correctIndex: correctIndex ?? this.correctIndex,
      correctBool: correctBool ?? this.correctBool,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      matchingPairs: matchingPairs ?? this.matchingPairs,
      points: points ?? this.points,
      explanation: explanation ?? this.explanation,
      order: order ?? this.order,
      timesAnswered: timesAnswered ?? this.timesAnswered,
      timesCorrect: timesCorrect ?? this.timesCorrect,
    );
  }

  ValidationResult validate() {
    if (type != QuestionType.matchingType && questionText.trim().isEmpty) {
      return const ValidationResult.invalid("Question text is required");
    }

    switch (type) {
      case QuestionType.multipleChoice:
        if (options == null || options!.length < 2) {
          return const ValidationResult.invalid("At least 2 options required");
        }
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
      'lessonId': lessonId,
      'type': type.name,
      'questionText': questionText,
      'points': points,
      'order': order,
      'timesAnswered': timesAnswered,
      'timesCorrect': timesCorrect,
    };

    if (questionImage != null && !questionImage!.isEmpty) {
      data['questionImageUrl'] = questionImage!.remoteUrl;
    }

    if (explanation != null && explanation!.isNotEmpty) {
      data['explanation'] = explanation;
    }

    switch (type) {
      case QuestionType.multipleChoice:
        data.addAll({'options': options, 'correctIndex': correctIndex});
        if (optionImages != null && optionImages!.isNotEmpty) {
          data['optionImageUrls'] = optionImages!
              .map((img) => img?.remoteUrl)
              .whereType<String>()
              .toList(growable: false);
        }
      case QuestionType.trueFalse:
        data.addAll({'correctBool': correctBool});
      case QuestionType.identification:
        data.addAll({'correctAnswer': correctAnswer});
      case QuestionType.matchingType:
        data.addAll({
          'matchingPairs': matchingPairs
              ?.map((p) => p.toJson())
              .toList(growable: false),
        });
    }

    return data;
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'identification';
    final type = QuestionTypeX.fromName(typeStr);

    ImageRef? questionImage;
    if (json['questionImageUrl'] != null) {
      questionImage = ImageRef(
        remoteUrl: json['questionImageUrl'] as String,
      );
    } else if (json['questionImage'] != null) {
      questionImage = ImageRef.fromJson(
        Map<String, dynamic>.from(json['questionImage']),
      );
    }

    List<ImageRef?>? optionImages;
    if (json['optionImageUrls'] != null) {
      optionImages = (json['optionImageUrls'] as List<dynamic>)
          .map((e) => e != null ? ImageRef(remoteUrl: e.toString()) : null)
          .toList();
    } else if (json['optionImages'] != null) {
      optionImages = (json['optionImages'] as List<dynamic>).map((e) {
        if (e == null || (e is Map && e.isEmpty)) return null;
        return ImageRef.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    return QuizQuestion(
      id: json['id'] as String?,
      lessonId: (json['lessonId'] as String?) ?? '',
      type: type,
      questionText: (json['questionText'] as String?) ?? json['question'] as String? ?? '',
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
      order: (json['order'] as num?)?.toInt() ?? 0,
      timesAnswered: (json['timesAnswered'] as num?)?.toInt() ?? 0,
      timesCorrect: (json['timesCorrect'] as num?)?.toInt() ?? 0,
    );
  }

  String get imageUrl =>
      questionImage?.remoteUrl ?? questionImage?.localPath ?? '';

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
