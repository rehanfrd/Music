import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MaterialApp(home: MusicApp()));

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  void requestPermission() async {
    await Permission.storage.request();
    await Permission.audio.request();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Music Player")),
      body: FutureBuilder<List<SongModel>>(
        future: _audioQuery.querySongs(sortType: null, orderType: OrderType.ASC_OR_SMALLER, uriType: UriType.EXTERNAL, ignoreCase: true),
        builder: (context, item) {
          if (item.data == null) return const CircularProgressIndicator();
          if (item.data!.isEmpty) return const Text("No music found");
          return ListView.builder(
            itemCount: item.data!.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(item.data![index].title),
              onTap: () async {
                await _player.setAudioSource(AudioSource.uri(Uri.parse(item.data![index].uri!)));
                _player.play();
              },
            ),
          );
        },
      ),
    );
  }
}
