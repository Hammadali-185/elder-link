import 'package:flutter/material.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  int _currentTrackIndex = 0;
  bool _isPlaying = false;

  final List<Map<String, String>> _tracks = [
    {'name': 'Surah Al-Fatiha', 'duration': '2:15'},
    {'name': 'Surah Al-Baqarah', 'duration': '45:20'},
    {'name': 'Surah Al-Ikhlas', 'duration': '1:30'},
    {'name': 'Surah Al-Falaq', 'duration': '1:20'},
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      padding: const EdgeInsets.all(8),
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Audio / Quran',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Track',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _tracks[_currentTrackIndex]['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                final isCurrentTrack = index == _currentTrackIndex;
                return _buildTrackItem(track, index, isCurrentTrack);
              },
            ),
          ),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_currentTrackIndex > 0) {
                        _currentTrackIndex--;
                      }
                    });
                  },
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_currentTrackIndex < _tracks.length - 1) {
                        _currentTrackIndex++;
                      }
                    });
                  },
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = false;
                    });
                  },
                  icon: const Icon(Icons.stop, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTrackItem(Map<String, String> track, int index, bool isCurrentTrack) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTrackIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentTrack ? Colors.purple.withOpacity(0.3) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentTrack ? Colors.purple : Colors.grey[800]!,
            width: isCurrentTrack ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCurrentTrack ? Icons.music_note : Icons.music_note_outlined,
              color: isCurrentTrack ? Colors.purple : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track['name']!,
                    style: TextStyle(
                      color: isCurrentTrack ? Colors.white : Colors.grey[300],
                      fontSize: 16,
                      fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    track['duration']!,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
