import 'package:flutter/foundation.dart';

class User extends ChangeNotifier {
  static User? _currentUser;

  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;

  static void login(User user) {
    _currentUser = user;
  }

  static void logout() {
    _currentUser?.dispose();
    _currentUser = null;
  }

  final dynamic userId;
  final String? name;
  final String? email;
  final String? regDate;

  int _translationsCount = 0;
  int get translationsCount => _translationsCount;

  int _correctionsCount = 0;
  int get correctionsCount => _correctionsCount;

  bool statsLoaded = false;
  bool catsLoaded = false;

  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> get cats => _cats;

  void setCats(List<Map<String, dynamic>> newCats) {
    _cats = newCats;
    catsLoaded = true;
    notifyListeners();
  }

  void invalidateCats() {
    catsLoaded = false;
    _cats = [];
    notifyListeners();
  }

  void setStats({required int translations, required int corrections}) {
    _translationsCount = translations;
    _correctionsCount = corrections;
    statsLoaded = true;
    notifyListeners();
  }

  void incrementTranslations() {
    _translationsCount++;
    notifyListeners();
  }

  void incrementCorrections() {
    _correctionsCount++;
    notifyListeners();
  }

  User({this.userId, this.name, this.email, this.regDate});

  User.fromJson(Map<String, dynamic> json)
      : userId = json['userId'],
        name = json['name'],
        email = json['email'],
        regDate = json['regDate'];

  Map<String, dynamic> toJson() =>
      {'userId': userId, 'name': name, 'email': email, 'regDate': regDate};
}