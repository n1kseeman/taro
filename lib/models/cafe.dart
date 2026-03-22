class Cafe {
  final String id;
  final String name;
  final String address;

  // логин/пароль админа именно этой кофейни (локально, позже заменим на backend)
  final String adminLogin;
  final String adminPasswordHash; // sha256

  const Cafe({
    required this.id,
    required this.name,
    required this.address,
    required this.adminLogin,
    required this.adminPasswordHash,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "address": address,
    "adminLogin": adminLogin,
    "adminPasswordHash": adminPasswordHash,
  };

  static Cafe fromJson(Map<String, dynamic> json) => Cafe(
    id: json["id"],
    name: json["name"],
    address: json["address"],
    adminLogin: json["adminLogin"],
    adminPasswordHash: json["adminPasswordHash"],
  );
}
