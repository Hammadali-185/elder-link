import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  final double brightness;
  final String language; // 'en' or 'ur'
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<String> onLanguageChanged;

  const SettingsScreen({
    super.key,
    this.onBackTap,
    required this.brightness,
    required this.language,
    required this.onBrightnessChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _saveBackend() async {
    try {
      final rawHost = _hostController.text.trim();
      final rawPort = _portController.text.trim();
      if (rawHost.isEmpty || rawPort.isEmpty) {
        throw Exception('Host and port are required');
      }
      await ApiService.saveNetworkConfig(
        host: rawHost,
        port: rawPort,
      );
      _hostController.text = ApiService.apiHost;
      _portController.text = ApiService.apiPort;
      ApiService.debugLogEndpoint();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${ApiService.baseUrl}')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _testConnection() async {
    if (!mounted) return;
    await ApiService.saveNetworkConfig(
      host: _hostController.text,
      port: _portController.text,
    );
    _hostController.text = ApiService.apiHost;
    _portController.text = ApiService.apiPort;
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing…')),
    );
    final msg = await ApiService.testBackendConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 8),
        backgroundColor: msg.startsWith('Connected') ? Colors.green.shade800 : Colors.red.shade900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Backend',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _hostController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Host / IP (PC)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveBackend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testConnection,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Test', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${ApiService.baseUrl}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    if (ApiService.lastMedicinesFetchError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last error: ${ApiService.lastMedicinesFetchError}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Brightness
                    const Text(
                      'Brightness',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Slider(
                      value: widget.brightness.clamp(0.2, 1.0),
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      activeColor: Colors.orange,
                      inactiveColor: Colors.white24,
                      onChanged: widget.onBrightnessChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dim', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text('${(widget.brightness * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Text('Bright', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Language
                    const Text(
                      'Language',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.language,
                          dropdownColor: Colors.black87,
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'ur', child: Text('Urdu / اردو')),
                          ],
                          onChanged: (val) {
                            if (val != null) widget.onLanguageChanged(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(25),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
