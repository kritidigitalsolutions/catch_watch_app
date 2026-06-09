import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class UserDetails extends HiveObject {
  @HiveField(0)
  String? name;

  @HiveField(1)
  String? email;

  @HiveField(2)
  String? image;

  @HiveField(3)
  String? token;

  @HiveField(4)
  String? phone;

  @HiveField(5)
  int? createdAt;

  @HiveField(6)
  List<String>? favoriteSports;

  @HiveField(7)
  bool? isNewUser;

  @HiveField(8)
  String? sId;

  UserDetails({
    this.name,
    this.email,
    this.image,
    this.token,
    this.phone,
    this.createdAt,
    this.favoriteSports,
    this.isNewUser,
    this.sId,
  });
}
