import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class ClockScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  
  const ClockScreen({super.key, this.onBackTap});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Timer? _timer;
  Timer? _clockTimer;
  Timer? _ringTimer;
  int _secondsRemaining = 0;
  bool _isRunning = false;
  bool _isRinging = false;
  DateTime _currentTime = DateTime.now();
  
  // Timer input controllers
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  void _startTimer() {
    if (_secondsRemaining > 0) {
      setState(() {
        _isRunning = true;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_secondsRemaining > 0) {
              _secondsRemaining--;
            } else {
              _stopTimer();
              _showTimerCompleteDialog();
            }
          });
        }
      });
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = 0;
    });
  }

  void _resetTimer() {
    _stopTimer();
    _secondsRemaining = (_hours * 3600) + (_minutes * 60) + _seconds;
  }

  void _setTimer() {
    _secondsRemaining = (_hours * 3600) + (_minutes * 60) + _seconds;
    if (_secondsRemaining > 0) {
      _startTimer();
    }
  }

  void _ringAlarm() async {
    setState(() {
      _isRinging = true;
    });

    // Vibrate
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 500, 500], repeat: 1);
    }

    // Play alarm sound repeatedly
    int beepCount = 0;
    _ringTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (beepCount < 15) { // Ring for 9 seconds (15 beeps)
        // Play system alert sound
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        beepCount++;
      } else {
        timer.cancel();
        setState(() {
          _isRinging = false;
        });
      }
    });
  }

  void _stopRing() {
    _ringTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isRinging = false;
    });
  }

  void _showTimerCompleteDialog() {
    _ringAlarm();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange,
        title: const Text(
          'Timer Complete!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your timer has finished.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopRing();
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatClockTime(DateTime time) {
    // Format with 12-hour format without seconds
    int hour = time.hour;
    String period = '';
    
    // Use 12-hour format
    if (hour == 0) {
      hour = 12;
      period = ' AM';
    } else if (hour < 12) {
      period = ' AM';
    } else if (hour == 12) {
      period = ' PM';
    } else {
      hour = hour - 12;
      period = ' PM';
    }
    
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}$period';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _ringTimer?.cancel();
    Vibration.cancel();
    super.dispose();
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
          // Main content - Constrained to stay within watch frame
          Center(
            child: SizedBox(
              width: 320, // Constrain width to stay within 360px circle
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current time display - More prominent, constrained
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatClockTime(_currentTime),
                      style: TextStyle(
                        color: _isRinging ? Colors.orange : Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date display
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_currentTime.day}/${_currentTime.month}/${_currentTime.year}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Timer display - Constrained
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatTime(_secondsRemaining),
                      style: TextStyle(
                        color: _secondsRemaining > 0 ? Colors.orange : Colors.grey,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Timer controls
                  if (!_isRunning && _secondsRemaining == 0)
                    // Set timer input
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Hours
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_hours < 23) _hours++;
                                      });
                                    },
                                  ),
                                  Text(
                                    _hours.toString().padLeft(2, '0'),
                                    style: const TextStyle(color: Colors.white, fontSize: 20),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_hours > 0) _hours--;
                                      });
                                    },
                                  ),
                                  const Text('H', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const Text(':', style: TextStyle(color: Colors.white, fontSize: 24)),
                              // Minutes
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_minutes < 59) _minutes++;
                                      });
                                    },
                                  ),
                                  Text(
                                    _minutes.toString().padLeft(2, '0'),
                                    style: const TextStyle(color: Colors.white, fontSize: 20),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_minutes > 0) _minutes--;
                                      });
                                    },
                                  ),
                                  const Text('M', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const Text(':', style: TextStyle(color: Colors.white, fontSize: 24)),
                              // Seconds
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_seconds < 59) _seconds++;
                                      });
                                    },
                                  ),
                                  Text(
                                    _seconds.toString().padLeft(2, '0'),
                                    style: const TextStyle(color: Colors.white, fontSize: 20),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        if (_seconds > 0) _seconds--;
                                      });
                                    },
                                  ),
                                  const Text('S', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Start button (when timer is set but not started) - More prominent
                        if (_hours > 0 || _minutes > 0 || _seconds > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _setTimer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  elevation: 8,
                                  shadowColor: Colors.orange.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'START TIMER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    // Timer running controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRunning)
                          IconButton(
                            icon: const Icon(Icons.pause, color: Colors.white, size: 32),
                            onPressed: _pauseTimer,
                          )
                        else if (_secondsRemaining > 0)
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                            onPressed: _startTimer,
                          ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.white, size: 32),
                          onPressed: _stopTimer,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Back button (keep LAST so it stays on top)
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
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.6),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 28,
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
