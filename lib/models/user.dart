class AppUser {
  final String id;
  final String email;
  final String passwordHash; // sha256
  final String firstName;
  final String lastName;
  final String phone;
  final String? photoDataUri;
  final String? gender;
  final String? birthDateIso;
  final bool notificationsEnabled;

  const AppUser({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.firstName,
    this.lastName = "",
    this.phone = "",
    this.photoDataUri,
    this.gender,
    this.birthDateIso,
    this.notificationsEnabled = false,
  });

  String get name {
    final full = "$firstName $lastName".trim();
    return full.isEmpty ? email : full;
  }

  DateTime? get birthDate {
    final value = birthDateIso;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  AppUser copyWith({
    String? email,
    String? passwordHash,
    String? firstName,
    String? lastName,
    String? phone,
    Object? photoDataUri = _sentinel,
    String? gender,
    Object? birthDateIso = _sentinel,
    bool? notificationsEnabled,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      photoDataUri: identical(photoDataUri, _sentinel)
          ? this.photoDataUri
          : photoDataUri as String?,
      gender: gender ?? this.gender,
      birthDateIso: identical(birthDateIso, _sentinel)
          ? this.birthDateIso
          : birthDateIso as String?,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "passwordHash": passwordHash,
    "firstName": firstName,
    "lastName": lastName,
    "phone": phone,
    "photoDataUri": photoDataUri,
    "gender": gender,
    "birthDateIso": birthDateIso,
    "notificationsEnabled": notificationsEnabled,
  };

  static AppUser fromJson(Map<String, dynamic> j) => AppUser(
    id: j["id"],
    email: j["email"],
    passwordHash: j["passwordHash"],
    firstName: (j["firstName"] ?? j["name"] ?? "") as String,
    lastName: (j["lastName"] ?? "") as String,
    phone: (j["phone"] ?? "") as String,
    photoDataUri: j["photoDataUri"] as String?,
    gender: j["gender"] as String?,
    birthDateIso: j["birthDateIso"] as String?,
    notificationsEnabled: (j["notificationsEnabled"] ?? false) == true,
  );
}

const _sentinel = Object();
