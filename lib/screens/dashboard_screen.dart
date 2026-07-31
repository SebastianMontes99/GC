import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/deuda.dart';
import '../models/tarjeta.dart';
import '../services/hive_service.dart';
import '../utils/ciclo_utils.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  double _totalPrestadoEnCicloActual(
    Tarjeta tarjeta,
    Box<Deuda> deudasBox,
    DateTime proximoCierre,
  ) {
    double total = 0;
    for (final deuda in deudasBox.values) {
      if (deuda.tarjetaId != tarjeta.id) continue;
      if (CicloUtils.tieneCuotaEnCierre(
        deuda.fechaRegistro,
        tarjeta.diaCierre,
        deuda.cuotas,
        proximoCierre,
      )) {
        total += deuda.montoPorCuota;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tarjetas')),
      body: ValueListenableBuilder<Box<Tarjeta>>(
        valueListenable: HiveService.tarjetasBox.listenable(),
        builder: (context, tarjetasBox, _) {
          final tarjetas = tarjetasBox.values.toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));

          if (tarjetas.isEmpty) {
            return const _DashboardVacio();
          }

          return ValueListenableBuilder<Box<Deuda>>(
            valueListenable: HiveService.deudasBox.listenable(),
            builder: (context, deudasBox, __) {
              final ahora = DateTime.now();
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: tarjetas.length,
                itemBuilder: (context, index) {
                  final tarjeta = tarjetas[index];
                  final proximoCierre =
                      CicloUtils.proximoCierre(ahora, tarjeta.diaCierre);
                  final fechaPago =
                      CicloUtils.fechaPago(proximoCierre, tarjeta.diaPago);
                  final diasRestantes =
                      CicloUtils.diasRestantes(ahora, fechaPago);
                  final totalPrestado = _totalPrestadoEnCicloActual(
                    tarjeta,
                    deudasBox,
                    proximoCierre,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tarjeta.nombre,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              _ChipDiasRestantes(dias: diasRestantes),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prestado en este ciclo',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    formatearMonto(totalPrestado),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Corte',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(formatearFecha(proximoCierre)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fecha límite de pago',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                formatearFecha(fechaPago),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: diasRestantes <= 5
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ChipDiasRestantes extends StatelessWidget {
  final int dias;
  const _ChipDiasRestantes({required this.dias});

  @override
  Widget build(BuildContext context) {
    final bool cerca = dias <= 5;
    final color = cerca ? Colors.red : Colors.green;
    final texto = dias <= 0 ? 'Paga hoy' : '$dias días';
    return Chip(
      label: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
    );
  }
}

class _DashboardVacio extends StatelessWidget {
  const _DashboardVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aún no has agregado tarjetas.\nVe a la pestaña "Tarjetas" para crear la primera.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
