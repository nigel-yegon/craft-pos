import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class AuthProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  final _uuid = const Uuid();

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AuthProvider(this.db, this.businessId);

  /// Hash a PIN with SHA-256 + salt
  String _hashPin(String pin) {
    final bytes = utf8.encode('craft_pos_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  /// Create a new user (owner setup)
  Future<User?> createUser({
    required String name,
    required String pin,
    String role = 'owner',
  }) async {
    if (pin.length < 4) return null;

    try {
      final userId = _uuid.v4();
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: userId,
          businessId: businessId,
          name: name.trim(),
          pinHash: _hashPin(pin),
          role: drift.Value(role),
        ),
      );

      final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingle();
      _currentUser = user;
      notifyListeners();
      return user;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return null;
    }
  }

  /// Login with name + PIN
  Future<bool> login(String name, String pin) async {
    try {
      final users = await (db.select(db.users)
        ..where((u) => u.businessId.equals(businessId))
        ..where((u) => u.name.equals(name.trim()))
        ..where((u) => u.isActive.equals(true)))
          .get();

      if (users.isEmpty) return false;

      final user = users.first;
      if (user.pinHash == _hashPin(pin)) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Check if any users exist (for first-time setup)
  Future<bool> hasUsers() async {
    final users = await (db.select(db.users)..where((u) => u.businessId.equals(businessId))).get();
    return users.isNotEmpty;
  }

  /// Logout
  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }
}