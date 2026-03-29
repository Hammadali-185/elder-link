import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
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
                    // Brightness
                    const Text(
                      'Brightness',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Slider(
                      value: brightness.clamp(0.2, 1.0),
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      activeColor: Colors.orange,
                      inactiveColor: Colors.white24,
                      onChanged: onBrightnessChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dim', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text('${(brightness * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                          value: language,
                          dropdownColor: Colors.black87,
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'ur', child: Text('Urdu / اردو')),
                          ],
                          onChanged: (val) {
                            if (val != null) onLanguageChanged(val);
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
                onTap: onBackTap,
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
