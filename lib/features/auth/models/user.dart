class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final bool isEmailVerified;
  final DateTime createdAt;
  final String? country;
  final String? city;
  final String? address;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    required this.isEmailVerified,
    required this.createdAt,
    this.country,
    this.city,
    this.address,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      phoneNumber: json['phoneNumber'],
      profileImageUrl: json['profileImageUrl'],
      isEmailVerified: json['isEmailVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      country: json['country'],
      city: json['city'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
      'country': country,
      'city': city,
      'address': address,
    };
  }
}