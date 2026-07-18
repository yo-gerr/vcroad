import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// Uploads to valid_ids/{uid}/id.jpg and selfies/{uid}/selfie.jpg with retry.
class ImageService {
  // Simple in-memory cache for storage-path -> download URL
  static final Map<String, String> _urlCache = {};

  // Commented out: uploadUserImage uses firebase_storage
  // static Future<String> uploadUserImage({
  //   required String imageType,
  //   required String userId,
  //   required dynamic imageData,
  //   SettableMetadata? metadata,
  //   int maxRetries = 2,
  //   int compressQuality = 75,
  //   int maxWidth = 1024,
  // }) async {
  //   dynamic compressedData = imageData;
  //   if (imageData is String) {
  //     compressedData = await compressImageFile(imageData, quality: compressQuality, maxWidth: maxWidth);
  //   } else if (imageData is Uint8List) {
  //     compressedData = compressImageBytes(imageData, quality: compressQuality, maxWidth: maxWidth);
  //   }
  //   final path = switch (imageType) {
  //     'id' => 'valid_ids/$userId/id.jpg',
  //     'selfie' => 'selfies/$userId/selfie.jpg',
  //     _ => throw ArgumentError('imageType must be "id" or "selfie"'),
  //   };
  //   final meta = metadata ?? SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000');
  //   return _uploadWithRetry(storagePath: path, imageData: compressedData, metadata: meta, maxRetries: maxRetries);
  // }

  // Commented out: uploadUserImagesBatch uses firebase_storage
  // static Future<Map<String, String>> uploadUserImagesBatch({
  //   required String userId,
  //   required Map<String, dynamic> images,
  //   SettableMetadata? metadata,
  // }) async {
  //   final futures = <String, Future<String>>{};
  //   if (images['id'] != null) {
  //     futures['id'] = uploadUserImage(imageType: 'id', userId: userId, imageData: images['id'], metadata: metadata);
  //   }
  //   if (images['selfie'] != null) {
  //     futures['selfie'] = uploadUserImage(imageType: 'selfie', userId: userId, imageData: images['selfie'], metadata: metadata);
  //   }
  //   final results = await Future.wait(futures.values);
  //   return Map.fromIterables(futures.keys, results);
  // }

  // Commented out: _uploadWithRetry uses firebase_storage
  // static Future<String> _uploadWithRetry({
  //   required String storagePath,
  //   required dynamic imageData,
  //   required SettableMetadata metadata,
  //   int maxRetries = 2,
  // }) async {
  //   int attempt = 0;
  //   while (true) {
  //     try {
  //       return await _upload(storagePath: storagePath, imageData: imageData, metadata: metadata);
  //     } catch (e) {
  //       attempt++;
  //       if (attempt > maxRetries) rethrow;
  //       await Future.delayed(Duration(milliseconds: 250 * attempt));
  //     }
  //   }
  // }

  // Commented out: _upload uses firebase_storage
  // static Future<String> _upload({
  //   required String storagePath,
  //   required dynamic imageData,
  //   required SettableMetadata metadata,
  // }) async {
  //   final ref = FirebaseStorage.instance.ref(storagePath);
  //   UploadTask task;
  //   if (imageData is String) {
  //     task = ref.putFile(File(imageData), metadata);
  //   } else if (imageData is Uint8List) {
  //     task = ref.putData(imageData, metadata);
  //   } else {
  //     throw ArgumentError('Unsupported image data type');
  //   }
  //   final snap = await task.whenComplete(() {});
  //   return snap.ref.getDownloadURL();
  // }

  // Compress image file (path)
  static Future<Uint8List> compressImageFile(
    String path, {
    int quality = 75,
    int maxWidth = 1024,
  }) async {
    final bytes = await File(path).readAsBytes();
    return compressImageBytes(bytes, quality: quality, maxWidth: maxWidth);
  }

  // Compress image bytes
  static Uint8List compressImageBytes(
    Uint8List bytes, {
    int quality = 75,
    int maxWidth = 1024,
  }) {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Invalid image data');
    final resized = img.copyResize(image, width: maxWidth);
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  // Image validation (for registration: id/selfie).
  // Client-side heuristics replace Cloud Vision.
  static Future<Map<String, dynamic>> validateImage(
    Uint8List imageBytes,
  ) async {
    return _basicImageValidation(imageBytes);
  }

  /// Validate report media for safe content only.
  /// Client-side heuristics replace Cloud Vision.
  static Future<Map<String, dynamic>> validateReportMedia(
    Uint8List imageBytes,
  ) async {
    return _basicImageValidation(imageBytes);
  }

  /// Client-side image validation (replaces Cloud Vision).
  /// Checks: decode success, minimum dimensions, luminance variance.
  static Map<String, dynamic> _basicImageValidation(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return {
          'valid': false,
          'reason': 'Unable to decode image. Please use a valid image file.',
        };
      }

      if (image.width < 200 || image.height < 200) {
        return {
          'valid': false,
          'reason': 'Image resolution is too low. Please use a clearer image.',
        };
      }

      final variance = _computeLuminanceVariance(image);
      if (variance < 15) {
        return {
          'valid': false,
          'reason':
              'Image appears blank or low contrast. Please retake with better lighting.',
        };
      }

      return {'valid': true};
    } catch (e) {
      return {'valid': false, 'reason': 'Image validation failed: $e'};
    }
  }

  /// Estimate image interestingness via random-sample luminance variance.
  static double _computeLuminanceVariance(img.Image image) {
    final random = Random();
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    final totalPixels = image.width * image.height;
    final samples = min(200, totalPixels);

    for (int i = 0; i < samples; i++) {
      final idx = random.nextInt(totalPixels);
      final x = idx % image.width;
      final y = idx ~/ image.width;
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      sum += luminance;
      sumSq += luminance * luminance;
      count++;
    }

    if (count == 0) return 0;
    final mean = sum / count;
    return (sumSq / count) - (mean * mean);
  }

  // Peek cached URL synchronously (no network).
  static String? peekCachedUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;
    return _urlCache[storagePath];
  }

  // Commented out: getDownloadUrlCached uses firebase_storage
  // static Future<String?> getDownloadUrlCached(String? storagePath) async {
  //   if (storagePath == null || storagePath.isEmpty) return null;
  //   final cached = _urlCache[storagePath];
  //   if (cached != null) return cached;
  //   try {
  //     final ref = FirebaseStorage.instance.ref(storagePath);
  //     final url = await ref.getDownloadURL();
  //     _urlCache[storagePath] = url;
  //     return url;
  //   } catch (_) {
  //     return null;
  //   }
  // }

  // Commented out: prefetchDownloadUrls uses firebase_storage
  // static Future<void> prefetchDownloadUrls(Iterable<String?> paths) async {
  //   final tasks = <Future>[];
  //   for (final p in paths) {
  //     if (p == null || p.isEmpty) continue;
  //     if (_urlCache.containsKey(p)) continue;
  //     tasks.add(getDownloadUrlCached(p));
  //   }
  //   if (tasks.isNotEmpty) {
  //     await Future.wait(tasks);
  //   }
  // }

  // Evict a cached path (e.g., when user updates selfie).
  static void evictCachedUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return;
    _urlCache.remove(storagePath);
    // Also evict from CachedNetworkImage cache
    if (_urlCache[storagePath] != null) {
      CachedNetworkImage.evictFromCache(_urlCache[storagePath]!);
    }
  }

  /// Build a CachedNetworkImage widget with optimized settings
  static Widget buildCachedAvatar({
    required String? imageUrl,
    required double radius,
    String placeholderAsset = 'assets/images/vcroad.webp',
    int? cacheWidth,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(placeholderAsset),
        backgroundColor: Colors.transparent,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: Colors.transparent,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: Icon(
          Icons.person,
          size: radius * 0.8,
          color: Colors.grey.shade400,
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(placeholderAsset),
        backgroundColor: Colors.transparent,
      ),
      memCacheWidth: cacheWidth,
      maxWidthDiskCache: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  // Add this method to AccountProvider or AuthService
  static Future<void> clearImageCache() async {
    await CachedNetworkImage.evictFromCache(''); // Clears all
    _urlCache.clear();
  }
}
