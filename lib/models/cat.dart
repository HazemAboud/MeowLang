class Cat {
  final int? catId;
  final int? userId;
  final String name;
  final String breed;
  final String gender;
  final int age;
  final String? imgPath;

  Cat({
    this.catId,
    this.userId,
    required this.name,
    required this.breed,
    required this.gender,
    required this.age,
    this.imgPath,
  });

  Cat.fromJson(Map<String, dynamic> json)
      : catId = json['catId'] is int ? json['catId'] : int.tryParse(json['catId']?.toString() ?? ''),
        userId = json['userId'] is int ? json['userId'] : int.tryParse(json['userId']?.toString() ?? ''),
        name = json['name'] ?? 'Unknown',
        breed = json['breed'] ?? 'Unknown',
        gender = json['gender'] ?? 'Unknown',
        age = json['age'] ?? 0,
        imgPath = json['img_path']?.toString();

  Map<String, dynamic> toJson() {
    return {
      'catId': catId,
      'userId': userId,
      'name': name,
      'breed': breed,
      'gender': gender,
      'age': age,
      'img_path': imgPath,
    };
  }
}


class CatList{
  final List<Cat> cats;

  CatList({required this.cats});

  void add(Cat cat){
    cats.add(cat);
  }
}