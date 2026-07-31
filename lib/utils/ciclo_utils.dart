/// Utilidades para calcular fechas de ciclo de facturación a partir del
/// día de cierre configurado en cada tarjeta.
class CicloUtils {
  CicloUtils._();

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ajusta [dia] al último día válido del mes (ej: 31 en febrero -> 28/29).
  static DateTime _clampDia(int year, int month, int dia) {
    final ultimoDiaDelMes = DateTime(year, month + 1, 0).day;
    final diaAjustado = dia > ultimoDiaDelMes ? ultimoDiaDelMes : dia;
    return DateTime(year, month, diaAjustado);
  }

  /// Próxima fecha de cierre de facturación en o después de [desde],
  /// según el [diaCierre] (1-31) configurado para la tarjeta.
  static DateTime proximoCierre(DateTime desde, int diaCierre) {
    final hoy = _soloFecha(desde);
    var candidato = _clampDia(hoy.year, hoy.month, diaCierre);
    if (candidato.isBefore(hoy)) {
      final mesSiguiente = DateTime(hoy.year, hoy.month + 1, 1);
      candidato = _clampDia(mesSiguiente.year, mesSiguiente.month, diaCierre);
    }
    return candidato;
  }

  /// Días restantes (puede ser 0) entre [desde] y [hasta], ignorando la hora.
  static int diasRestantes(DateTime desde, DateTime hasta) {
    final d1 = _soloFecha(desde);
    final d2 = _soloFecha(hasta);
    return d2.difference(d1).inDays;
  }

  /// Fecha de cierre correspondiente a la cuota [numeroCuota] (1-indexada)
  /// de una deuda registrada en [fechaRegistro], para una tarjeta con el
  /// [diaCierre] indicado. La cuota 1 vence en el primer cierre luego del
  /// registro; cada cuota siguiente vence un mes después.
  static DateTime cierreDeCuota(
    DateTime fechaRegistro,
    int diaCierre,
    int numeroCuota,
  ) {
    final primerCierre = proximoCierre(fechaRegistro, diaCierre);
    if (numeroCuota <= 1) return primerCierre;
    final mesObjetivo = DateTime(
      primerCierre.year,
      primerCierre.month + (numeroCuota - 1),
      1,
    );
    return _clampDia(mesObjetivo.year, mesObjetivo.month, diaCierre);
  }

  /// Fecha límite de pago que corresponde a un [cierre] dado, según el
  /// [diaPago] (día del mes) configurado en la tarjeta.
  ///
  /// El día de pago siempre cae DESPUÉS del cierre que lo genera: si el
  /// [diaPago] (numéricamente) ya pasó dentro del mes del cierre, la fecha
  /// de pago es en el mes siguiente; si todavía no llega, es en el mismo mes.
  /// Ej: cierre 31/07 con diaPago 10 -> pago 10/08 (mes siguiente).
  /// Ej: cierre 05/07 con diaPago 20 -> pago 20/07 (mismo mes).
  static DateTime fechaPago(DateTime cierre, int diaPago) {
    var candidato = _clampDia(cierre.year, cierre.month, diaPago);
    if (!candidato.isAfter(cierre)) {
      final mesSiguiente = DateTime(cierre.year, cierre.month + 1, 1);
      candidato = _clampDia(mesSiguiente.year, mesSiguiente.month, diaPago);
    }
    return candidato;
  }

  /// Número de cuota (1-indexado) cuya fecha límite de pago está actualmente
  /// pendiente en o después de [ahora]. Si todas las cuotas ya vencieron,
  /// devuelve la última.
  static int cuotaActual(
    DateTime fechaRegistro,
    int diaCierre,
    int diaPago,
    int totalCuotas,
    DateTime ahora,
  ) {
    final hoy = _soloFecha(ahora);
    for (var k = 1; k <= totalCuotas; k++) {
      final cierreK = cierreDeCuota(fechaRegistro, diaCierre, k);
      if (!fechaPago(cierreK, diaPago).isBefore(hoy)) {
        return k;
      }
    }
    return totalCuotas;
  }

  /// Indica si alguna de las cuotas de una deuda vence exactamente en
  /// [cierre] (la fecha de cierre del ciclo que se está evaluando).
  static bool tieneCuotaEnCierre(
    DateTime fechaRegistro,
    int diaCierre,
    int totalCuotas,
    DateTime cierre,
  ) {
    for (var k = 1; k <= totalCuotas; k++) {
      if (cierreDeCuota(fechaRegistro, diaCierre, k) == cierre) return true;
    }
    return false;
  }
}
