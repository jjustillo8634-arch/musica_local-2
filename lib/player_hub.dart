import 'dart:async';
import 'dart:math';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'app_theme.dart';

class PlayerHub extends StatefulWidget {
  const PlayerHub({super.key});
  @override
  State<PlayerHub> createState() => _PlayerHubState();
}

class _PlayerHubState extends State<PlayerHub> {
  final AudioPlayer _player = AudioPlayer();
  final List<PlatformFile> _tracks = [];
  final Set<String> _favorites = {};
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _indexSub;
  bool _playing = false;
  bool _shuffle = false;
  bool _repeat = false;
  bool _sleepTimer = false;
  Timer? _sleepCountdown;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _index = 0;
  double _speed = 1.0;
  String? _error;

  PlatformFile? get _current => _tracks.isEmpty || _index >= _tracks.length ? null : _tracks[_index];
  bool get _isFavorite => _current != null && _favorites.contains(_current!.path ?? _current!.name);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
    _stateSub = _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
    _durationSub = _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _positionSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _indexSub = _player.currentIndexStream.listen((i) {
      if (mounted && i != null) setState(() => _index = i);
    });
  }

  Future<void> _addTracks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'aiff'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final newFiles = result.files.where((f) => f.path != null).toList();
    if (newFiles.isEmpty) {
      _message('No pude acceder a esos archivos. Prueba seleccionarlos desde Archivos.');
      return;
    }
    final wasEmpty = _tracks.isEmpty;
    final known = _tracks.map((f) => f.path).toSet();
    final additions = newFiles.where((f) => !known.contains(f.path)).toList();
    if (additions.isEmpty) {
      _message('Esas canciones ya están en la lista.');
      return;
    }
    setState(() { _tracks.addAll(additions); _error = null; });
    try {
      await _loadPlaylist(startIndex: wasEmpty ? 0 : _index, autoplay: wasEmpty);
      _message('Añadidas ${additions.length} canción(es)');
    } catch (e) {
      setState(() => _error = 'No se pudo abrir el audio seleccionado.');
      _message('Error al cargar audio: $e');
    }
  }

  Future<void> _loadPlaylist({int startIndex = 0, bool autoplay = true}) async {
    if (_tracks.isEmpty) return;
    final sources = _tracks.map((f) => AudioSource.uri(Uri.file(f.path!))).toList();
    await _player.setAudioSource(ConcatenatingAudioSource(children: sources), initialIndex: startIndex.clamp(0, _tracks.length - 1).toInt());
    await _player.setSpeed(_speed);
    if (autoplay) await _player.play();
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    try {
      if (_player.sequence.isEmpty) {
        await _loadPlaylist(startIndex: index);
      } else {
        await _player.seek(Duration.zero, index: index);
        await _player.play();
      }
      setState(() { _index = index; _error = null; });
    } catch (e) { _message('No se pudo reproducir esa canción: $e'); }
  }

  Future<void> _togglePlay() async {
    if (_tracks.isEmpty) { await _addTracks(); return; }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: _index);
      await _player.play();
    } else if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _next() async {
    if (_tracks.isEmpty) return;
    if (_shuffle && _tracks.length > 1) {
      var next = _index;
      while (next == _index) { next = Random().nextInt(_tracks.length); }
      await _playIndex(next);
    } else if (_index + 1 < _tracks.length) {
      await _player.seekToNext();
    } else if (_repeat) {
      await _playIndex(0);
    } else {
      await _player.pause();
      await _player.seek(Duration.zero, index: _index);
    }
  }

  Future<void> _previous() async {
    if (_position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_index > 0) {
      await _player.seekToPrevious();
    } else if (_repeat && _tracks.isNotEmpty) {
      await _playIndex(_tracks.length - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> _setSpeed() async {
    final options = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final next = options[(options.indexOf(_speed) + 1) % options.length];
    setState(() => _speed = next);
    await _player.setSpeed(next);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  String _time(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _title(String file) {
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }

  @override
  void dispose() {
    _sleepCountdown?.cancel();
    _stateSub?.cancel(); _durationSub?.cancel(); _positionSub?.cancel(); _indexSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final title = current == null ? 'Selecciona una canción' : _title(current.name);
    final maxMs = max(1, _duration.inMilliseconds).toDouble();
    final posMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: appPurple), onPressed: () => _showQueue()),
        actions: [
          TextButton(onPressed: _setSpeed, child: Text('${_speed.toStringAsFixed(_speed == 1 ? 1 : 2)}x', style: const TextStyle(color: appRed, fontSize: 12))),
          TextButton(onPressed: _toggleSleepTimer, child: Text(_sleepTimer ? '◷ 30m' : '◷ Off', style: const TextStyle(color: Colors.white70, fontSize: 12))),
          PopupMenuButton<String>(icon: const Icon(Icons.menu), onSelected: (v) {
            if (v == 'add') _addTracks();
            if (v == 'queue') _showQueue();
            if (v == 'favorites') _showFavorites();
            if (v == 'clear') _confirmClear();
            if (v == 'equalizer') _showEqualizerInfo();
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'add', child: Text('Añadir canciones')),
            PopupMenuItem(value: 'queue', child: Text('Lista de reproducción')),
            PopupMenuItem(value: 'favorites', child: Text('Favoritas')),
            PopupMenuItem(value: 'equalizer', child: Text('Ecualizador (próximamente)')),
            PopupMenuItem(value: 'clear', child: Text('Vaciar lista')),
          ]),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final artSize = min(constraints.maxWidth - 36, constraints.maxHeight * 0.47).clamp(190.0, 360.0).toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(19, 0, 19, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(
                width: artSize, height: artSize,
                decoration: BoxDecoration(color: const Color(0xFF1D1D20), borderRadius: BorderRadius.circular(22)),
                child: Icon(Icons.music_note_rounded, size: artSize * 0.22, color: appPurple.withOpacity(0.75)),
              )),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: InkWell(onTap: _addTracks, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: TextDecoration.underline, decorationColor: appRed)))),
                IconButton(visualDensity: VisualDensity.compact, onPressed: current == null ? null : () => setState(() {
                  final key = current.path ?? current.name;
                  _favorites.contains(key) ? _favorites.remove(key) : _favorites.add(key);
                }), icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, size: 20, color: appPurple)),
              ]),
              Text(current == null ? 'Artista desconocido' : 'Archivo local · ${_index + 1} de ${_tracks.length}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(_error!, style: const TextStyle(color: appRed, fontSize: 11))),
              const SizedBox(height: 7),
              Slider(value: posMs, max: maxMs, onChanged: _duration == Duration.zero ? null : (v) => setState(() => _position = Duration(milliseconds: v.round())), onChangeEnd: (v) => _player.seek(Duration(milliseconds: v.round()))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_time(_position), style: const TextStyle(color: Colors.white70, fontSize: 11)), Text(_time(_duration), style: const TextStyle(color: Colors.white70, fontSize: 11))]),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _roundButton(Icons.shuffle_rounded, active: _shuffle, onTap: () => setState(() => _shuffle = !_shuffle)),
                _roundButton(Icons.skip_previous_rounded, onTap: _previous, size: 48),
                GestureDetector(onTap: _togglePlay, child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: appRed, shape: BoxShape.circle), child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32))),
                _roundButton(Icons.skip_next_rounded, onTap: _next, size: 48),
                _roundButton(Icons.repeat_rounded, active: _repeat, onTap: _toggleRepeat),
              ]),
              const SizedBox(height: 6),
            ]),
          );
        }),
      ),
    );
  }

  Widget _roundButton(IconData icon, {required VoidCallback onTap, bool active = false, double size = 40}) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Container(width: size, height: size, decoration: BoxDecoration(color: active ? const Color(0xFF51446E) : const Color(0xFF29292D), shape: BoxShape.circle), child: Icon(icon, color: active ? appPurple : Colors.white70, size: 21)));

  void _showQueue() => showModalBottomSheet(context: context, backgroundColor: const Color(0xFF171719), isScrollControlled: true, builder: (ctx) => SafeArea(child: SizedBox(height: MediaQuery.of(ctx).size.height * .65, child: Column(children: [
    ListTile(title: const Text('Lista de reproducción', style: TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(onPressed: () { Navigator.pop(ctx); _addTracks(); }, icon: const Icon(Icons.add))),
    Expanded(child: _tracks.isEmpty ? const Center(child: Text('Añade música desde tu teléfono')) : ListView.builder(itemCount: _tracks.length, itemBuilder: (_, i) => ListTile(leading: Icon(i == _index ? Icons.volume_up : Icons.music_note, color: i == _index ? appRed : appPurple), title: Text(_title(_tracks[i].name), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(_tracks[i].name, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { Navigator.pop(ctx); _playIndex(i); }, trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { Navigator.pop(ctx); _removeTrack(i); }))))),
  ]))));

  Future<void> _removeTrack(int i) async {
    if (i < 0 || i >= _tracks.length) return;
    setState(() => _tracks.removeAt(i));
    if (_tracks.isEmpty) {
      await _player.stop();
      if (mounted) setState(() { _index = 0; _duration = Duration.zero; _position = Duration.zero; });
    } else {
      _index = _index.clamp(0, _tracks.length - 1).toInt();
      await _loadPlaylist(startIndex: _index, autoplay: true);
    }
  }

  void _showFavorites() {
    final favorites = _tracks.where((f) => _favorites.contains(f.path ?? f.name)).toList();
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF171719), builder: (ctx) => SafeArea(child: SizedBox(height: 350, child: Column(children: [const ListTile(title: Text('Canciones favoritas')), Expanded(child: favorites.isEmpty ? const Center(child: Text('Todavía no tienes favoritas')) : ListView(children: favorites.map((f) { final i = _tracks.indexOf(f); return ListTile(leading: const Icon(Icons.favorite, color: appRed), title: Text(_title(f.name), maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { Navigator.pop(ctx); _playIndex(i); }); }).toList()))]))));
  }

  void _confirmClear() => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Vaciar lista'), content: const Text('¿Quieres quitar todas las canciones de la lista actual?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), TextButton(onPressed: () async { Navigator.pop(ctx); setState(() { _tracks.clear(); _favorites.clear(); _index = 0; _duration = Duration.zero; _position = Duration.zero; }); await _player.stop(); }, child: const Text('Vaciar'))]));

  Future<void> _toggleRepeat() async {
    final enabled = !_repeat;
    setState(() => _repeat = enabled);
    await _player.setLoopMode(enabled ? LoopMode.all : LoopMode.off);
  }

  void _toggleSleepTimer() {
    if (_sleepTimer) {
      _sleepCountdown?.cancel();
      setState(() => _sleepTimer = false);
      _message('Temporizador desactivado');
    } else {
      setState(() => _sleepTimer = true);
      _sleepCountdown = Timer(const Duration(minutes: 30), () async {
        await _player.pause();
        if (mounted) setState(() => _sleepTimer = false);
      });
      _message('La música se pausará en 30 minutos');
    }
  }

  void _showEqualizerInfo() => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Ecualizador'), content: const Text('La interfaz del ecualizador todavía no está conectada al procesamiento de audio. Prefiero avisarte antes que mostrar controles que no cambian el sonido.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))]));
}
