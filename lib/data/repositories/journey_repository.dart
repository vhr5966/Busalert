/// Repository for journey records.
///
/// When Firebase is available, uses Cloud Firestore for cloud sync.
/// When Firebase is not available, saves journeys locally using SharedPreferences.
/// Uses a stable device-based user ID for both cases.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/constants.dart';
import '../../core/device_id.dart';
import '../../features/auth/services/auth_service.dart';
import '../../main.dart';
import '../../core/error_handler.dart';
import '../models/journey.dart';

class JourneyRepository {
  final AuthService _authService = AuthService();

  FirebaseFirestore? get _firestore => firebaseAvailable
      ? FirebaseFirestore.instance
      : null;

  /// Submits a completed journey.
  ///
  /// If authenticated, sends to Node.js backend.
  /// If Firebase is available, saves to Firestore.
  /// Otherwise, saves locally using SharedPreferences.
  Future<void> submitJourney(Journey journey) async {
    // 1. Try Node.js backend if user is authenticated
    try {
      final user = await _authService.getSavedUser();
      if (user != null && user.token != null) {
        final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/journeys');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user.token}',
          },
          body: jsonEncode(journey.toJson()),
        );

        if (response.statusCode == 201) {
          debugPrint('🌐 Journey saved to Node.js backend');
          await _saveJourneyLocally(journey);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Node.js journey submit error: $e');
    }

    // 2. Fallback to Firestore / Local Storage
    try {
      final firestore = _firestore;
      if (firestore != null && firebaseAvailable) {
        // Save to Firestore
        await firestore.collection(kJourneysCollection).add(journey.toJson());
        debugPrint('✅ Journey saved to Firestore');
      } else {
        // Save locally
        await _saveJourneyLocally(journey);
        debugPrint('📱 Journey saved locally');
      }
    } catch (e) {
      // If Firestore fails, save locally as fallback
      try {
        await _saveJourneyLocally(journey);
        debugPrint('📱 Journey saved locally (Firestore failed)');
      } catch (localError) {
        throw parseError(e);
      }
    }
  }

  /// Fetches this device/user's journey history.
  Future<List<Journey>> getHistory() async {
    // 1. Try Node.js backend if authenticated
    try {
      final user = await _authService.getSavedUser();
      if (user != null && user.token != null) {
        final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/journeys/history');
        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer ${user.token}',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list
              .map((item) => Journey.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Node.js getHistory error: $e');
    }

    // 2. Fallback to Firestore / Local storage
    try {
      final firestore = _firestore;
      if (firestore != null && firebaseAvailable) {
        // Fetch from Firestore
        final userId = await DeviceIdService.getDeviceUserId();

        final querySnapshot = await firestore
            .collection(kJourneysCollection)
            .where('user_id', isEqualTo: userId)
            .orderBy('boarding_time', descending: true)
            .limit(100)
            .get();

        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Journey.fromJson(data);
        }).toList();
      } else {
        // Fetch from local storage
        return await _getJourneysLocally();
      }
    } catch (e) {
      // If Firestore fails, try local storage
      try {
        return await _getJourneysLocally();
      } catch (localError) {
        if (e is AppError) rethrow;
        throw parseError(e);
      }
    }
  }

  /// Saves a journey to local storage.
  Future<void> _saveJourneyLocally(Journey journey) async {
    final prefs = await SharedPreferences.getInstance();
    final journeys = await _getJourneysLocally();
    
    // Add new journey at the beginning
    journeys.insert(0, journey);
    
    // Keep only the last 100 journeys
    final trimmedJourneys = journeys.take(100).toList();
    
    // Save as JSON
    final journeysJson = trimmedJourneys.map((j) => j.toJson()).toList();
    await prefs.setString('local_journeys', jsonEncode(journeysJson));
  }

  /// Fetches journeys from local storage.
  Future<List<Journey>> _getJourneysLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final journeysJson = prefs.getString('local_journeys');
    
    if (journeysJson == null || journeysJson.isEmpty) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(journeysJson);
    return decoded.map((json) => Journey.fromJson(json as Map<String, dynamic>)).toList();
  }
}
