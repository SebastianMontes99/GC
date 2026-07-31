import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/deuda.dart';
import '../models/tarjeta.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../utils/ciclo_utils.dart';
import '../utils/formatters.dart';

/// Días restantes hasta el cierre a partir de los cuales el semáforo
/// pasa de verde a rojo (se acerca la fecha límite de cobro).
const int _umbralDiasAlerta = 5;

class DeudasActivasScreen extends StatelessWidget {
  const DeudasActivasScreen({super.key});

  Future<void> _eliminarDeuda(BuildContext context, Deuda deuda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como cobrada'),
        content: Text('¿Ya cobraste a ${deuda.deudor}? Se eliminará de la lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, ya cobré'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await NotificationService().cancelarRecordatorios(deuda.notificationIds);
    await deuda.delete();
  }

  void _editarDeuda(BuildContext context, Deuda deuda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormularioEditarDeuda(deuda: deuda),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deudas activas')),
      body: ValueListenableBuilder<Box<Deuda>>(
        valueListenable: HiveService.deudasBox.listenable(),
        builder: (context, deudasBox, _) {
          final deudas = deudasBox.values.toList();

          if (deudas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay deudas activas registradas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ValueListenableBuilder<Box<Tarjeta>>(
            valueListenable: HiveService.tarjetasBox.listenable(),
            builder: (context, tarjetasBox, __) {
              final ahora = DateTime.now();

              final entradas = deudas.map((deuda) {
                final tarjeta = tarjetasBox.get(deuda.tarjetaId);
                DateTime? cierreCuota;
                DateTime? pagoCuota;
                int? numeroCuota;
                int? diasRestantes;
                if (tarjeta != null) {
                  numeroCuota = CicloUtils.cuotaActual(
                    deuda.fechaRegistro,
                    tarjeta.diaCierre,
                    tarjeta.diaPago,
                    deuda.cuotas,
                    ahora,
                  );
                  cierreCuota = CicloUtils.cierreDeCuota(
                    deuda.fechaRegistro,
                    tarjeta.diaCierre,
                    numeroCuota,
                  );
                  pagoCuota = CicloUtils.fechaPago(cierreCuota, tarjeta.diaPago);
                  diasRestantes = CicloUtils.diasRestantes(ahora, pagoCuota);
                }
                return _EntradaDeuda(
                  deuda: deuda,
                  tarjeta: tarjeta,
                  cierreCuota: cierreCuota,
                  pagoCuota: pagoCuota,
                  numeroCuota: numeroCuota,
                  diasRestantes: diasRestantes,
                );
              }).toList()
                ..sort((a, b) {
                  final da = a.diasRestantes ?? 999999;
                  final db = b.diasRestantes ?? 999999;
                  return da.compareTo(db);
                });

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: entradas.length,
                itemBuilder: (context, index) {
                  final entrada = entradas[index];
                  final deuda = entrada.deuda;
                  final tarjeta = entrada.tarjeta;
                  final dias = entrada.diasRestantes;
                  final cerca = dias != null && dias <= _umbralDiasAlerta;
                  final colorSemaforo = dias == null
                      ? Colors.grey
                      : (cerca ? Colors.red : Colors.green);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorSemaforo,
                        child: const Icon(Icons.attach_money, color: Colors.white),
                      ),
                      title: Text(deuda.deudor),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deuda.cuotas > 1
                                ? 'Total ${formatearMonto(deuda.monto)} en ${deuda.cuotas} cuotas'
                                : formatearMonto(deuda.monto),
                          ),
                          Text(tarjeta?.nombre ?? 'Tarjeta eliminada'),
                          if (deuda.cuotas > 1 && entrada.numeroCuota != null)
                            Text(
                              'Cuota ${entrada.numeroCuota} de ${deuda.cuotas}: '
                              '${formatearMonto(deuda.montoPorCuota)}',
                            ),
                          if (entrada.cierreCuota != null)
                            Text('Corte: ${formatearFecha(entrada.cierreCuota!)}'),
                          if (entrada.pagoCuota != null)
                            Text(
                              dias! <= 0
                                  ? 'Paga hoy (${formatearFecha(entrada.pagoCuota!)})'
                                  : 'Paga en $dias días (${formatearFecha(entrada.pagoCuota!)})',
                              style: TextStyle(
                                color: colorSemaforo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar deuda',
                            onPressed: () => _editarDeuda(context, deuda),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            tooltip: 'Marcar como cobrada',
                            onPressed: () => _eliminarDeuda(context, deuda),
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

class _EntradaDeuda {
  final Deuda deuda;
  final Tarjeta? tarjeta;
  final DateTime? cierreCuota;
  final DateTime? pagoCuota;
  final int? numeroCuota;
  final int? diasRestantes;

  _EntradaDeuda({
    required this.deuda,
    required this.tarjeta,
    required this.cierreCuota,
    required this.pagoCuota,
    required this.numeroCuota,
    required this.diasRestantes,
  });
}

class _FormularioEditarDeuda extends StatefulWidget {
  final Deuda deuda;
  const _FormularioEditarDeuda({required this.deuda});

  @override
  State<_FormularioEditarDeuda> createState() => _FormularioEditarDeudaState();
}

class _FormularioEditarDeudaState extends State<_FormularioEditarDeuda> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  late final TextEditingController _cuotasController;
  late final TextEditingController _deudorController;
  late String? _tarjetaSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _montoController =
        TextEditingController(text: widget.deuda.monto.toStringAsFixed(0));
    _cuotasController =
        TextEditingController(text: widget.deuda.cuotas.toString());
    _deudorController = TextEditingController(text: widget.deuda.deudor);
    _tarjetaSeleccionadaId = widget.deuda.tarjetaId;
  }

  @override
  void dispose() {
    _montoController.dispose();
    _cuotasController.dispose();
    _deudorController.dispose();
    super.dispose();
  }

  Future<void> _guardar(List<Tarjeta> tarjetas) async {
    if (!_formKey.currentState!.validate()) return;
    if (_tarjetaSeleccionadaId == null) return;

    final tarjeta = tarjetas.firstWhere((t) => t.id == _tarjetaSeleccionadaId);
    final monto = double.parse(_montoController.text.replaceAll(',', '.'));
    final cuotas = int.tryParse(_cuotasController.text) ?? 1;

    final deuda = widget.deuda;
    deuda.tarjetaId = tarjeta.id;
    deuda.monto = monto;
    deuda.cuotas = cuotas < 1 ? 1 : cuotas;
    deuda.deudor = _deudorController.text.trim();
    await deuda.save();

    await NotificationService().cancelarRecordatorios(deuda.notificationIds);
    deuda.notificationIds = await NotificationService().programarRecordatorio(
      deuda: deuda,
      tarjeta: tarjeta,
    );
    await deuda.save();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ValueListenableBuilder<Box<Tarjeta>>(
        valueListenable: HiveService.tarjetasBox.listenable(),
        builder: (context, box, _) {
          final tarjetas = box.values.toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));

          if (_tarjetaSeleccionadaId != null &&
              !tarjetas.any((t) => t.id == _tarjetaSeleccionadaId)) {
            _tarjetaSeleccionadaId = null;
          }

          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Editar deuda', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _tarjetaSeleccionadaId,
                    decoration: const InputDecoration(
                      labelText: 'Tarjeta usada',
                      border: OutlineInputBorder(),
                    ),
                    items: tarjetas
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.nombre),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _tarjetaSeleccionadaId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una tarjeta' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _montoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto prestado',
                      prefixText: r'$ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el monto prestado';
                      }
                      final parsed =
                          double.tryParse(value.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Ingresa un monto válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cuotasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuotas',
                      helperText: 'Deja 1 si no aplica en cuotas',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 1) {
                        return 'Ingresa un número de cuotas válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _deudorController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la persona',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Ingresa el nombre de la persona'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _guardar(tarjetas),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Guardar cambios'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
