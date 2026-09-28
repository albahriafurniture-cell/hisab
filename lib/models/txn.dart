import 'package:hive/hive.dart';

class Txn {
  final String id;
  double amount;
  String kind; // income | expense
  String categoryId;
  String accountId;
  DateTime date;
  String note;
  final DateTime createdAt;
  DateTime updatedAt;

  Txn({
    required this.id,
    required this.amount,
    required this.kind,
    required this.categoryId,
    required this.accountId,
    required this.date,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'kind': kind,
        'categoryId': categoryId,
        'accountId': accountId,
        'date': date.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        kind: j['kind'] as String,
        categoryId: j['categoryId'] as String,
        accountId: j['accountId'] as String,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class TxnAdapter extends TypeAdapter<Txn> {
  @override
  final int typeId = 2;

  @override
  Txn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Txn(
      id: fields[0] as String,
      amount: fields[1] as double,
      kind: fields[2] as String,
      categoryId: fields[3] as String,
      accountId: fields[4] as String,
      date: fields[5] as DateTime,
      note: fields[6] as String,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Txn obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
