import 'package:hive/hive.dart';

/// A savings goal: track progress toward a target amount, optionally moving
/// money in/out of an account so balances stay in sync.
class Goal {
  final String id;
  String title;
  double targetAmount;
  double savedAmount;
  DateTime? deadline;
  int color; // ARGB
  String icon; // key into kAppIcons (see utils/icons.dart)
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'deadline': deadline?.toIso8601String(),
        'color': color,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String,
        targetAmount: (j['targetAmount'] as num).toDouble(),
        savedAmount: (j['savedAmount'] as num?)?.toDouble() ?? 0,
        deadline: j['deadline'] != null
            ? DateTime.parse(j['deadline'] as String)
            : null,
        color: (j['color'] as num).toInt(),
        icon: j['icon'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 5;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      targetAmount: fields[2] as double,
      savedAmount: fields[3] as double,
      deadline: fields[4] as DateTime?,
      color: fields[5] as int,
      icon: fields[6] as String,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.savedAmount)
      ..writeByte(4)
      ..write(obj.deadline)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.icon)
      ..writeByte(7)
      ..write(obj.createdAt);
  }
}
