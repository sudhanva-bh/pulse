import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/core/services/lan_client.dart';
import 'dart:convert';
import 'package:toastification/toastification.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() => _isProcessing = true);
      final raw = barcodes.first.rawValue!;
      try {
        final payload = jsonDecode(raw);
        final expiry = payload['expiry'] as int;
        if (DateTime.now().millisecondsSinceEpoch > expiry) {
           toastification.show(
             context: context,
             title: const Text('QR Expired'),
             type: ToastificationType.error,
           );
           if (mounted) setState(() => _isProcessing = false);
           return;
        }

        final client = ref.read(lanClientProvider);
        final count = await client.connectAndReceive(payload['ip'], payload['port'], payload['token']);
        
        if (mounted) {
           if (count > 0) {
             toastification.show(
               context: context,
               title: Text('Received $count messages!'),
               type: ToastificationType.success,
             );
           } else {
             toastification.show(
               context: context,
               title: const Text('Transfer Failed'),
               type: ToastificationType.error,
             );
           }
           Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive via LAN')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          if (_isProcessing)
             const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
