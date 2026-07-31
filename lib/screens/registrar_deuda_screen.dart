import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/deuda.dart';
import '../models/tarjeta.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class RegistrarDeudaScreen extends StatefulWidget {
  const RegistrarDeudaScreen({super.key});

  @override
  State<RegistrarDeudaScreen> createState() => _RegistrarDeudaScreenState();
}

class _RegistrarDeudaScreenState extends State<RegistrarDeudaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController(text: '1');
  final _deudorController = TextEditingController();
  String? _tarjetaSeleccionadaId;

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

    final deuda = Deuda(
      id: const Uuid().v4(),
      tarjetaId: tarjeta.id,
      monto: monto,
      cuotas: cuotas < 1 ? 1 : cuotas,
      deudor: _deudorController.text.trim(),
      fechaRegistro: DateTime.now(),
    );

    deuda.notificationIds = await NotificationService().programarRecordatorio(
      deuda: deuda,
      tarjeta: tarjeta,
    );

    await HiveService.deudasBox.put(deuda.id, deuda);

    if (!mounted) return;
    _formKey.currentState!.reset();
    _montoController.clear();
    _cuotasController.text = '1';
    _deudorController.clear();
    setState(() => _tarjetaSeleccionadaId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deuda registrada correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar deuda')),
      body: ValueListenableBuilder<Box<Tarjeta>>(
        valueListenable: HiveService.tarjetasBox.listenable(),
        builder: (context, box, _) {
          final tarjetas = box.values.toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));

          if (tarjetas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Primero debes agregar una tarjeta en la pestaña "Tarjetas".',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (_tarjetaSeleccionadaId != null &&
              !tarjetas.any((t) => t.id == _tarjetaSeleccionadaId)) {
            _tarjetaSeleccionadaId = null;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      helperText: 'El monto se reparte en un cierre por cuota',
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
                      hintText: '¿A quién le prestaste el dinero?',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Ingresa el nombre de la persona'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _guardar(tarjetas),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('Registrar deuda'),
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
