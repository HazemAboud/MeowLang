import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/cat.dart';
import '../models/historyRecord.dart';
import '../models/translation.dart';

/// Service class to handle all Firebase database operations using manual login logic.
class FirebaseService {
  // Using the "meowlang" Firestore database instance configured in firebase.json
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'meowlang',
  );

  /// Exposes the collection method from the underlying Firestore instance.
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _db.collection(path);
  }

  // Performance Logging Helper (Consistent with original Python implementation)
  Future<void> _logPerformance(String endpoint, String queryName, double timeMs) async {
    try {
      await _db.collection('query_performance').add({
        'endpoint': endpoint,
        'query_name': queryName,
        'execution_time_ms': timeMs,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log("Could not log query performance: $e");
    }
  }

  // --- Auth Logic ---

  /// Performs a manual login by checking the users collection for matching credentials.
  Future<Map<String, dynamic>?> login(String identifier, String password) async {
    final stopwatch = Stopwatch()..start();

    // Try login by email OR by name
    final field = identifier.contains('@') ? 'email' : 'name';
    
    final query = await _db.collection('users')
        .where(field, isEqualTo: identifier)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    _logPerformance('/login', 'manual_auth_query', stopwatch.elapsedMilliseconds.toDouble());

    if (query.docs.isNotEmpty) {
      final userData = query.docs.first.data();
      userData['uid'] = query.docs.first.id; // Map document ID to uid for consistency
      return userData;
    }
    return null;
  }

  /// Manually registers a user by creating a document in the users collection.
  Future<Map<String, dynamic>?> register(String name, String email, String password) async {
    final stopwatch = Stopwatch()..start();
    
    // Check if user already exists
    final existing = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (existing.docs.isNotEmpty) throw Exception("User with this email already exists");

    final newUser = {
      'name': name,
      'email': email,
      'password': password, // Basic manual storage
      'regDate': FieldValue.serverTimestamp(),
    };

    final docRef = await _db.collection('users').add(newUser);
    
    _logPerformance('/register', 'insert_user', stopwatch.elapsedMilliseconds.toDouble());
    newUser['uid'] = docRef.id;
    return newUser;
  }

  // --- Cat CRUD ---

  /// Returns a real-time stream of cats owned by the user.
  /// Use this with a StreamBuilder in your UI to update automatically.
  /// Errors are propagated to the StreamBuilder for UI handling.
  Stream<List<Cat>> streamCats(String userId) {
    return _db
        .collection('cats')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
          } catch (e) {
            debugPrint('[streamCats] Error mapping snapshot: $e');
            rethrow;
          }
        })
        .handleError((error) {
          debugPrint('[streamCats] Stream error for userId $userId: $error');
          // Don't suppress the error - let it propagate to StreamBuilder
          throw error;
        });
  }

  /// Retrieves a list of cats owned by the user (non-streaming).
  Future<List<Cat>> getCats(String userId) async {
    final snapshot = await _db
        .collection('cats')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
  }

  Future<Cat> createCat(Cat cat) async {
    final stopwatch = Stopwatch()..start();
    final docRef = await _db.collection('cats').add(cat.toJson());
    final newDoc = await docRef.get();
    
    _logPerformance('/cats', 'insert_cat', stopwatch.elapsedMilliseconds.toDouble());
    return Cat.fromFirestore(newDoc);
  }

  Future<void> updateCat(String catId, Map<String, dynamic> data) async {
    final stopwatch = Stopwatch()..start();
    await _db.collection('cats').doc(catId).update(data);
    _logPerformance('/cats/$catId', 'update_cat', stopwatch.elapsedMilliseconds.toDouble());
  }

  /// Verifies that the update was actually applied to Firestore
  Future<bool> verifyCatUpdate(String catId, Map<String, dynamic> expectedData) async {
    try {
      final updatedDoc = await _db.collection('cats').doc(catId).get();
      if (!updatedDoc.exists) return false;
      
      final docData = updatedDoc.data() ?? {};
      // Verify that at least the key fields match
      for (final key in expectedData.keys) {
        if (docData[key] != expectedData[key]) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error verifying cat update: $e');
      return false;
    }
  }

  Future<void> deleteCat(String catId) async {
    final stopwatch = Stopwatch()..start();
    await _db.collection('cats').doc(catId).delete();
    _logPerformance('/cats/$catId', 'delete_cat', stopwatch.elapsedMilliseconds.toDouble());
  }

  /// Verifies that the deletion was actually applied to Firestore
  Future<bool> verifyCatDeletion(String catId) async {
    try {
      final doc = await _db.collection('cats').doc(catId).get();
      return !doc.exists; // Should not exist if deletion was successful
    } catch (e) {
      debugPrint('Error verifying cat deletion: $e');
      return false;
    }
  }

  // --- History & Translations ---

  Future<List<HistoryRecord>> getHistoryForCat(String catId) async {
    final stopwatch = Stopwatch()..start();
    final snapshot = await _db
        .collection('history')
        .where('catId', isEqualTo: catId)
        .orderBy('hist_time', descending: true)
        .get();
    
    _logPerformance('/history/$catId', 'get_cat_history', stopwatch.elapsedMilliseconds.toDouble());
    return snapshot.docs.map((doc) => HistoryRecord.fromFirestore(doc)).toList();
  }

  Future<List<HistoryRecord>> getHistoryForUser(String userId) async {
    final stopwatch = Stopwatch()..start();
    
    // 1. Get IDs of all cats owned by the user
    final catSnap = await _db.collection('cats').where('userId', isEqualTo: userId).get();
    final catIds = catSnap.docs.map((d) => d.id).toList();

    // If the user has no cats, they cannot have history records.
    // Firestore 'whereIn' will throw an error if the list is empty.
    if (catIds.isEmpty) return [];

    // 2. Fetch history where catId is in the user's cat list
    final histSnap = await _db
        .collection('history')
        .where('catId', whereIn: catIds)
        .orderBy('hist_time', descending: true)
        .get();

    _logPerformance('/history/user/$userId', 'get_user_history_by_cat_ids', stopwatch.elapsedMilliseconds.toDouble());
    return histSnap.docs.map((doc) => HistoryRecord.fromFirestore(doc)).toList();
  }

  Future<void> saveHistory(HistoryRecord history, {String? catName, String? imgPath, required String userId}) async {
    final stopwatch = Stopwatch()..start();
    final data = history.toJson();
    // Denormalize data for easy display in lists
    data['userId'] = userId; // Add userId to history record
    if (catName != null) data['catName'] = catName;
    if (imgPath != null) data['imgPath'] = imgPath;
    
    await _db.collection('history').add(data);
    _logPerformance('/history', 'insert_history', stopwatch.elapsedMilliseconds.toDouble());
  }

  /// Streams the translation count for a specific user.
  Stream<int> streamUserTranslationCount(String userId) {
    return _db
        .collection('history')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Streams the correction count for a specific user.
  Stream<int> streamUserCorrectionCount(String userId) {
    return _db
        .collection('corrections')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String> saveTranslation(Translation translation) async {
    final stopwatch = Stopwatch()..start();
    final docRef = await _db.collection('translations').add(translation.toJson());
    _logPerformance('/convert', 'insert_translation', stopwatch.elapsedMilliseconds.toDouble());
    return docRef.id;
  }

  // --- Stats & Feedback ---

  Future<Map<String, int>> getUserStats(String userId) async {
    final stopwatch = Stopwatch()..start();

    // Get Translation count across all user's cats
    final catsSnap = await _db.collection('cats').where('userId', isEqualTo: userId).get();
    final catIds = catsSnap.docs.map((d) => d.id).toList();
    
    int translationsCount = 0;
    if (catIds.isNotEmpty) {
      final transCountQuery = await _db
          .collection('history')
          .where('catId', whereIn: catIds)
          .count()
          .get();
      translationsCount = transCountQuery.count ?? 0;
    }

    // Get Correction count for this user
    final corrCountQuery = await _db
        .collection('corrections')
        .where('user_id', isEqualTo: userId)
        .count()
        .get();
    int correctionsCount = corrCountQuery.count ?? 0;

    _logPerformance('/users/$userId/stats', 'get_user_stats', stopwatch.elapsedMilliseconds.toDouble());
    return {
      "translations": translationsCount,
      "corrections": correctionsCount,
    };
  }

  Future<void> saveFeedback({
    required String translationId,
    required String newLabel,
    required String userId,
    String? catId, // Added to strengthen the relation
  }) async {
    final stopwatch = Stopwatch()..start();
    
    final transDoc = await _db.collection('translations').doc(translationId).get();
    if (!transDoc.exists) throw Exception("Original translation not found");

    final translation = Translation.fromFirestore(transDoc);

    await _db.collection('corrections').add({
      'translationId': translationId,
      'image_path': translation.imgPath, // Assumes URL or Storage path
      'old_label': translation.className,
      'old_conf': translation.confidence,
      'new_label': newLabel,
      'user_id': userId,
      'catId': catId, 
      'timestamp': FieldValue.serverTimestamp(),
    });

    _logPerformance('/feedback', 'insert_correction', stopwatch.elapsedMilliseconds.toDouble());
  }
}