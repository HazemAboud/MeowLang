import 'package:cloud_firestore/cloud_firestore.dart';

class Translation {
  final String? id;
  final String? audioPath;
  final String? imgPath;
  final String? className;
  final double? confidence;
  final DateTime? dateTime;

  Translation({
    this.id,
    required this.audioPath,
    this.imgPath,
    required this.className,
    required this.confidence,
    required this.dateTime,
  });

  factory Translation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Translation(
      id: doc.id,
      audioPath: data['audioPath'],
      imgPath: data['imgPath'],
      className: data['className'],
      confidence: (data['confidence'] as num?)?.toDouble(),
      dateTime: (data['datetime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }


  Map<String, dynamic> toJson() => {
        'audioPath': audioPath, 
        'imgPath': imgPath,
        'className': className,
        'confidence': confidence,
        'datetime': dateTime != null ? Timestamp.fromDate(dateTime!) : FieldValue.serverTimestamp(),
      };
}