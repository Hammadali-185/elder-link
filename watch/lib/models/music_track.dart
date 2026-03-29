/// A playable item: either [audioUrl] (network) or [assetPath] (bundled asset).
/// [category] is used for music analytics (MongoDB); no audio bytes are uploaded.
class MusicTrack {
  final String id;
  final String title;
  final String? artist;
  /// Analytics bucket, e.g. relaxing, old_favorites, watch_demo.
  final String category;
  final String? audioUrl;
  final String? assetPath;

  const MusicTrack({
    required this.id,
    required this.title,
    this.artist,
    required this.category,
    this.audioUrl,
    this.assetPath,
  });

  bool get isRemote => audioUrl != null && audioUrl!.isNotEmpty;
  bool get isAsset => assetPath != null && assetPath!.isNotEmpty;

  String get subtitleOrArtist => artist ?? (isRemote ? 'Streaming' : 'Local');
}
