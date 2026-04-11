import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/translation.dart';

class HistoryRecord {
  final String? id;
  final String? translationId;
  final String? catId;
  final String? userId; // Added userId for easier querying
  final Translation? translation;
  final Cat? cat;
  final String? textTranslation;
  final String? imgPath;
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
    this.imgPath,
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
      imgPath: data['imgPath'],
      catName: data['catName'],
      translationDatetime: (data['hist_time'] as Timestamp?)?.toDate(),
    );
  }

  HistoryRecord.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString(),
        translationId = json['translationId']?.toString(),
        catId = json['catId']?.toString(),
        userId = json['userId']?.toString(), // Read userId from JSON
        translation = json['translation'] != null
            ? Translation.fromJson(json['translation'])
            : null,
        cat = json['cat'] != null ? Cat.fromJson(json['cat']) : null,
        textTranslation = json['textTranslation'],
        imgPath = json['imgPath']?.toString(),
        translationDatetime = json['translation_datetime'] != null
            ? DateTime.tryParse(json['translation_datetime'].toString())
            : null,
        catName = json['catName']?.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'translationId': translationId,
        'userId': userId, // Include userId in JSON for saving
        'catId': catId,
        'textTranslation': textTranslation,
        'imgPath': imgPath,
        'catName': catName,
        'hist_time': translationDatetime != null 
            ? Timestamp.fromDate(translationDatetime!) 
            : FieldValue.serverTimestamp(),
      };
}
