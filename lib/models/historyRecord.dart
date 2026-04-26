import 'package:cloud_firestore/cloud_firestore.dart';
import 'cat.dart';
import 'translation.dart';

class HistoryRecord {
  final String? id;
  final String? translationId;
  final String? catId;
  final String? userId; // Added userId for easier querying
  final Translation? translation;
  final Cat? cat;
  final String? textTranslation;
  /// when the translation was performed on the server (or locally if
  /// available). This comes from the joined `translations.datetime` column.
  final DateTime? translationDatetime;
  final String? catName;

  HistoryRecord({
    this.id,
    this.translationId,
    this.userId,
    this.catId,
    this.translation,
    this.cat,
    this.textTranslation,
    this.translationDatetime,
    this.catName,
  });

  factory HistoryRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HistoryRecord(
      id: doc.id,
      translationId: data['translationId']?.toString(),
      userId: data['userId']?.toString(), // Read userId from Firestore
      catId: data['catId']?.toString(),
      textTranslation: data['textTranslation'],
      catName: data['catName'],
      translationDatetime: (data['hist_time'] as Timestamp?)?.toDate(),
    );
  }



  Map<String, dynamic> toJson() => {
        'translationId': translationId,
        'userId': userId, // Include userId in JSON for saving
        'catId': catId,
        'textTranslation': textTranslation,
        'catName': catName,
        'hist_time': translationDatetime != null 
            ? Timestamp.fromDate(translationDatetime!) 
            : FieldValue.serverTimestamp(),
      };
}
