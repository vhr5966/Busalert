/// Repository for journey records using Cloud Firestore.
///
/// Handles:
/// - Submitting completed journeys to Firestore
/// - Fetching journey history for the logged-in user
/// - Firestore handles offline persistence natively (no manual queue needed)
///
/// Firestore's built-in offline support means queued writes are automatically
/// synced when connectivity returns, replacing the manual SharedPreferences
/// queue used in the previous REST API version.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants.dart';
import '../../core/error_handler.dart';
import '../models/journey.dart';

class JourneyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a journey record to Firestore.
  ///
  /// Firestore automatically handles offline persistence — if the device
  /// is offline, the write is queued locally and synced when connectivity
  /// returns. This replaces the manual SharedPreferences queue used in
  /// the previous REST API version.
  Future<void> submitJourney(Journey journey) async {
    try {
      await _firestore.collection(kJourneysCollection).add(journey.toJson());
    } catch (e) {
      throw parseError(e);
    }
  }

  /// Fetches the logged-in user's journey history from Firestore.
  ///
  /// Returns the 100 most recent journeys, ordered by boarding time.
  Future<List<Journey>> getHistory() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw const AppError(userMessage: 'User not authenticated.');
      }
      // Use the UID hashCode for consistent int-based queries matching
      // the Journey model's userId field.
      final userId = firebaseUser.uid.hashCode;

      final querySnapshot = await _firestore
          .collection(kJourneysCollection)
          .where('user_id', isEqualTo: userId)
          .orderBy('boarding_time', descending: true)
          .limit(100)
          .get();

      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Firestore document ID
            return Journey.fromJson(data);
          })
          .toList();
    } catch (e) {
      if (e is AppError) rethrow;
      throw parseError(e);
    }
  }
}
