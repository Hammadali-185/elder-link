import 'package:flutter/material.dart';
import 'account_settings_screen.dart';
import 'widgets/avatar_widget.dart';

class MusicScreen extends StatelessWidget {
  final String? staffName;

  const MusicScreen({super.key, this.staffName});

  static const _deepMint = Color(0xFF17A2A2);
  static const _lightMint = Color(0xFF90EE90);
  static const _bg = Color(0xFFF6FFFA);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'ElderLinks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: _deepMint,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        centerTitle: false,
        actions: [
          const Icon(Icons.man, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          const Icon(Icons.woman, size: 20, color: Colors.white),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsScreen(staffName: staffName),
                  ),
                );
              },
              child: const AvatarWidget(size: 40),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildQuickPlay(context),
              const SizedBox(height: 28),
              _buildSection(
                context,
                title: 'Relaxing music',
                icon: Icons.spa_rounded,
                items: _relaxingMusic,
                isPlaylist: false,
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'Old favorites',
                icon: Icons.favorite_rounded,
                items: _oldFavorites,
                isPlaylist: false,
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'Radio & podcasts',
                icon: Icons.radio_rounded,
                items: _radioPodcasts,
                isPlaylist: true,
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'Nature & calm',
                icon: Icons.grass_rounded,
                items: _natureCalm,
                isPlaylist: true,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepMint, Color(0xFF2DB8B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _deepMint.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Music & entertainment',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Relax, remember, and enjoy',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPlay(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _deepMint.withOpacity(0.12),
            _lightMint.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _deepMint.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _deepMint.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_filled_rounded, color: _deepMint, size: 24),
              const SizedBox(width: 8),
              Text(
                'Playing now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _deepMint,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What a Wonderful World',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Louis Armstrong',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniButton(Icons.skip_previous_rounded),
              const SizedBox(width: 8),
              _miniButton(Icons.play_arrow_rounded, isPrimary: true),
              const SizedBox(width: 8),
              _miniButton(Icons.skip_next_rounded),
              const Spacer(),
              Text(
                '2:14 / 2:19',
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniButton(IconData icon, {bool isPrimary = false}) {
    return Material(
      color: isPrimary ? _deepMint : _deepMint.withOpacity(0.15),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 24,
            color: isPrimary ? Colors.white : _deepMint,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
    required bool isPlaylist,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: _deepMint),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isPlaylist ? 148 : 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildEntertainmentCard(
                title: item['title']!,
                subtitle: item['subtitle']!,
                icon: isPlaylist ? Icons.headphones_rounded : Icons.music_note_rounded,
                gradient: _cardGradients[index % _cardGradients.length],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntertainmentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _cardGradients = [
    [_deepMint, Color(0xFF2DB8B8)],
    [Color(0xFF6B8E6B), Color(0xFF8FBC8F)],
    [Color(0xFF5B7C99), Color(0xFF7BA3C4)],
    [Color(0xFF9B7B9B), Color(0xFFB895B8)],
  ];

  static final _relaxingMusic = [
    {'title': 'Piano in the evening', 'subtitle': 'Calm piano'},
    {'title': 'Soft strings', 'subtitle': 'Orchestral peace'},
    {'title': 'Gentle guitar', 'subtitle': 'Acoustic'},
    {'title': 'Meditation tones', 'subtitle': 'Ambient'},
  ];

  static final _oldFavorites = [
    {'title': 'What a Wonderful World', 'subtitle': 'Louis Armstrong'},
    {'title': 'Moon River', 'subtitle': 'Andy Williams'},
    {'title': 'Fly Me to the Moon', 'subtitle': 'Frank Sinatra'},
    {'title': 'Over the Rainbow', 'subtitle': 'Judy Garland'},
    {'title': 'My Way', 'subtitle': 'Frank Sinatra'},
  ];

  static final _radioPodcasts = [
    {'title': 'Classic FM', 'subtitle': 'Classical music'},
    {'title': 'Golden oldies', 'subtitle': '50s & 60s hits'},
    {'title': 'Stories of the past', 'subtitle': 'Nostalgia podcast'},
    {'title': 'Garden talk', 'subtitle': 'Gardening & nature'},
  ];

  static final _natureCalm = [
    {'title': 'Rain on the window', 'subtitle': 'Rain sounds'},
    {'title': 'Forest morning', 'subtitle': 'Birds & breeze'},
    {'title': 'Ocean waves', 'subtitle': 'Seaside calm'},
    {'title': 'Crackling fireplace', 'subtitle': 'Cozy sounds'},
  ];
}
