import 'package:hive/hive.dart';

class Recurring {
  final String id;
  String title;
  double amount;
  String kind; // income | expense
  String categoryId;
  String accountId;
  int dayOfMonth; // 1..28
  bool active;
  String? lastPostedKey; // "yyyy-MM" or null

  Recurring({
    required this.id,
    required this.title,
    required this.amount,
    required this.kind,
    required this.categoryId,
    required this.accountId,
    required this.dayOfMonth,
    required this.active,
    this.lastPostedKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'kind': kind,
        'categoryId': categoryId,
        'accountId': accountId,
        'dayOfMonth': dayOfMonth,
        'active': active,
        'lastPostedKey': lastPostedKey,
      };

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        kind: j['kind'] as String,
        categoryId: j['categoryId'] as String,
        accountId: j['accountId'] as String,
        dayOfMonth: j['dayOfMonth'] as int,
        active: j['active'] as bool,
        lastPostedKey: j['lastPostedKey'] as String?,
      );
}

class RecurringAdapter extends TypeAdapter<Recurring> {
  @override
  final int typeId = 4;

  @override
  Recurring read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recurring(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      kind: fields[3] as String,
      categoryId: fields[4] as String,
      accountId: fields[5] as String,
      dayOfMonth: fields[6] as int,
      active: fields[7] as bool,
      lastPostedKey: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Recurring obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.kind)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.accountId)
      ..writeByte(6)
      ..write(obj.dayOfMonth)
      ..writeByte(7)
      ..write(obj.active)
      ..writeByte(8)
      ..write(obj.lastPostedKey);
  }
}
