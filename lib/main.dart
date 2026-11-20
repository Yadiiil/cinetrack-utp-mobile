import 'package:flutter/material.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  final _sampleShows = [
    {
      'title': 'Dark',
      'genre': 'Sci-Fi • Thriller',
      'rating': '8.7',
      'summary':
          'Sebuah keluarga di kota kecil Jerman mengungkap misteri perjalanan waktu lintas generasi.',
    },
    {
      'title': 'Stranger Things',
      'genre': 'Drama • Fantasy',
      'rating': '8.6',
      'summary':
          'Hilangnya seorang anak memicu penyelidikan penuh rahasia supernatural dan eksperimen rahasia.',
    },
    {
      'title': 'Sherlock',
      'genre': 'Crime • Mystery',
      'rating': '8.8',
      'summary':
          'Detektif eksentrik memecahkan berbagai kasus rumit di London modern bersama rekannya.',
    },
  ];

  final _watchlist = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleWatchlist(Map<String, String> show) {
    setState(() {
      final exists = _watchlist.any((item) => item['title'] == show['title']);
      if (exists) {
        _watchlist.removeWhere((item) => item['title'] == show['title']);
      } else {
        _watchlist.add(show);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CineTrack'),
        actions: [
          IconButton(
            tooltip: 'Watchlist',
            icon: const Icon(Icons.bookmarks),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WatchlistPage(
                    watchlist: _watchlist,
                    onRemove: _toggleWatchlist,
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
              'Cari Film & Serial',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ketik judul film atau serial...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _sampleShows.length,
                itemBuilder: (context, index) {
                  final show = _sampleShows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.movie),
                      ),
                      title: Text(
                        show['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(show['genre'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(show['rating'] ?? '-'),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailPage(
                              show: show,
                              isSaved: _watchlist.any(
                                (item) => item['title'] == show['title'],
                              ),
                              onToggleSave: () => _toggleWatchlist(show),
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
  final Map<String, String> show;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const DetailPage({
    super.key,
    required this.show,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
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
            const SizedBox(height: 20),
            const Text(
              'Sinopsis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(widget.show['summary'] ?? 'Tidak ada sinopsis.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onToggleSave();
                  setState(() {
                    _saved = !_saved;
                  });
                },
                icon: Icon(_saved ? Icons.bookmark_remove : Icons.bookmark_add),
                label: Text(
                  _saved ? 'Hapus dari Watchlist' : 'Simpan ke Watchlist',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WatchlistPage extends StatefulWidget {
  final watchlist;
  final void Function(Map<String, String>) onRemove;

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
        title: const Text('Watchlist Saya'),
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.bookmark),
                    ),
                    title: Text(item['title'] ?? ''),
                    subtitle: Text(item['genre'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        widget.onRemove(item);
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