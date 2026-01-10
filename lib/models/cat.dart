class Cat {
  final int? catId;
  final String name;
  final String breed;
  final String gender;
  final int age;

  Cat({
    this.catId,
    required this.name,
    required this.breed,
    required this.gender,
    required this.age,
  });

  Cat.fromJson(Map<String, dynamic> json)
      : catId = json['CatId'],
        name = json['name'] ?? 'Unknown',
        breed = json['breed'] ?? 'Unknown',
        gender = json['gender'] ?? 'Unknown',
        age = json['age'] ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'CatId': catId,
      'name': name,
      'breed': breed,
      'gender': gender,
      'age': age,
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