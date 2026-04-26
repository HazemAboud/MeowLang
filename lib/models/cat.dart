import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  final String? catId;
  final String? userId;
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

  factory Cat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cat(
      catId: doc.id,
      userId: data['userId']?.toString(),
      name: data['name'] ?? 'Unknown',
      breed: data['breed'] ?? 'Unknown',
      gender: data['gender'] ?? 'Unknown',
      age: data['age'] ?? 0,
      imgPath: data['img_path']?.toString(),
    );
  }


  Map<String, dynamic> toJson() {
    return {
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