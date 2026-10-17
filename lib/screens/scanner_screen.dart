
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/database_service.dart';
import 'guest_detail_screen.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );

  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || !mounted) return;

    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    setState(() => _processing = true);

    await _controller.stop();

    try {
      final code = _extractCode(rawValue);

      if (code == null) {
        await _showMessage(
          'Código QR no válido',
          'El QR no contiene un folio válido.',
        );
        return;
      }

      final guest = await DatabaseService.instance
          .getGuestByCode(code);

      if (!mounted) return;

      if (guest == null) {
        await _showMessage(
          'Pase no encontrado',
          'El folio $code no existe en la lista de invitados.',
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestDetailScreen(
            code: guest.code,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        await _showMessage(
          'Error al escanear',
          'No se pudo procesar el código: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        await _controller.start();
      }
    }
  }

  String? _extractCode(String value) {
    final text = value.trim();

    // QR que contiene únicamente el folio.
    final codePattern = RegExp(r'^[A-Za-z0-9]{8}$');

    if (codePattern.hasMatch(text)) {
      return text.toUpperCase();
    }

    // QR que contiene una URL con el folio.
    // Ejemplo: https://invitacion.com/pase?folio=EEGA7775
    final uri = Uri.tryParse(text);

    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      final code = uri.queryParameters['folio'];

      if (code != null &&
          codePattern.hasMatch(code)) {
        return code.toUpperCase();
      }
    }

    return null;
  }

  Future<void> _showMessage(
    String title,
    String message,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Escanear invitación'),
      backgroundColor: AppColors.background,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),

        Container(
          color: Colors.black.withOpacity(0.15),
        ),

        Center(
          child: Container(
            width: 265,
            height: 265,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE8D6A9),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_2,
                size: 75,
                color: Colors.white38,
              ),
            ),
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: 45,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primary,
                    size: 30,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Escanear pase digital',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'serif',
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Coloca el código QR dentro del '
                    'recuadro para consultar la invitación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

}
