import 'package:flutter/material.dart';

import '../models/import_result.dart';
import '../services/guest_import_service.dart';
import '../services/admin_security_service.dart';
import '../widgets/admin_pin_dialog.dart';

class ImportGuestsScreen extends StatefulWidget {
  const ImportGuestsScreen({super.key});

  @override
  State<ImportGuestsScreen> createState() => _ImportGuestsScreenState();
}

class _ImportGuestsScreenState extends State<ImportGuestsScreen> {
  final GuestImportService _importService = GuestImportService();

  bool _importing = false;
  ImportResult? _result;
  String? _error;

  Future<void> _selectFile() async {
    if (_importing) return;

    setState(() {
      _importing = true;
      _result = null;
      _error = null;
    });

    try {
      final authorization = await requestAdminAuthorization(context,
          action: AdminAction.importGuests,
          reason:
              'Autorizar la importación y actualización de invitados desde Excel');
      if (authorization == null || !mounted) return;
      final result =
          await _importService.pickAndImport(authorization: authorization);

      if (!mounted) return;

      if (result != null) {
        setState(() => _result = result);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is AdminPinException
            ? e.message
            : e is FormatException
                ? e.message
                : 'No se pudo importar el archivo: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Widget _resultRow(
    String title,
    int value,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xFF806A61),
      ),
      title: Text(title),
      trailing: Text(
        '$value',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar invitados'),
        backgroundColor: const Color(0xFFEDE2DC),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.file_upload_outlined,
            size: 75,
            color: Color(0xFF806A61),
          ),
          const SizedBox(height: 20),
          const Text(
            'Actualizar lista de invitados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecciona un archivo Excel (.xlsx) con los '
            'folios y datos de tus invitados. Se requiere el PIN de administrador.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          const Text(
            'Primera hoja con datos: encabezados Folio, Nombre, Adultos, '
            'Niños y Mesa. Una invitación por fila. '
            'Mesa puede quedar vacía; conserva la asignación existente. '
            'Usa cantidades enteras y folios de 8 letras o números '
            '(formato de celda Texto para conservar ceros iniciales).',
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFF5EFEB),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text(
                      'Agrega invitados nuevos',
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text(
                      'Actualiza invitados existentes',
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text(
                      'Conserva las entradas registradas',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _importing ? null : _selectFile,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.folder_open),
            label: Text(
              _importing ? 'Importando...' : 'Seleccionar archivo Excel',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF806A61),
              padding: const EdgeInsets.all(18),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 50,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Importación completada',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _resultRow(
                      'Nuevos',
                      _result!.inserted,
                      Icons.person_add_alt,
                    ),
                    _resultRow(
                      'Actualizados',
                      _result!.updated,
                      Icons.update,
                    ),
                    _resultRow(
                      'Sin cambios',
                      _result!.unchanged,
                      Icons.check,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.people),
              label: const Text('Ver invitados'),
            ),
          ],
        ],
      ),
    );
  }
}
