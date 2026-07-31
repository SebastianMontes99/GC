import 'package:hive_flutter/hive_flutter.dart';

import '../models/deuda.dart';
import '../models/tarjeta.dart';

/// Encapsula la inicialización y el acceso a las cajas (boxes) de Hive.
/// Toda la información vive únicamente en el almacenamiento local del
/// dispositivo, sin ningún servidor ni base de datos remota.
class HiveService {
  HiveService._();

  static const String tarjetasBoxName = 'tarjetas';
  static const String deudasBoxName = 'deudas';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TarjetaAdapter());
    Hive.registerAdapter(DeudaAdapter());
    await Hive.openBox<Tarjeta>(tarjetasBoxName);
    await Hive.openBox<Deuda>(deudasBoxName);
  }

  static Box<Tarjeta> get tarjetasBox => Hive.box<Tarjeta>(tarjetasBoxName);
  static Box<Deuda> get deudasBox => Hive.box<Deuda>(deudasBoxName);
}
