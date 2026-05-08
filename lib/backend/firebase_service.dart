import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/cat.dart';
import '../models/historyRecord.dart';
import '../models/translation.dart';
import '../tabs/password_helper.dart';

// handles firebase operations
class FirebaseService {
  // firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'meowlang',
  );

  final Random _random = Random();
  
  // generates a unique numeric id
  String _generateNumericId() {
    // combines timestamp with random digits
    return '${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(90000) + 10000}';
  }
  
  // exposes firestore collection method
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _db.collection(path);
  }
  
  /// Logs AI inference performance to the 'translation_performance' collection.
  Future<void> logInferencePerformance(double timeMs, String phoneModel) async {
    try {
      final id = _generateNumericId();
      await _db.collection('translation_performance').doc(id).set({
        'execution_time_ms': timeMs,
        'phone_model': phoneModel,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log("Could not log translation performance: $e");
    }
  }

  // auth logic
  
  // performs manual login
  Future<Map<String, dynamic>?> login(String identifier, String password) async {
    // login by email or name
    final field = identifier.contains('@') ? 'email' : 'name';

    final hashedPassword = PasswordHelper.hashPassword(password);
    
    final query = await _db.collection('users')
        .where(field, isEqualTo: identifier)
        .where('password', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final userData = query.docs.first.data();
      userData['uid'] = query.docs.first.id; // maps document id to uid
      return userData;
    }
    return null;
  }
  
  // registers a user
  Future<Map<String, dynamic>?> register(String name, String email, String password) async {
    // checks if user exists
    final existing = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (existing.docs.isNotEmpty) throw Exception("User with this email already exists");
    
    final newUser = {
      'name': name,
      'email': email,
      'password': PasswordHelper.hashPassword(password), // Basic manual storage
      'regDate': FieldValue.serverTimestamp(),
    };

    final id = _generateNumericId();
    final docRef = _db.collection('users').doc(id);
    await docRef.set(newUser);
    
    newUser['uid'] = id;
    return newUser;
  }

  // cat crud
  
  // returns a stream of user's cats
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
          } // errors propagated to streambuilder
        })
        .handleError((error) {
          debugPrint('[streamCats] Stream error for userId $userId: $error');
          // use with streambuilder
          throw error;
        });
  }
  
  // retrieves list of user's cats
  Future<List<Cat>> getCats(String userId) async {
    final snapshot = await _db
        .collection('cats')
        .where('userId', isEqualTo: userId)
        .get();
    
    return snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
  }

  Future<Cat> createCat(Cat cat) async {
    final id = _generateNumericId();
    final docRef = _db.collection('cats').doc(id);
    await docRef.set(cat.toJson());
    final newDoc = await docRef.get();
    
    return Cat.fromFirestore(newDoc);
  }

  Future<void> updateCat(String catId, Map<String, dynamic> data) async {
    await _db.collection('cats').doc(catId).update(data);
  }

  // verifies cat update
  Future<bool> verifyCatUpdate(String catId, Map<String, dynamic> expectedData) async {
    try {
      final updatedDoc = await _db.collection('cats').doc(catId).get();
      if (!updatedDoc.exists) return false;
      
      final docData = updatedDoc.data() ?? {};
      // verifies key fields match
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
    await _db.collection('cats').doc(catId).delete();
  }

  Future<bool> verifyCatDeletion(String catId) async {
    try {
      final doc = await _db.collection('cats').doc(catId).get();
      return !doc.exists;
    } catch (e) {
      debugPrint('Error verifying cat deletion: $e');
      return false;
    }
  }

  // --- History & Translations ---
  Future<List<HistoryRecord>> getHistoryForCat(String catId) async {
    final snapshot = await _db
        .collection('history')
        .where('catId', isEqualTo: catId)
        .orderBy('hist_time', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => HistoryRecord.fromFirestore(doc)).toList();
  }

  Future<List<HistoryRecord>> getHistoryForUser(String userId) async {
    // gets ids of user's cats
    final catSnap = await _db.collection('cats').where('userId', isEqualTo: userId).get();
    final catIds = catSnap.docs.map((d) => d.id).toList();
    
    // no history if no cats
    if (catIds.isEmpty) return [];

    final histSnap = await _db
        .collection('history')
        .where('catId', whereIn: catIds)
        .orderBy('hist_time', descending: true)
        .get();

    return histSnap.docs.map((doc) => HistoryRecord.fromFirestore(doc)).toList();
  }

  Future<void> saveHistory(HistoryRecord history, {String? catName, String? imgPath, required String userId}) async {
    final data = history.toJson();
    // denormalizes data
    data['userId'] = userId;
    if (catName != null) data['catName'] = catName;
    if (imgPath != null) data['imgPath'] = imgPath;
    
    final histId = _generateNumericId();
    await _db.collection('history').doc(histId).set(data);
  }

  Stream<int> streamUserTranslationCount(String userId) {
    return _db
        .collection('history')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  } 

  Stream<int> streamUserCorrectionCount(String userId) {
    return _db
        .collection('corrections')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String> saveTranslation(Translation translation) async {
    final id = _generateNumericId();
    await _db.collection('translations').doc(id).set(translation.toJson());
    return id;
  }

  Future<Map<String, int>> getUserStats(String userId) async {
    // gets translation count for user's cats
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
    
    // gets correction count for user
    final corrCountQuery = await _db
        .collection('corrections')
        .where('user_id', isEqualTo: userId)
        .count()
        .get();
    int correctionsCount = corrCountQuery.count ?? 0;

    return {
      "translations": translationsCount,
      "corrections": correctionsCount,
    };
  }
  
  Future<void> saveFeedback({
    required String translationId,
    required String newLabel,
    required String userId,
    String? catId,
  }) async {
    final transDoc = await _db.collection('translations').doc(translationId).get();
    if (!transDoc.exists) throw Exception("Original translation not found");

    final translation = Translation.fromFirestore(transDoc);

    final id = _generateNumericId();
    await _db.collection('corrections').doc(id).set({
      'translationId': translationId,
      'image_path': translation.imgPath,
      'old_label': translation.className,
      'old_conf': translation.confidence,
      'new_label': newLabel,
      'user_id': userId,
      'catId': catId, 
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}