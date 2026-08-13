import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Background Notification Service
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const PremiumMusicApp());
}

class PremiumMusicApp extends StatelessWidget {
  const PremiumMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Premium Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark theme
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: const HomeLayout(),
    );
  }
}

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  int _currentIndex = 0;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  void _requestPermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      _fetchSongs();
    } else {
      await Permission.audio.request();
      _fetchSongs();
    }
  }

  void _fetchSongs() async {
    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // FILTER: Only real music (removes call recordings/short audio)
    List<SongModel> filteredSongs = songs.where((song) => 
      song.isMusic == true && (song.duration ?? 0) > 60000
    ).toList();

    setState(() {
      _songs = filteredSongs;
    });

    // Setup Playlist for Background Audio
    final playlist = ConcatenatingAudioSource(
      children: filteredSongs.map((song) => AudioSource.uri(
        Uri.parse(song.uri!),
        tag: MediaItem(
          id: song.id.toString(),
          title: song.title,
          artist: song.artist ?? "Unknown Artist",
        ),
      )).toList(),
    );
    await _audioPlayer.setAudioSource(playlist);
  }

  void _playSong(int index) {
    _audioPlayer.seek(Duration.zero, index: index);
    _audioPlayer.play();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerScreen(audioPlayer: _audioPlayer, songs: _songs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Library', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: _songs.isEmpty
          ? const Center(child: CupertinoActivityIndicator(radius: 20))
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white10,
                    ),
                    child: QueryArtworkWidget(
                      id: _songs[index].id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: const Icon(CupertinoIcons.music_note, color: Colors.white54),
                    ),
                  ),
                  title: Text(_songs[index].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_songs[index].artist ?? 'Unknown', maxLines: 1, style: const TextStyle(color: Colors.white54)),
                  onTap: () => _playSong(index),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: CupertinoColors.systemBlue,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.music_albums), label: 'Playlist'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart_fill), label: 'Liked'),
        ],
      ),
    );
  }
}

// PREMIUM GLASSMORPHISM PLAYER SCREEN
class PlayerScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final List<SongModel> songs;

  const PlayerScreen({super.key, required this.audioPlayer, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image / Color
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C3E50), Color(0xFF000000)],
              ),
            ),
          ),
          // Glassmorphism Blur Effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
          SafeArea(
            child: StreamBuilder<SequenceState?>(
              stream: audioPlayer.sequenceStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state?.sequence.isEmpty ?? true) return const SizedBox();
                final metadata = state!.currentSource!.tag as MediaItem;
                
                return Column(
                  children: [
                    // App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text("Now Playing", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(CupertinoIcons.ellipsis, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Artwork with Glass effect shadow
                    Container(
                      height: 300,
                      width: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: QueryArtworkWidget(
                          id: int.parse(metadata.id),
                          type: ArtworkType.AUDIO,
                          artworkHeight: 300,
                          artworkWidth: 300,
                          nullArtworkWidget: Container(
                            color: Colors.white10,
                            child: const Icon(CupertinoIcons.music_note, size: 100, color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    // Title and Artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          Text(metadata.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(metadata.artist ?? "Unknown", maxLines: 1, style: const TextStyle(fontSize: 18, color: Colors.white54)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: StreamBuilder<Duration>(
                        stream: audioPlayer.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = audioPlayer.duration ?? Duration.zero;
                          return ProgressBar(
                            progress: position,
                            total: duration,
                            progressBarColor: Colors.white,
                            baseBarColor: Colors.white24,
                            thumbColor: Colors.white,
                            timeLabelTextStyle: const TextStyle(color: Colors.white70),
                            onSeek: (duration) {
                              audioPlayer.seek(duration);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white, size: 35), onPressed: () => audioPlayer.seekToPrevious()),
                          StreamBuilder<PlayerState>(
                            stream: audioPlayer.playerStateStream,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final playing = playerState?.playing ?? false;
                              return GestureDetector(
                                onTap: () {
                                  if (playing) {
                                    audioPlayer.pause();
                                  } else {
                                    audioPlayer.play();
                                  }
                                },
                                child: Container(
                                  height: 75,
                                  width: 75,
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 20)]),
                                  child: Icon(playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: Colors.black, size: 40),
                                ),
                              );
                            },
                          ),
                          IconButton(icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 35), onPressed: () => audioPlayer.seekToNext()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
