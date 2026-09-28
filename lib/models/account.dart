import 'package:hive/hive.dart';

class Account {
  final String id;
  String name;
  String type; // cash | bank | jazzcash | easypaisa | other
  double balance;
  int color; // ARGB
  String icon; // key into kAppIcons
  final DateTime createdAt;
  String currency; // ISO 4217 code, e.g. 'PKR' (mutable)

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.currency = 'PKR',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'color': color,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
        'currency': currency,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        balance: (j['balance'] as num).toDouble(),
        color: j['color'] as int,
        icon: j['icon'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        currency: (j['currency'] as String?) ?? 'PKR',
      );
}

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 0;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      balance: fields[3] as double,
      color: fields[4] as int,
      icon: fields[5] as String,
      createdAt: fields[6] as DateTime,
      currency: fields[7] as String? ?? 'PKR',
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.balance)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.currency);
  }
}
