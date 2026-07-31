import 'package:hive/hive.dart';

class Tarjeta extends HiveObject {
  String id;
  String nombre;

  /// Día del mes en que cierra la facturación (fin del ciclo/corte).
  int diaCierre;

  /// Día del mes en que vence el pago de la factura generada en el cierre.
  /// Es la fecha límite real para cobrar antes de que el banco cobre a su
  /// dueño: puede caer en el mismo mes del cierre o en el siguiente,
  /// dependiendo de si el día de pago es antes o después del día de cierre.
  int diaPago;

  Tarjeta({
    required this.id,
    required this.nombre,
    required this.diaCierre,
    required this.diaPago,
  });
}

class TarjetaAdapter extends TypeAdapter<Tarjeta> {
  @override
  final int typeId = 0;

  @override
  Tarjeta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final diaCierre = fields[2] as int;
    return Tarjeta(
      id: fields[0] as String,
      nombre: fields[1] as String,
      diaCierre: diaCierre,
      diaPago: (fields[3] as int?) ?? diaCierre,
    );
  }

  @override
  void write(BinaryWriter writer, Tarjeta obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.diaCierre)
      ..writeByte(3)
      ..write(obj.diaPago);
  }
}
