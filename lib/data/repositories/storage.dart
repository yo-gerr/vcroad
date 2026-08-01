import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vcroad/core/constants/config.dart';

class SupabaseStorageService {
  SupabaseStorageService._();
  static final SupabaseStorageService instance = SupabaseStorageService._();

  SupabaseClient get _client => Supabase.instance.client;
  String get _bucket => AppConfig.storageBucket;

  Future<String> uploadFile({
    required String path,
    required File file,
  }) async {
    try {
      await _client.storage.from(_bucket).upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      return getPublicUrl(path);
    } catch (e) {
      debugPrint('SupabaseStorageService.uploadFile error: $e');
      rethrow;
    }
  }

  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      await _client.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );
      return getPublicUrl(path);
    } catch (e) {
      debugPrint('SupabaseStorageService.uploadBytes error: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final path = _extractPathFromUrl(url);
      if (path == null) {
        debugPrint('SupabaseStorageService.deleteFile: could not extract path from URL');
        return;
      }
      await _client.storage.from(_bucket).remove([path]);
    } catch (e) {
      debugPrint('SupabaseStorageService.deleteFile error: $e');
    }
  }

  Future<void> deleteFiles(Iterable<String> urls) async {
    final paths = urls.map((u) => _extractPathFromUrl(u)).whereType<String>().toList();
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (e) {
      debugPrint('SupabaseStorageService.deleteFiles error: $e');
    }
  }

  Future<void> deleteFolder(String prefix) async {
    try {
      final items = await _client.storage.from(_bucket).list(path: prefix);
      if (items.isEmpty) return;
      final paths = items.map((item) => '$prefix/${item.name}').toList();
      await _client.storage.from(_bucket).remove(paths);
    } catch (e) {
      debugPrint('SupabaseStorageService.deleteFolder error: $e');
    }
  }

  String getPublicUrl(String path) {
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  String? _extractPathFromUrl(String url) {
    try {
      final bucketPrefix = '/storage/v1/object/public/$_bucket/';
      final idx = url.indexOf(bucketPrefix);
      if (idx == -1) return null;
      return url.substring(idx + bucketPrefix.length);
    } catch (_) {
      return null;
    }
  }
}
