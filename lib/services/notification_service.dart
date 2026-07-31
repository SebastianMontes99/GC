import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/deuda.dart';
import '../models/tarjeta.dart';
import '../utils/ciclo_utils.dart';

/// Notificaciones locales (sin internet ni servidor) que recuerdan al
/// usuario que debe cobrar una deuda antes de que cierre la facturación
/// de la tarjeta usada.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'recordatorios_cobro';
  static const String _channelName = 'Recordatorios de cobro';
  static const String _channelDescription =
      'Avisos para cobrar una deuda antes del cierre de facturación';

  /// Días de anticipación por defecto para recordar el cobro.
  static const int diasAntesPorDefecto = 3;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final nombreZonaHoraria = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(nombreZonaHoraria.identifier));
    } catch (_) {
      // Si no se puede determinar la zona horaria del dispositivo,
      // se mantiene la zona por defecto del paquete timezone.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings: settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ));
  }

  Future<void> solicitarPermisos() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int _idParaCuota(Deuda deuda, int numeroCuota) =>
      '${deuda.id}-cuota-$numeroCuota'.hashCode & 0x7fffffff;

  /// Programa un recordatorio de cobro para cada cuota pendiente de [deuda],
  /// [diasAntes] días antes de la fecha límite de pago que le corresponde a
  /// cada una (no del cierre: el cierre solo define en qué factura cae la
  /// cuota, la fecha de pago es el verdadero límite para cobrar antes de
  /// que el banco cobre a su dueño). Devuelve la lista de ids de las
  /// notificaciones programadas (las cuotas cuya fecha de pago ya pasó no
  /// generan recordatorio).
  Future<List<int>> programarRecordatorio({
    required Deuda deuda,
    required Tarjeta tarjeta,
    int diasAntes = diasAntesPorDefecto,
  }) async {
    final ahora = tz.TZDateTime.now(tz.local);
    final idsProgramados = <int>[];

    for (var numeroCuota = 1; numeroCuota <= deuda.cuotas; numeroCuota++) {
      final cierreCuota = CicloUtils.cierreDeCuota(
        deuda.fechaRegistro,
        tarjeta.diaCierre,
        numeroCuota,
      );
      final pagoCuota = CicloUtils.fechaPago(cierreCuota, tarjeta.diaPago);

      var programarPara = tz.TZDateTime(
        tz.local,
        pagoCuota.year,
        pagoCuota.month,
        pagoCuota.day,
      ).subtract(Duration(days: diasAntes)).add(const Duration(hours: 9));

      final pagoConHora = tz.TZDateTime(
        tz.local,
        pagoCuota.year,
        pagoCuota.month,
        pagoCuota.day,
        9,
      );
      if (!pagoConHora.isAfter(ahora)) {
        continue;
      }
      if (!programarPara.isAfter(ahora)) {
        programarPara = ahora.add(const Duration(minutes: 1));
      }

      final id = _idParaCuota(deuda, numeroCuota);
      final tituloCuota = deuda.cuotas > 1
          ? 'Cobrar a ${deuda.deudor} (cuota $numeroCuota/${deuda.cuotas})'
          : 'Cobrar a ${deuda.deudor}';
      await _plugin.zonedSchedule(
        id: id,
        title: tituloCuota,
        body: 'La tarjeta "${tarjeta.nombre}" cierra el '
            '${cierreCuota.day.toString().padLeft(2, '0')}/'
            '${cierreCuota.month.toString().padLeft(2, '0')} y se paga el '
            '${pagoCuota.day.toString().padLeft(2, '0')}/'
            '${pagoCuota.month.toString().padLeft(2, '0')}. '
            'Recuerda cobrar la cuota antes de esa fecha.',
        scheduledDate: programarPara,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      idsProgramados.add(id);
    }
    return idsProgramados;
  }

  Future<void> cancelarRecordatorios(List<int> notificationIds) async {
    for (final id in notificationIds) {
      await _plugin.cancel(id: id);
    }
  }
}
