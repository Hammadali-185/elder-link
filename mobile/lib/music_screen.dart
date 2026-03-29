import 'dart:async';

import 'package:flutter/material.dart';

import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'widgets/avatar_widget.dart';

class MusicScreen extends StatefulWidget {
  final String? staffName;

  const MusicScreen({super.key, this.staffName});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  MusicDashboardSummary? _summary;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  static const _deepMint = Color(0xFF17A2A2);
  static const _lightMint = Color(0xFF90EE90);
  static const _bg = Color(0xFFF6FFFA);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

  @override
  void initState() {
    super.initState();
    _loadPanel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadPanel(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPanel({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final data = await ApiService.getMusicDashboard();
    if (!mounted) return;

    setState(() {
      _summary = data;
      _loading = false;
      _error = data == null ? 'Could not load live music monitoring.' : null;
    });
  }

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
          IconButton(
            onPressed: _loading ? null : _loadPanel,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsScreen(staffName: widget.staffName),
                  ),
                );
              },
              child: const AvatarWidget(size: 40),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPanel,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_loading && _summary == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null) _buildErrorCard(),
                if (_summary != null) ...[
                  _buildOverview(_summary!),
                  const SizedBox(height: 24),
                  _buildNowListeningSection(_summary!),
                  const SizedBox(height: 24),
                  _buildTodayByElderSection(_summary!),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(_summary!),
                ] else if (!_loading)
                  _buildEmptyCard('No music monitoring data yet.'),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                color: _deepMint.withValues(alpha: 0.35),
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
                'Music monitoring',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live elder listening status and category trends',
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
    );
  }

  Widget _buildOverview(MusicDashboardSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _deepMint.withValues(alpha: 0.12),
            _lightMint.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _deepMint.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _deepMint.withValues(alpha: 0.08),
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
              Icon(Icons.headphones_rounded, color: _deepMint, size: 24),
              const SizedBox(width: 8),
              Text(
                'Live overview',
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
            '${summary.activeListenersCount} elder${summary.activeListenersCount == 1 ? '' : 's'} listening now',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary.mostPlayedCategory == null
                ? 'Most played category: not enough data yet'
                : 'Most played category today: ${_formatCategory(summary.mostPlayedCategory!)}'
                    '${summary.mostPlayedCategorySeconds == null ? '' : ' (${_formatDuration(summary.mostPlayedCategorySeconds!)})'}',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.album_outlined,
                  label: 'Now playing',
                  value: '${summary.nowPlaying.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  icon: Icons.schedule,
                  label: 'Updated',
                  value: _formatDateTime(summary.generatedAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _deepMint.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _deepMint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowListeningSection(MusicDashboardSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Currently listening', Icons.graphic_eq),
        const SizedBox(height: 12),
        if (summary.nowPlaying.isEmpty)
          _buildEmptyCard('No elder is listening right now.')
        else
          ...summary.nowPlaying.map((item) {
            return _infoCard(
              leading: Icons.play_circle_fill_rounded,
              title: item.elderName,
              subtitle:
                  '${item.title}  ${_formatCategory(item.category)}  Started ${_formatDateTime(item.playStart)}',
            );
          }),
      ],
    );
  }

  Widget _buildTodayByElderSection(MusicDashboardSummary summary) {
    final sorted = [...summary.listeningTodaySecondsByElder]
      ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Listening today', Icons.people_alt_rounded),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          _buildEmptyCard('No listening recorded today yet.')
        else
          ...sorted.map((item) {
            return _infoCard(
              leading: Icons.person,
              title: item.elderName,
              subtitle: 'Listening time today: ${_formatDuration(item.totalSeconds)}',
              trailing: Text(
                _formatDuration(item.totalSeconds),
                style: TextStyle(
                  color: _deepMint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentActivitySection(MusicDashboardSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent finished listening', Icons.history),
        const SizedBox(height: 12),
        if (summary.lastPlayedByElder.isEmpty)
          _buildEmptyCard('No completed listening session yet.')
        else
          ...summary.lastPlayedByElder.take(8).map((item) {
            return _infoCard(
              leading: Icons.access_time,
              title: item.elderName,
              subtitle: 'Last listened at ${_formatDateTime(item.lastPlayedAt)}',
            );
          }),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
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
    );
  }

  Widget _infoCard({
    required IconData leading,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _deepMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(leading, color: _deepMint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong.',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _loadPanel,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: _textSecondary,
        ),
      ),
    );
  }

  String _formatCategory(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month} $hour:$minute $suffix';
  }
}
