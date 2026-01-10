import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/translation.dart';

class HistoryRecord {
  final String? id;
  final int? translationId;
  final int? catId;
  final Translation? translation;
  final Cat? cat;
  final String? textTranslation;

  HistoryRecord({
    this.id,
    this.translationId,
    this.catId,
    this.translation,
    this.cat,
    this.textTranslation,
  });

  HistoryRecord.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        translationId = json['translationId'],
        catId = json['catId'],
        translation = json['translation'] != null ? Translation.fromJson(json['translation']) : null,
        cat = json['cat'] != null ? Cat.fromJson(json['cat']) : null,
        textTranslation = json['textTranslation'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'translationId': translationId,
        'catId': catId,
        'textTranslation': textTranslation,
      };
}
