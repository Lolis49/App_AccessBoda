import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_security_service.dart';

Future<AdminAuthorization?> requestAdminAuthorization(BuildContext context,
    {required AdminAction action,
    required String reason,
    AdminSecurityService? security}) async {
  final service = security ?? AdminSecurityService.instance;
  try {
    final configured = await service.isConfigured();
    if (!context.mounted) return null;
    return await showDialog<AdminAuthorization>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminPinDialog(
          security: service,
          action: action,
          reason: reason,
          creating: !configured),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No se pudo acceder al almacenamiento seguro. Intenta de nuevo.'),
      ));
    }
    return null;
  }
}

Future<void> manageAdminPin(BuildContext context) async {
  final bool configured;
  try {
    configured = await AdminSecurityService.instance.isConfigured();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo acceder al almacenamiento seguro.'),
      ));
    }
    return;
  }
  if (!context.mounted) return;
  final authorization = await requestAdminAuthorization(context,
      action: AdminAction.changePin,
      reason: 'Configurar o cambiar el PIN de administrador');
  if (authorization == null || !context.mounted) return;
  if (!configured) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('PIN configurado.')));
    return;
  }
  final result = await showDialog<AdminAuthorization>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminPinDialog(
        security: AdminSecurityService.instance,
        action: AdminAction.changePin,
        reason: 'Elige tu nuevo PIN de administrador',
        creating: true,
        changeAuthorization: authorization),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('PIN actualizado.')));
  }
}

class AdminPinDialog extends StatefulWidget {
  final AdminSecurityService security;
  final AdminAction action;
  final String reason;
  final bool creating;
  final AdminAuthorization? changeAuthorization;
  const AdminPinDialog(
      {super.key,
      required this.security,
      required this.action,
      required this.reason,
      required this.creating,
      this.changeAuthorization});

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (widget.creating && _pin.text != _confirmation.text) {
      setState(() => _error = 'Los PIN no coinciden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AdminAuthorization authorization;
      if (widget.changeAuthorization != null) {
        authorization = widget.changeAuthorization!;
        await widget.security.changePin(authorization, _pin.text);
      } else if (widget.creating) {
        authorization =
            await widget.security.configure(_pin.text, widget.action);
      } else {
        authorization =
            await widget.security.authorize(_pin.text, widget.action);
      }
      if (mounted) {
        Navigator.pop(context, authorization);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AdminPinException
              ? error.message
              : 'No se pudo verificar o guardar el PIN. Intenta de nuevo.';
          _pin.clear();
          _confirmation.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        enabled: !_busy,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(labelText: label, counterText: ''),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.creating
            ? (widget.changeAuthorization == null
                ? 'Crear PIN de administrador'
                : 'Cambiar PIN')
            : 'PIN de administrador'),
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.reason),
            const SizedBox(height: 12),
            if (widget.creating) ...[
              const Text('Usa 6 dígitos y guarda tu PIN en un lugar seguro.'),
              const SizedBox(height: 12),
            ],
            _field(_pin, widget.creating ? 'Nuevo PIN' : 'PIN'),
            if (widget.creating) ...[
              const SizedBox(height: 12),
              _field(_confirmation, 'Confirmar PIN'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_busy)
              const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator()),
          ],
        )),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(widget.creating ? 'Guardar PIN' : 'Autorizar')),
        ],
      ),
    );
  }
}
