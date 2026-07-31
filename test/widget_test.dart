import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:gestor_cobros/main.dart';
import 'package:gestor_cobros/models/deuda.dart';
import 'package:gestor_cobros/models/tarjeta.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('gestor_cobros_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TarjetaAdapter());
    Hive.registerAdapter(DeudaAdapter());
    await Hive.openBox<Tarjeta>('tarjetas');
    await Hive.openBox<Deuda>('deudas');
  });

  testWidgets('La app muestra la navegación con las 4 pantallas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GestorCobrosApp());
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Tarjetas'), findsWidgets);
    expect(find.text('Prestar'), findsOneWidget);
    expect(find.text('Deudas'), findsOneWidget);
  });
}
