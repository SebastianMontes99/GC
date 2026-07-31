import 'package:hive/hive.dart';

class Deuda extends HiveObject {
  String id;
  String tarjetaId;
  double monto;
  int cuotas;
  String deudor;
  DateTime fechaRegistro;
  List<int> notificationIds;

  Deuda({
    required this.id,
    required this.tarjetaId,
    required this.monto,
    required this.cuotas,
    required this.deudor,
    required this.fechaRegistro,
    List<int>? notificationIds,
  }) : notificationIds = notificationIds ?? [];

  double get montoPorCuota => cuotas > 0 ? monto / cuotas : monto;
}

class DeudaAdapter extends TypeAdapter<Deuda> {
  @override
  final int typeId = 1;

  @override
  Deuda read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Deuda(
      id: fields[0] as String,
      tarjetaId: fields[1] as String,
      monto: fields[2] as double,
      cuotas: fields[3] as int,
      deudor: fields[4] as String,
      fechaRegistro: fields[5] as DateTime,
      notificationIds: (fields[6] as List?)?.cast<int>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, Deuda obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tarjetaId)
      ..writeByte(2)
      ..write(obj.monto)
      ..writeByte(3)
      ..write(obj.cuotas)
      ..writeByte(4)
      ..write(obj.deudor)
      ..writeByte(5)
      ..write(obj.fechaRegistro)
      ..writeByte(6)
      ..write(obj.notificationIds);
  }
}
