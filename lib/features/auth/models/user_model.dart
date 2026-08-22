class UserModel {
  final int id;
  final String name;
  final String phone;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String token) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'] ?? '',
      token: token,
    );
  }
}
