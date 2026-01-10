class User {
  final int? userId;
  final String? name;
  final String? email;
  final String? regDate;

  User({this.userId, this.name, this.email, this.regDate});



  User.fromJson(Map<String, dynamic> json)
      : userId = json['userId'],
        name = json['name'],
        email = json['email'],
        regDate = json['regDate'];

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'email': email, 'regDate': regDate};  
}