import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CineTrackApp());
}

class CineTrackApp extends StatelessWidget {
  const CineTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

String _stripHtml(String? htmlText) {
  if (htmlText == null || htmlText.isEmpty) {
    return 'Tidak ada sinopsis tersedia.';
  }
  return htmlText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _watchlistKey = 'cinetrack_watchlist_v2';
  static const String _historyKey = 'cinetrack_search_history_v1';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  final _shows = [];
  final _watchlist = [];
  final _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _fetchShows('dark', saveToHistory: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rawWatchlist = prefs.getString(_watchlistKey);
      final loadedWatchlist = [];
      if (rawWatchlist != null && rawWatchlist.isNotEmpty) {
        final decoded = jsonDecode(rawWatchlist);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              loadedWatchlist.add({
                'id': item['id']?.toString() ?? '',
                'title': item['title']?.toString() ?? '',
                'genre': item['genre']?.toString() ?? '',
                'rating': item['rating']?.toString() ?? '-',
                'summary': item['summary']?.toString() ?? '',
                'note': item['note']?.toString() ?? '',
              });
            }
          }
        }
      }

      final savedHistory = prefs.getStringList(_historyKey) ?? [];

      if (mounted) {
        setState(() {
          _watchlist.clear();
          _watchlist.addAll(loadedWatchlist);
          _searchHistory.clear();
          _searchHistory.addAll(savedHistory);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveWatchlistToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchlistKey, jsonEncode(_watchlist));
  }

  Future<void> _addSearchHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    _searchHistory.removeWhere(
      (item) => item.toString().toLowerCase() == normalized.toLowerCase(),
    );
    _searchHistory.insert(0, normalized);
    if (_searchHistory.length > 6) {
      _searchHistory.removeRange(6, _searchHistory.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final stringHistory = _searchHistory.map((e) => e.toString()).toList();
    await prefs.setStringList(_historyKey, stringHistory);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clearSearchHistory() async {
    _searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchShows(String query, {bool saveToHistory = true}) async {
    final cleanQuery = query.trim().isEmpty ? 'batman' : query.trim();
    if (saveToHistory && query.trim().isNotEmpty) {
      await _addSearchHistory(cleanQuery);
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.https(
        'api.tvmaze.com',
        '/search/shows',
        {'q': cleanQuery},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsedShows = [];

        if (data is List) {
          for (final entry in data) {
            if (entry is Map && entry['show'] is Map) {
              final show = entry['show'] as Map;
              final genres = (show['genres'] is List)
                  ? (show['genres'] as List).map((g) => g.toString()).toList()
                  : [];
              final rating = (show['rating'] is Map)
                  ? (show['rating']['average']?.toString() ?? '-')
                  : '-';

              parsedShows.add({
                'id': show['id']?.toString() ?? '',
                'title': show['name']?.toString() ?? 'Tanpa Judul',
                'genre': genres.isEmpty ? 'Umum' : genres.join(' • '),
                'rating': rating == 'null' ? '-' : rating,
                'summary': _stripHtml(show['summary']?.toString()),
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            _shows.clear();
            _shows.addAll(parsedShows);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal memuat data (Kode: ${response.statusCode}).';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan koneksi atau jaringan.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveOrUpdateWatchlist(Map show, String note) async {
    final index =
        _watchlist.indexWhere((item) => item['title'] == show['title']);
    final entry = {
      'id': show['id'] ?? '',
      'title': show['title'] ?? '',
      'genre': show['genre'] ?? '',
      'rating': show['rating'] ?? '-',
      'summary': show['summary'] ?? '',
      'note': note.trim(),
    };

    if (index >= 0) {
      _watchlist[index] = entry;
    } else {
      _watchlist.add(entry);
    }

    await _saveWatchlistToStorage();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Watchlist & catatan tersimpan ke Local Storage'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _removeFromWatchlist(Map show) async {
    _watchlist.removeWhere((item) => item['title'] == show['title']);
    await _saveWatchlistToStorage();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dihapus dari Watchlist'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  String _getSavedNote(String title) {
    final found = _watchlist.where((item) => item['title'] == title).toList();
    if (found.isEmpty) return '';
    return found.first['note']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CineTrack'),
        actions: [
          IconButton(
            tooltip: 'Watchlist & Catatan',
            icon: Badge(
              label: Text('${_watchlist.length}'),
              isLabelVisible: _watchlist.isNotEmpty,
              child: const Icon(Icons.bookmarks),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WatchlistPage(
                    watchlist: _watchlist,
                    onRemove: _removeFromWatchlist,
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cari Film & Serial (TVMaze API)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _fetchShows,
              decoration: InputDecoration(
                hintText: 'Ketik judul lalu tekan Enter...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Cari',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _fetchShows(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_searchHistory.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Riwayat Pencarian:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSearchHistory,
                    child: const Text('Hapus Riwayat', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _searchHistory.map((keyword) {
                  return ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(keyword.toString()),
                    onPressed: () {
                      _searchController.text = keyword.toString();
                      _fetchShows(keyword.toString(), saveToHistory: false);
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () =>
                                    _fetchShows(_searchController.text),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _shows.isEmpty
                          ? const Center(
                              child: Text('Film atau serial tidak ditemukan.'),
                            )
                          : ListView.builder(
                              itemCount: _shows.length,
                              itemBuilder: (context, index) {
                                final show = _shows[index];
                                final isSaved = _watchlist.any(
                                  (item) => item['title'] == show['title'],
                                );
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        isSaved ? Icons.bookmark : Icons.movie,
                                      ),
                                    ),
                                    title: Text(
                                      show['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(show['genre'] ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 18,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(show['rating'] ?? '-'),
                                      ],
                                    ),
                                    onTap: () {
                                      final title =
                                          show['title']?.toString() ?? '';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailPage(
                                            show: show,
                                            isSaved: isSaved,
                                            initialNote: _getSavedNote(title),
                                            onSave: (note) =>
                                                _saveOrUpdateWatchlist(
                                                    show, note),
                                            onRemove: () =>
                                                _removeFromWatchlist(show),
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Map show;
  final bool isSaved;
  final String initialNote;
  final Future<void> Function(String note) onSave;
  final Future<void> Function() onRemove;

  const DetailPage({
    super.key,
    required this.show,
    required this.isSaved,
    required this.initialNote,
    required this.onSave,
    required this.onRemove,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late bool _saved;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.show['title'] ?? 'Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.movie, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.show['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(widget.show['genre'] ?? ''),
                    ],
                  ),
                ),
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 4),
                Text(widget.show['rating'] ?? '-'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sinopsis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(widget.show['summary'] ?? 'Tidak ada sinopsis.'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Catatan Pribadi (Disimpan Lokal)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tulis catatan tontonanmu (opsional)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await widget.onSave(_noteController.text);
                  setState(() {
                    _saved = true;
                  });
                },
                icon: const Icon(Icons.bookmark_added),
                label: Text(
                  _saved
                      ? 'Perbarui Watchlist & Catatan'
                      : 'Simpan ke Watchlist',
                ),
              ),
            ),
            if (_saved) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onRemove();
                    setState(() {
                      _saved = false;
                      _noteController.clear();
                    });
                  },
                  icon: const Icon(Icons.bookmark_remove),
                  label: const Text('Hapus dari Watchlist'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WatchlistPage extends StatefulWidget {
  final watchlist;
  final Future<void> Function(Map) onRemove;

  const WatchlistPage({
    super.key,
    required this.watchlist,
    required this.onRemove,
  });

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist & Catatan Saya'),
      ),
      body: widget.watchlist.isEmpty
          ? const Center(
              child: Text('Belum ada film atau serial di watchlist.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.watchlist.length,
              itemBuilder: (context, index) {
                final item = widget.watchlist[index];
                final note = item['note']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.bookmark),
                    ),
                    title: Text(
                      item['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['genre'] ?? ''),
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Catatan: $note',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.onRemove(item);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}