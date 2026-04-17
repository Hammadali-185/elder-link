import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/medicine_schedule_monitor.dart';
import '../services/music_player_service.dart';

/// Pick another resident from recent elder history on this device.
class SwitchElderScreen extends StatefulWidget {
  const SwitchElderScreen({super.key, this.onBackTap});

  final VoidCallback? onBackTap;

  @override
  State<SwitchElderScreen> createState() => _SwitchElderScreenState();
}

class _ElderTile {
  _ElderTile({
    required this.id,
    required this.name,
    this.room,
  });

  final String id;
  final String name;
  final String? room;
}

class _SwitchElderScreenState extends State<SwitchElderScreen> {
  List<_ElderTile>? _rows;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load(attempt: 0);
  }

  /// [attempt] 0 = first pass; if we pruned server-gone ids from MRU, reload once with fresh prefs.
  Future<void> _load({required int attempt}) async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      await ApiService.mergeRecentHistoryWithServerElders();
      final ids = await ApiService.getRecentElderMongoIds();
      if (ids.isEmpty) {
        if (mounted) setState(() => _rows = []);
        return;
      }
      final rows = <_ElderTile>[];
      var prunedGone = false;
      for (final id in ids) {
        final r = await ApiService.fetchElderByIdResult(id);
        if (r.data != null) {
          final data = r.data!;
          final n = (data['name'] ?? '').toString().trim();
          final room = (data['roomNumber'] ?? '').toString().trim();
          rows.add(
            _ElderTile(
              id: id,
              name: n.isEmpty ? 'Resident' : n,
              room: room.isEmpty ? null : room,
            ),
          );
        } else if (r.serverRejectedElder) {
          // Idempotent: handleInvalidElderReference already cleared MRU/active when applicable.
          await ApiService.removeElderIdFromRecentHistory(id);
          prunedGone = true;
        }
      }
      if (!mounted) return;
      if (prunedGone && attempt == 0) {
        await _load(attempt: 1);
        return;
      }
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _onPick(_ElderTile row) async {
    final active = ApiService.activeElderMongoId?.trim();
    if (active != null && active == row.id) {
      widget.onBackTap?.call();
      return;
    }
    setState(() => _busyId = row.id);
    try {
      final fetch = await ApiService.fetchElderByIdResult(row.id);
      if (!mounted) return;
      if (fetch.data == null) {
        if (fetch.serverRejectedElder) {
          await ApiService.removeElderIdFromRecentHistory(row.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This resident is no longer on the server')),
            );
            await _load(attempt: 0);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load resident (check connection)')),
          );
        }
        return;
      }
      final data = fetch.data!;
      final prev = ApiService.userName?.trim() ?? '';
      final newName = (data['name'] ?? '').toString().trim();
      if (prev.isNotEmpty && newName.isNotEmpty && prev != newName) {
        await MusicPlayerService.instance.stop();
      }
      final ok = await ApiService.applyFetchedElderProfile(data);
      if (!mounted) return;
      if (ok) {
        MedicineScheduleMonitor.instance.onUserIdentityChanged();
        widget.onBackTap?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not switch')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Switch resident',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          Positioned(
            top: 28,
            left: 28,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(25),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }
    if (_rows == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF90CAF9)),
      );
    }
    if (_rows!.isEmpty) {
      return const Center(
        child: Text(
          'No residents found.\nCheck Wi‑Fi and that the backend lists elders.\nYou can also add one in My Info.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
        ),
      );
    }
    final active = ApiService.activeElderMongoId?.trim();
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _rows!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final row = _rows![i];
        final isActive = active != null && active == row.id;
        final busy = _busyId == row.id;
        return Material(
          color: isActive ? const Color(0xFF1E3A5F) : const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: busy ? null : () => _onPick(row),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (row.room != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Room ${row.room}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (isActive)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'Active',
                        style: TextStyle(color: Color(0xFF81C784), fontSize: 11),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
