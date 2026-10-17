
import 'package:flutter/material.dart';

import '../models/import_result.dart';
import '../services/guest_import_service.dart';

class ImportGuestsScreen extends StatefulWidget {
  const ImportGuestsScreen({super.key});

  @override
  State<ImportGuestsScreen> createState() =>
      _ImportGuestsScreenState();
}

class _ImportGuestsScreenState
    extends State<ImportGuestsScreen> {
  final GuestImportService _importService =
      GuestImportService();

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
      final result = await _importService.pickAndImport();

      if (!mounted) return;

      if (result != null) {
        setState(() => _result = result);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is FormatException
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
            'Selecciona un archivo JSON con los '
            'folios y datos de tus invitados.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 25),

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
              _importing
                  ? 'Importando...'
                  : 'Seleccionar archivo JSON',
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
