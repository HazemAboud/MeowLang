class User {
  static User? _currentUser;

  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;

  static void login(User user) => _currentUser = user;
  static void logout() => _currentUser = null;

  final dynamic userId;
  final String? name;
  final String? email;
  final String? regDate;

  User({this.userId, this.name, this.email, this.regDate});

  User.fromJson(Map<String, dynamic> json)
      : userId = json['userId'],
        name = json['name'],
        email = json['email'],
        regDate = json['regDate'];

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'regDate': regDate
      };
}