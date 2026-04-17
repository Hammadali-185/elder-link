import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Staff / admin: set PC or laptop hotspot IP so the APK can reach the Node backend.
class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: ApiService.apiHost);
    _portController = TextEditingController(text: ApiService.apiPort);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ApiService.saveNetworkConfig(
      host: kIsWeb ? '127.0.0.1' : _hostController.text,
      port: _portController.text,
    );
    _hostController.text = ApiService.apiHost;
    _portController.text = ApiService.apiPort;
    ApiService.debugLogEndpoint();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${ApiService.baseUrl}')),
    );
  }

  Future<void> _verifyElderLinkAndPurge() async {
    await ApiService.saveNetworkConfig(
      host: kIsWeb ? '127.0.0.1' : _hostController.text,
      port: _portController.text,
    );
    _hostController.text = ApiService.apiHost;
    _portController.text = ApiService.apiPort;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Verifying…'),
        content: SizedBox(
          width: 280,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    final msg = await ApiService.runBackendPurgeDiagnostics();
    if (!mounted) return;
    Navigator.of(context).pop();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ElderLink / purge check'),
        content: SingleChildScrollView(
          child: SelectableText(msg, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _test() async {
    await ApiService.saveNetworkConfig(
      host: kIsWeb ? '127.0.0.1' : _hostController.text,
      port: _portController.text,
    );
    _hostController.text = ApiService.apiHost;
    _portController.text = ApiService.apiPort;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing…')),
    );
    final msg = await ApiService.testBackendConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 6),
        backgroundColor: msg.startsWith('Connected') ? Colors.green.shade800 : Colors.red.shade900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend server'),
        backgroundColor: deepMint,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            kIsWeb
                ? 'Web uses localhost. APK: enter your PC IP (e.g. 192.168.137.1 on Windows hotspot).'
                : 'Enter the IP of the computer running the backend (same Wi‑Fi or laptop hotspot).',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host / IP (PC)',
              border: OutlineInputBorder(),
            ),
            enabled: !kIsWeb,
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Host locked to localhost on web.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current API base: ${ApiService.baseUrl}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(backgroundColor: deepMint),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _test,
                  child: const Text('Test'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _verifyElderLinkAndPurge,
              child: const Text('Verify ElderLink & purge API'),
            ),
          ),
        ],
      ),
    );
  }
}
