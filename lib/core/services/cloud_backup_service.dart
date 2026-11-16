// lib/core/services/cloud_backup_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class CloudBackupService {
  final AppDatabase db;
  final String businessId;
  final String baseUrl;

  static const _timeout = Duration(seconds: 60);

  CloudBackupService({
    required this.db,
    required this.businessId,
    required this.baseUrl,
  });

  /// Whether this platform supports local filesystem access.
  /// `path_provider` only works on mobile/desktop, not web.
  bool get _supportsLocalFiles => !kIsWeb;

  /// Uploads the local DB to the server. Returns the server backup ID on
  /// success, `null` on any failure.
  ///
  /// Returns `null` immediately on web (no filesystem access).
  Future<String?> upload({required String databaseName}) async {
    if (!_supportsLocalFiles) {
      debugPrint('☁️ [backup] not supported on web — skipping upload');
      return null;
    }

    if (businessId.isEmpty) {
      debugPrint('☁️ [backup] skipped — no businessId');
      return null;
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(docs.path, databaseName));
      if (!await dbFile.exists()) {
        debugPrint('☁️ [backup] local DB not found at ${dbFile.path}');
        return null;
      }

      final sizeBytes = await dbFile.length();
      debugPrint('☁️ [backup] uploading ${dbFile.path} ($sizeBytes bytes)');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/backups'),
      );
      request.fields['businessId'] = businessId;
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        dbFile.path,
        filename: p.basename(dbFile.path),
      ));

      final streamed = await request.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);

      debugPrint('☁️ [backup] POST /backups → ${res.statusCode}');

      if (res.statusCode == 201) {
        debugPrint('☁️ [backup] success: ${res.body}');
        final match = RegExp(r'"id":"([^"]+)"').firstMatch(res.body);
        return match?.group(1);
      }
      debugPrint('☁️ [backup] failed body: ${res.body}');
      return null;
    } catch (e) {
      debugPrint('☁️ [backup] error: $e');
      return null;
    }
  }

  /// Lists backups available on the server for this business.
  ///
  /// Works on all platforms (pure HTTP — no local filesystem involved).
  Future<List<CloudBackup>> list() async {
    if (businessId.isEmpty) return [];

    try {
      final uri = Uri.parse('$baseUrl/backups?businessId=$businessId');
      final res = await http.get(uri).timeout(_timeout);

      debugPrint('☁️ [backup] GET $uri → ${res.statusCode}');

      if (res.statusCode != 200) {
        debugPrint('☁️ [backup] list failed body: ${res.body}');
        return [];
      }

      return _parseList(res.body);
    } catch (e) {
      debugPrint('☁️ [backup] list error: $e');
      return [];
    }
  }

  /// Downloads a backup and writes it to a staged file for next-launch
  /// restore. Returns `false` on web (no staging possible).
  Future<bool> downloadAndStage(String backupId) async {
    if (!_supportsLocalFiles) {
      debugPrint('☁️ [restore] not supported on web — skipping restore');
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/backups/$backupId/download');
      final res = await http.get(uri).timeout(_timeout);

      debugPrint('☁️ [restore] GET $uri → ${res.statusCode}');

      if (res.statusCode != 200) {
        debugPrint('☁️ [restore] download failed body: ${res.body}');
        return false;
      }

      final docs = await getApplicationDocumentsDirectory();
      final staged = File(p.join(docs.path, 'craft_pos_restore_pending.sqlite'));
      await staged.writeAsBytes(res.bodyBytes);

      debugPrint('☁️ [restore] staged ${res.bodyBytes.length} bytes');
      return true;
    } catch (e) {
      debugPrint('☁️ [restore] error: $e');
      return false;
    }
  }

  List<CloudBackup> _parseList(String body) {
    try {
      final matches = RegExp(
        r'\{"id":"([^"]+)","filename":"([^"]+)","sizeBytes":(\d+),"createdAt":"([^"]+)"',
      ).allMatches(body);

      return matches
          .map((m) => CloudBackup(
        id: m.group(1)!,
        filename: m.group(2)!,
        sizeBytes: int.parse(m.group(3)!),
        createdAt: DateTime.parse(m.group(4)!),
      ))
          .toList();
    } catch (e) {
      debugPrint('☁️ [backup] parse error: $e');
      return [];
    }
  }
}

class CloudBackup {
  final String id;
  final String filename;
  final int sizeBytes;
  final DateTime createdAt;

  CloudBackup({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}