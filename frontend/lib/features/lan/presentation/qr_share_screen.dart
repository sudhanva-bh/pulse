import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:frontend/core/services/lan_server.dart';
import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:toastification/toastification.dart';

class QrShareScreen extends ConsumerStatefulWidget {
  const QrShareScreen({super.key});

  @override
  ConsumerState<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends ConsumerState<QrShareScreen> {
  Map<String, dynamic>? _payload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    final server = ref.read(lanServerProvider);
    final payload = await server.start();
    
    if (mounted) {
      if (payload == null) {
         toastification.show(
           context: context,
           title: const Text('WiFi Required'),
           description: const Text('Please connect to a WiFi network to use LAN delivery.'),
           type: ToastificationType.error,
         );
         Navigator.of(context).pop();
      } else {
         setState(() {
           _payload = payload;
           _isLoading = false;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send via LAN')),
      body: Center(
        child: _isLoading 
          ? LoadingAnimationWidget.progressiveDots(color: Colors.blue, size: 40)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Scan this QR with the other device', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 32),
                QrImageView(
                  data: jsonEncode(_payload),
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text('Expires in 60 seconds.'),
              ],
            ),
      ),
    );
  }
}
