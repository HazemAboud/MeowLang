class Translation {
  final int? id;
  final String? audioPath;
  final String? className;
  final double? confidence;
  final DateTime? dateTime;

  Translation({
    this.id,
    required this.audioPath,
    required this.className,
    required this.confidence,
    required this.dateTime,
  });

  Translation.fromJson(Map<String, dynamic> json)
      : id = json['translationId'],
        audioPath = json['audioPath'],
        className = json['className'],
        confidence = (json['confidence'] as num).toDouble(),
        dateTime = DateTime.parse(json['datetime']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioPath': audioPath, 
        'className': className,
        'confidence': confidence,
        'datetime': dateTime.toString(),
      };
}