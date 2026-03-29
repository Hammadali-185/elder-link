import '../models/music_track.dart';

abstract final class MusicCatalog {
  static const List<MusicTrack> songs = [
    MusicTrack(
      id: 'song_dil_to_bacha_hai_ji',
      title: 'Dil To Bacha Hai Ji',
      artist: 'Song',
      category: 'song',
      assetPath: 'assets/audio/song_dill_to_bacha_he_ji.mp3',
    ),
  ];

  static const List<MusicTrack> quran = [
    MusicTrack(
      id: 'quran_al_ikhlas',
      title: 'Talawat Al-Ikhlas',
      artist: 'Quran',
      category: 'quran',
      assetPath: 'assets/audio/Talawat_Al_Ikhlas.mp3',
    ),
  ];

  static const List<MusicTrack> watchPlaylist = [
    ...songs,
    ...quran,
  ];
}
