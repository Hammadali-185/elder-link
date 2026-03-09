import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PanicButtonScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  
  const PanicButtonScreen({super.key, this.onBackTap});

  @override
  State<PanicButtonScreen> createState() => _PanicButtonScreenState();
}

class _PanicButtonScreenState extends State<PanicButtonScreen> {
  bool _isPressed = false;
  bool _alertSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendPanicAlert() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Use saved name if available, otherwise use a default
    final username = ApiService.userName?.isNotEmpty == true 
        ? ApiService.userName! 
        : 'Watch User';
    
    final result = await ApiService.sendPanicAlert(
      username: username,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _alertSent = true;
          _isPressed = false;
        } else {
          // Show full error message for debugging
          final error = result['error'] ?? 'Failed to send alert';
          _errorMessage = 'Error: $error';
          print('Panic alert failed: $error');
          _isPressed = false;
        }
      });

      if (_alertSent) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _alertSent = false;
            });
          }
        });
      }
    }
  }

  void _handlePress() {
    setState(() {
      _isPressed = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isPressed) {
        _sendPanicAlert();
      }
    });
  }

  void _handleRelease() {
    if (_isPressed && !_alertSent) {
      setState(() {
        _isPressed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF000000), // Black background
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Back button top-most (matching other screens)
          Positioned(
            top: 28,
            left: 28,
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
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
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
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_alertSent)
                  const Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 60),
                      SizedBox(height: 16),
                      Text(
                        'Alert Sent!',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else if (_errorMessage != null)
                  Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      GestureDetector(
                        onTapDown: (_) => _handlePress(),
                        onTapUp: (_) => _handleRelease(),
                        onTapCancel: () => _handleRelease(),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _isPressed ? Colors.red[900] : const Color(0xFFDC3545),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _isPressed ? 'HOLDING...' : 'PRESS\n&\nHOLD',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Hold for 2 seconds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
