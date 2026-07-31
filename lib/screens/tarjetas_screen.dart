import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/tarjeta.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class TarjetasScreen extends StatelessWidget {
  const TarjetasScreen({super.key});

  Future<void> _eliminarTarjeta(BuildContext context, Tarjeta tarjeta) async {
    final deudasBox = HiveService.deudasBox;
    final deudasAsociadas =
        deudasBox.values.where((d) => d.tarjetaId == tarjeta.id).toList();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text(
          deudasAsociadas.isEmpty
              ? '¿Eliminar la tarjeta "${tarjeta.nombre}"?'
              : '¿Eliminar la tarjeta "${tarjeta.nombre}"? '
                  'Se eliminarán también sus ${deudasAsociadas.length} deuda(s) registrada(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    for (final deuda in deudasAsociadas) {
      await NotificationService().cancelarRecordatorios(deuda.notificationIds);
      await deuda.delete();
    }
    await tarjeta.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas')),
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
                  'No hay tarjetas registradas.\nToca el botón + para agregar una.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tarjetas.length,
            itemBuilder: (context, index) {
              final tarjeta = tarjetas[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.credit_card)),
                  title: Text(tarjeta.nombre),
                  subtitle: Text(
                    'Cierra el día ${tarjeta.diaCierre} · '
                    'Paga el día ${tarjeta.diaPago} de cada mes',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar tarjeta',
                        onPressed: () => _mostrarFormularioTarjeta(context,
                            tarjeta: tarjeta),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar tarjeta',
                        onPressed: () => _eliminarTarjeta(context, tarjeta),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioTarjeta(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarFormularioTarjeta(BuildContext context, {Tarjeta? tarjeta}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormularioNuevaTarjeta(tarjetaExistente: tarjeta),
    );
  }
}

class _FormularioNuevaTarjeta extends StatefulWidget {
  final Tarjeta? tarjetaExistente;
  const _FormularioNuevaTarjeta({this.tarjetaExistente});

  @override
  State<_FormularioNuevaTarjeta> createState() =>
      _FormularioNuevaTarjetaState();
}

class _FormularioNuevaTarjetaState extends State<_FormularioNuevaTarjeta> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late int _diaCierre;
  late int _diaPago;

  bool get _esEdicion => widget.tarjetaExistente != null;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.tarjetaExistente?.nombre ?? '');
    _diaCierre = widget.tarjetaExistente?.diaCierre ?? 1;
    _diaPago = widget.tarjetaExistente?.diaPago ?? 10;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final tarjetaExistente = widget.tarjetaExistente;
    if (tarjetaExistente != null) {
      final fechasCambiaron = tarjetaExistente.diaCierre != _diaCierre ||
          tarjetaExistente.diaPago != _diaPago;
      tarjetaExistente.nombre = _nombreController.text.trim();
      tarjetaExistente.diaCierre = _diaCierre;
      tarjetaExistente.diaPago = _diaPago;
      await tarjetaExistente.save();

      if (fechasCambiaron) {
        final deudasAsociadas = HiveService.deudasBox.values
            .where((d) => d.tarjetaId == tarjetaExistente.id)
            .toList();
        for (final deuda in deudasAsociadas) {
          await NotificationService()
              .cancelarRecordatorios(deuda.notificationIds);
          deuda.notificationIds =
              await NotificationService().programarRecordatorio(
            deuda: deuda,
            tarjeta: tarjetaExistente,
          );
          await deuda.save();
        }
      }
    } else {
      final tarjeta = Tarjeta(
        id: const Uuid().v4(),
        nombre: _nombreController.text.trim(),
        diaCierre: _diaCierre,
        diaPago: _diaPago,
      );
      await HiveService.tarjetasBox.put(tarjeta.id, tarjeta);
    }
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _esEdicion ? 'Editar tarjeta' : 'Nueva tarjeta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tarjeta',
                  hintText: 'Ej: Visa Bancolombia',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _diaCierre,
                decoration: const InputDecoration(
                  labelText: 'Día de cierre (corte)',
                  helperText: 'Fin del ciclo: hasta aquí llega cada factura',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(31, (i) => i + 1)
                    .map((dia) =>
                        DropdownMenuItem(value: dia, child: Text('Día $dia')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _diaCierre = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _diaPago,
                decoration: const InputDecoration(
                  labelText: 'Día límite de pago',
                  helperText:
                      'Fecha real para cobrar antes de pagarle al banco',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(31, (i) => i + 1)
                    .map((dia) =>
                        DropdownMenuItem(value: dia, child: Text('Día $dia')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _diaPago = value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Por seguridad no se solicita el número de la tarjeta.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardar,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                        _esEdicion ? 'Guardar cambios' : 'Guardar tarjeta'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
