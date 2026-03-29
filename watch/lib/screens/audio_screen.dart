import 'package:flutter/material.dart';

import '../data/music_catalog.dart';
import '../models/music_track.dart';
import '../services/music_player_service.dart';

class AudioScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const AudioScreen({super.key, this.onBackTap});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final MusicPlayerService _svc = MusicPlayerService.instance;
  late final PageController _pageController;
  int _pageIndex = 0;
  static const double _swipeVelocityThreshold = 250;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _svc.addListener(_onSvc);
  }

  void _onSvc() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _svc.removeListener(_onSvc);
    super.dispose();
  }

  Future<void> _playPageTrack() async {
    await _svc.playPlaylist(MusicCatalog.watchPlaylist, _pageIndex);
  }

  Future<void> _playTrackAt(int index) async {
    _pageIndex = index;
    if (mounted) {
      setState(() {});
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    await _svc.playPlaylist(MusicCatalog.watchPlaylist, index);
  }

  Future<void> _goToPage(int index) async {
    if (index < 0 || index >= MusicCatalog.watchPlaylist.length || index == _pageIndex) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    if (mounted) {
      setState(() {
        _pageIndex = index;
      });
    } else {
      _pageIndex = index;
    }
  }

  Future<void> _goPreviousPage() => _goToPage(_pageIndex - 1);

  Future<void> _goNextPage() => _goToPage(_pageIndex + 1);

  @override
  Widget build(BuildContext context) {
    final current = _svc.currentTrack;
    final err = _svc.lastError;
    final selected = MusicCatalog.watchPlaylist[_pageIndex];

    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 40, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Music',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    err,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                  ),
                ],
                const SizedBox(height: 4),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_pageIndex + 1} / ${MusicCatalog.watchPlaylist.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: (details) async {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity.abs() < _swipeVelocityThreshold) return;
                            if (velocity > 0) {
                              await _goPreviousPage();
                            } else {
                              await _goNextPage();
                            }
                          },
                          child: PageView.builder(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: MusicCatalog.watchPlaylist.length,
                            onPageChanged: (index) {
                              setState(() {
                                _pageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final track = MusicCatalog.watchPlaylist[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _AudioSlideCard(
                                  track: track,
                                  selected: _pageIndex == index,
                                  playing: current?.id == track.id && _svc.player.playing,
                                  isCurrentTrack: current?.id == track.id,
                                  hasPrevious: index > 0,
                                  hasNext: index < MusicCatalog.watchPlaylist.length - 1,
                                  onPrevious: _goPreviousPage,
                                  onPlay: () => _playTrackAt(index),
                                  onStop: () => _svc.stop(),
                                  onNext: _goNextPage,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          MusicCatalog.watchPlaylist.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _pageIndex == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        current == null
                            ? 'Selected: ${selected.category.toUpperCase()}'
                            : 'Now playing: ${current.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioSlideCard extends StatelessWidget {
  final MusicTrack track;
  final bool selected;
  final bool playing;
  final bool isCurrentTrack;
  final bool hasPrevious;
  final bool hasNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onPlay;
  final Future<void> Function() onStop;
  final Future<void> Function() onNext;

  const _AudioSlideCard({
    required this.track,
    required this.selected,
    required this.playing,
    required this.isCurrentTrack,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onPlay,
    required this.onStop,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final icon = track.category == 'quran' ? Icons.menu_book_rounded : Icons.music_note_rounded;
    final accent = Colors.white;
    final secondary = Colors.white70;
    final muted = Colors.white54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected ? const Color(0xFF3A3A3A) : const Color(0xFF1E1E1E),
        border: Border.all(
          color: playing ? Colors.white : Colors.white24,
          width: playing ? 2.2 : 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniControlButton(
                icon: Icons.skip_previous_rounded,
                enabled: hasPrevious,
                onPressed: hasPrevious ? onPrevious : null,
              ),
              _MiniControlButton(
                icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                enabled: true,
                onPressed: playing ? onStop : onPlay,
                filled: true,
              ),
              _MiniControlButton(
                icon: Icons.skip_next_rounded,
                enabled: hasNext,
                onPressed: hasNext ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            track.category == 'quran' ? 'Quran' : 'Song',
            style: TextStyle(
              color: secondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCurrentTrack
                ? (playing ? 'This audio is playing now' : 'This audio is paused')
                : 'Swipe left or right to change audio',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 9,
            ),
          ),
          const Spacer(),
          Text(
            track.category == 'quran'
                ? 'Swipe right or tap previous for Song'
                : 'Swipe left or tap next for Quran',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool filled;
  final Future<void> Function()? onPressed;

  const _MiniControlButton({
    required this.icon,
    required this.enabled,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? (filled ? Colors.black : Colors.white) : Colors.white24;
    final bg = filled
        ? (enabled ? Colors.white : Colors.white24)
        : Colors.transparent;

    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled && onPressed != null ? () => onPressed!() : null,
          child: Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}
