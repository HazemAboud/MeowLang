import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/translation.dart';

class HistoryRecord {
  final String? id;
  final String? translationId;
  final int? catId;
  final Translation? translation;
  final Cat? cat;
  final String? textTranslation;
  final String? imgPath;
  /// when the translation was performed on the server (or locally if
  /// available). This comes from the joined `translations.datetime` column.
  final DateTime? translationDatetime;

  HistoryRecord({
    this.id,
    this.translationId,
    this.catId,
    this.translation,
    this.cat,
    this.textTranslation,
    this.imgPath,
    this.translationDatetime,
  });

  HistoryRecord.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString(),
        translationId = json['translationId']?.toString(),
        catId = json['catId'] is int ? json['catId'] : int.tryParse(json['catId']?.toString() ?? ''),
        translation = json['translation'] != null
            ? Translation.fromJson(json['translation'])
            : null,
        cat = json['cat'] != null ? Cat.fromJson(json['cat']) : null,
        textTranslation = json['textTranslation'],
        imgPath = json['imgPath']?.toString(),
        translationDatetime = json['translation_datetime'] != null
            ? DateTime.tryParse(json['translation_datetime'].toString())
            : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'translationId': translationId,
        'catId': catId,
        'textTranslation': textTranslation,
        // translationDatetime and imgPath are only added by join queries
        // and are not stored directly in the history table.
      };
}
