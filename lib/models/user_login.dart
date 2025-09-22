import 'package:hive/hive.dart';

part 'user_login.g.dart';

@HiveType(typeId: 0)
class UserLogin extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String email;

  @HiveField(2)
  String? name;

  UserLogin({required this.userId, required this.email, this.name});
}
