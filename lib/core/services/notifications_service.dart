// lib/core/services/notifications_service.dart

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';

/// Handles fetching, caching, and reading notifications.
class NotificationsService {
  final AppDatabase db;
  final String businessId;
  final String baseUrl;
  final http.Client _http;

  NotificationsService({
    required this.db,
    required this.businessId,
    required this.baseUrl,
    http.Client? client,
  }) : _http = client ?? http.Client();

  // ═══════════════════════════════════════════════════════════════
  // SYNC
  // ═══════════════════════════════════════════════════════════════

  Future<void> sync() async {
    debugPrint('🔔 [sync] START (businessId=$businessId, baseUrl=$baseUrl)');

    final newest = await (db.select(db.notifications)
      ..where((t) => t.businessId.equals(businessId))
      ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
      ..limit(1))
        .getSingleOrNull();

    debugPrint('🔔 [sync] newest local = ${newest?.publishedAt}');

    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: {
        'businessId': businessId,
        if (newest != null)
          'since': newest.publishedAt.toUtc().toIso8601String(),
      },
    );
    debugPrint('🔔 [sync] GET $uri');

    http.Response res;
    try {
      res = await _http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
    } catch (e, stack) {
      debugPrint('🔔 [sync] NETWORK ERROR: $e');
      debugPrint('🔔 [sync] stack: $stack');
      return;
    }

    debugPrint('🔔 [sync] HTTP ${res.statusCode} (${res.body.length} bytes)');
    if (res.statusCode != 200) {
      debugPrint('🔔 [sync] non-200 body: ${res.body}');
      return;
    }

    final List<dynamic> body;
    try {
      body = jsonDecode(res.body) as List<dynamic>;
    } catch (e) {
      debugPrint('🔔 [sync] PARSE ERROR: $e');
      debugPrint('🔔 [sync] raw body: ${res.body}');
      return;
    }

    debugPrint('🔔 [sync] parsed ${body.length} rows');

    for (final raw in body) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        await _upsertFromJson(raw);
      } catch (e, stack) {
        debugPrint('🔔 [sync] UPSERT ERROR for id=${raw['id']}: $e');
        debugPrint('🔔 [sync] stack: $stack');
      }
    }

    final countRow = await (db.selectOnly(db.notifications)
      ..addColumns([db.notifications.id.count()])
      ..where(db.notifications.businessId.equals(businessId)))
        .getSingle();
    final localCount =
        countRow.read(db.notifications.id.count()) ?? 0;
    debugPrint(
        '🔔 [sync] DONE — local rows for $businessId = $localCount');
  }

  Future<void> _upsertFromJson(Map<String, dynamic> j) async {
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) return;

    final existing = await (db.select(db.notifications)
      ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    final publishedAt =
        DateTime.tryParse(j['publishedAt'] as String? ?? '')?.toLocal() ??
            DateTime.now();

    if (existing == null) {
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: id,
          businessId: businessId,
          type: (j['type'] as String?) ?? 'system',
          title: (j['title'] as String?) ?? 'Notification',
          body: (j['body'] as String?) ?? '',
          actionRoute: Value(j['actionRoute'] as String?),
          payloadJson: Value(
            j['payload'] == null ? null : jsonEncode(j['payload']),
          ),
          publishedAt: publishedAt,
        ),
      );
    } else {
      await (db.update(db.notifications)
        ..where((t) => t.id.equals(id)))
          .write(
        NotificationsCompanion(
          type: Value((j['type'] as String?) ?? existing.type),
          title: Value((j['title'] as String?) ?? existing.title),
          body: Value((j['body'] as String?) ?? existing.body),
          actionRoute: Value(j['actionRoute'] as String?),
          payloadJson: Value(
            j['payload'] == null ? null : jsonEncode(j['payload']),
          ),
          publishedAt: Value(publishedAt),
          fetchedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // READS
  // ═══════════════════════════════════════════════════════════════

  Stream<List<Notification>> watch() =>
      (db.select(db.notifications)
        ..where((t) => t.businessId.equals(businessId))
        ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
          .watch();

  Stream<int> watchUnreadCount() => (db.selectOnly(db.notifications)
    ..addColumns([db.notifications.id.count()])
    ..where(db.notifications.businessId.equals(businessId) &
    db.notifications.isRead.equals(false)))
      .map((row) => row.read(db.notifications.id.count()) ?? 0)
      .watchSingle();

  Future<int> getUnreadCount() async {
    final row = await (db.selectOnly(db.notifications)
      ..addColumns([db.notifications.id.count()])
      ..where(db.notifications.businessId.equals(businessId) &
      db.notifications.isRead.equals(false)))
        .getSingle();
    return row.read(db.notifications.id.count()) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // WRITES
  // ═══════════════════════════════════════════════════════════════

  Future<void> markAsRead(String id) async {
    await (db.update(db.notifications)..where((t) => t.id.equals(id)))
        .write(const NotificationsCompanion(isRead: Value(true)));
  }

  Future<void> markAllAsRead() async {
    await (db.update(db.notifications)
      ..where((t) =>
      t.businessId.equals(businessId) & t.isRead.equals(false)))
        .write(const NotificationsCompanion(isRead: Value(true)));
  }

  Future<void> clearAll() async {
    await (db.delete(db.notifications)
      ..where((t) => t.businessId.equals(businessId)))
        .go();
  }
}