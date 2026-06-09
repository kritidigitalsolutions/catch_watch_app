import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:hive/hive.dart';

class UserDetailsAdapter extends TypeAdapter<UserDetails> {
  @override
  final int typeId = 0;

  @override
  UserDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();

    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };

    return UserDetails(
      name: fields[0] as String?,
      email: fields[1] as String?,
      image: fields[2] as String?,
      token: fields[3] as String?,
      phone: fields[4] as String?,
      createdAt: fields[5] as int?,
      favoriteSports: (fields[6] as List?)?.cast<String>(),
      isNewUser: fields[7] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, UserDetails obj) {
    writer
      ..writeByte(8) // ✅ total fields = 8

      ..writeByte(0)
      ..write(obj.name)

      ..writeByte(1)
      ..write(obj.email)

      ..writeByte(2)
      ..write(obj.image)

      ..writeByte(3)
      ..write(obj.token)

      ..writeByte(4)
      ..write(obj.phone)

      ..writeByte(5)
      ..write(obj.createdAt)

      ..writeByte(6)
      ..write(obj.favoriteSports)

      ..writeByte(7)
      ..write(obj.isNewUser);
  }
}
