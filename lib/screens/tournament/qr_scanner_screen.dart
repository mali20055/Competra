import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key, required this.onCodeScanned});

  final void Function(String code) onCodeScanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Tara')),
      body: MobileScanner(
        onDetect: (capture) {
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw == null) return;
          final code = raw.replaceFirst('competra://join/', '');
          onCodeScanned(code);
          Navigator.pop(context);
        },
      ),
    );
  }
}
