import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrapService {
  bool _initializationAttempted = false;
  bool _isAvailable = false;
  String? _cachedToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get isAvailable => _isAvailable;
  String? get cachedToken => _cachedToken;

  Future<bool> ensureInitialized() async {
    if (_initializationAttempted) return _isAvailable;
    _initializationAttempted = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
    }

    return _isAvailable;
  }

  Future<String?> enableMessaging({required bool requestPermission}) async {
    if (!await ensureInitialized()) return null;
    if (!_supportsMessaging) return null;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      if (requestPermission) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final authorized =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (!authorized) return null;
      }

      _cachedToken = await messaging.getToken();
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        _cachedToken = token;
      });
      return _cachedToken;
    } catch (_) {
      return null;
    }
  }

  bool get _supportsMessaging {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
