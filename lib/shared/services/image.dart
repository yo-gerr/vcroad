import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// Uploads to valid_ids/{uid}/id.jpg and selfies/{uid}/selfie.jpg with retry.
class ImageService {
  // Simple in-memory cache for storage-path -> download URL
  static final Map<String, String> _urlCache = {};

  static Future<String> uploadUserImage({
    required String imageType, // 'id' | 'selfie'
    required String userId,
    required dynamic imageData, // String (path) or Uint8List (bytes)
    SettableMetadata? metadata,
    int maxRetries = 2,
    int compressQuality = 75,
    int maxWidth = 1024,
  }) async {
    dynamic compressedData = imageData;
    if (imageData is String) {
      // Compress file
      compressedData = await compressImageFile(
        imageData,
        quality: compressQuality,
        maxWidth: maxWidth,
      );
    } else if (imageData is Uint8List) {
      // Compress bytes
      compressedData = compressImageBytes(
        imageData,
        quality: compressQuality,
        maxWidth: maxWidth,
      );
    }

    final path = switch (imageType) {
      'id' => 'valid_ids/$userId/id.jpg',
      'selfie' => 'selfies/$userId/selfie.jpg',
      _ => throw ArgumentError('imageType must be "id" or "selfie"'),
    };
    final meta =
        metadata ??
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        );
    return _uploadWithRetry(
      storagePath: path,
      imageData: compressedData,
      metadata: meta,
      maxRetries: maxRetries,
    );
  }

  static Future<Map<String, String>> uploadUserImagesBatch({
    required String userId,
    required Map<String, dynamic> images, // {'id': ..., 'selfie': ...}
    SettableMetadata? metadata,
  }) async {
    final futures = <String, Future<String>>{};
    if (images['id'] != null) {
      futures['id'] = uploadUserImage(
        imageType: 'id',
        userId: userId,
        imageData: images['id'],
        metadata: metadata,
      );
    }
    if (images['selfie'] != null) {
      futures['selfie'] = uploadUserImage(
        imageType: 'selfie',
        userId: userId,
        imageData: images['selfie'],
        metadata: metadata,
      );
    }
    // Parallel upload
    final results = await Future.wait(futures.values);
    return Map.fromIterables(futures.keys, results);
  }

  static Future<String> _uploadWithRetry({
    required String storagePath,
    required dynamic imageData,
    required SettableMetadata metadata,
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await _upload(
          storagePath: storagePath,
          imageData: imageData,
          metadata: metadata,
        );
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }

  static Future<String> _upload({
    required String storagePath,
    required dynamic imageData,
    required SettableMetadata metadata,
  }) async {
    final ref = FirebaseStorage.instance.ref(storagePath);
    UploadTask task;
    if (imageData is String) {
      task = ref.putFile(File(imageData), metadata);
    } else if (imageData is Uint8List) {
      task = ref.putData(imageData, metadata);
    } else {
      throw ArgumentError('Unsupported image data type');
    }
    final snap = await task.whenComplete(() {});
    return snap.ref.getDownloadURL();
  }

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

  // Image validation (for registration: id/selfie)
  static Future<Map<String, dynamic>> validateImage(
    Uint8List imageBytes,
  ) async {
    final base64Image = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse(
        'https://us-central1-vcroad-a0022.cloudfunctions.net/vcroadApi/vision/validate',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageBytes': base64Image}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Image validation failed');
    }
  }

  /// Validate report media (photo/video) for safe content only
  /// Does not check categories - only ensures content is appropriate
  static Future<Map<String, dynamic>> validateReportMedia(
    Uint8List imageBytes,
  ) async {
    final base64Image = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse(
        'https://us-central1-vcroad-a0022.cloudfunctions.net/vcroadApi/vision/validate-report',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageBytes': base64Image}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Report media validation failed');
    }
  }

  // Peek cached URL synchronously (no network).
  static String? peekCachedUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;
    return _urlCache[storagePath];
  }

  // Get download URL with caching. If not cached, fetch and cache it.
  static Future<String?> getDownloadUrlCached(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    final cached = _urlCache[storagePath];
    if (cached != null) return cached;
    try {
      final ref = FirebaseStorage.instance.ref(storagePath);
      final url = await ref.getDownloadURL();
      _urlCache[storagePath] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  // Prefetch a group of storage paths (best effort).
  static Future<void> prefetchDownloadUrls(Iterable<String?> paths) async {
    final tasks = <Future>[];
    for (final p in paths) {
      if (p == null || p.isEmpty) continue;
      if (_urlCache.containsKey(p)) continue;
      tasks.add(getDownloadUrlCached(p));
    }
    if (tasks.isNotEmpty) {
      // Fire in parallel; errors are ignored inside getDownloadUrlCached
      await Future.wait(tasks);
    }
  }

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
