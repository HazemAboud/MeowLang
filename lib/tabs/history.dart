import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:meow_lang/DB/database_helper.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/historyRecord.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Cat> _cats = [];
  Cat? _selectedCat;
  List<HistoryRecord> _history = [];
  bool _isLoading = true;
  String? _error;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final cats = await DatabaseHelper.instance.getCats();
      final history = await DatabaseHelper.instance.readAllHistory();

      if (mounted) {
        setState(() {
          _cats = cats;
          // Default to first cat if none selected, or maintain selection if valid
          if (_cats.isNotEmpty) {
            if (_selectedCat == null || !_cats.any((c) => c.catId == _selectedCat!.catId)) {
              _selectedCat = _cats.first;
            }
          } else {
            _selectedCat = null;
          }
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load history.\n${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  List<HistoryRecord> get _filteredHistory {
    if (_selectedCat == null || _selectedCat!.catId == null) return [];
    return _history.where((r) => r.catId == _selectedCat!.catId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Oops!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Cats Registered',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Register a cat in the Profile tab to view history.'),
          ],
        ),
      );
    }

    final filteredList = _filteredHistory;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('Show history for: '),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Cat>(
                      value: _selectedCat,
                      isExpanded: true,
                      isDense: true,
                      items: _cats.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCat = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No history found for ${_selectedCat?.name}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final record = filteredList[index];
                    final translation = record.translation;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(Icons.graphic_eq, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(
                          record.textTranslation ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          translation?.dateTime?.toString().substring(0, 16) ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_outline),
                          onPressed: () {
                            if (translation?.audioPath != null) {
                              _audioPlayer.play(DeviceFileSource(translation!.audioPath!));
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}