import 'package:intl/intl.dart';

final NumberFormat montoFormatter = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
);

final DateFormat fechaCortaFormatter = DateFormat('dd/MM/yyyy');

String formatearMonto(double monto) => montoFormatter.format(monto);

String formatearFecha(DateTime fecha) => fechaCortaFormatter.format(fecha);
