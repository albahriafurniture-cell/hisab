import 'package:hive/hive.dart';

class Budget {
  final String id;
  String categoryId;
  double monthlyLimit;
  String monthKey; // "yyyy-MM"

  Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.monthKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'monthlyLimit': monthlyLimit,
        'monthKey': monthKey,
      };

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        monthlyLimit: (j['monthlyLimit'] as num).toDouble(),
        monthKey: j['monthKey'] as String,
      );
}

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 3;

  @override
  Budget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Budget(
      id: fields[0] as String,
      categoryId: fields[1] as String,
      monthlyLimit: fields[2] as double,
      monthKey: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.monthlyLimit)
      ..writeByte(3)
      ..write(obj.monthKey);
  }
}
