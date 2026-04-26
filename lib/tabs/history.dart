import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cat.dart';
import '../models/historyRecord.dart';
import '../models/user.dart';
import 'package:meow_lang/backend/firebase_service.dart';

// Assuming your legacy User model is still used for session management, 
// but we fetch via FirebaseService now.

class HistoryTab extends StatefulWidget {
  /// If [initialCat] is non-null the tab will show history only for that cat
  /// and hide the cat selector dropdown.  This makes the widget reusable by
  /// [CatsTab].
  const HistoryTab({super.key, this.initialCat});

  final Cat? initialCat;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  Cat? _selectedCat;
  List<HistoryRecord> _history = [];
  bool _isLoading = true;
  String? _error;
  final FirebaseService _db = FirebaseService();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCat != null) {
        // Detail view: load history for the specific cat
        setState(() {
          _selectedCat = widget.initialCat;
          _isLoading = true;
        });
        _loadHistoryForCat(widget.initialCat!.catId!);
      } else {
        // Main tab view: listen for auth changes
        if (User.isLoggedIn) {
          _loadAllHistory();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      if (!User.isLoggedIn) throw Exception("User not logged in");
      final user = User.currentUser!;

      final records = await _db.getHistoryForUser(user.userId.toString());

      if (mounted) {
        setState(() {
          _isLoading = false;
          _history = records;
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

  Future<void> _loadHistoryForCat(String catId) async {
    try {
      final records = await _db.getHistoryForCat(catId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _history = records;
        });
      }
    } catch (e) {
      debugPrint('Error loading history for cat $catId: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  List<HistoryRecord> get _filteredHistory {
    if (_selectedDate == null) {
      return _history;
    }
    return _history.where((record) {
      final dt = record.translationDatetime;
      if (dt == null) return false;
      return dt.year == _selectedDate!.year &&
          dt.month == _selectedDate!.month &&
          dt.day == _selectedDate!.day;
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    return _buildContent();
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
                onPressed: () {if (mounted) widget.initialCat != null ? _loadHistoryForCat(widget.initialCat!.catId!) : _loadAllHistory();},
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!User.isLoggedIn && widget.initialCat == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Please Log In',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Log in on the Profile tab to view history.'),
          ],
        ),
      );
    }

    final filteredList = _filteredHistory;

    return Column(
      children: [
        // show selector only if we weren't prefiltered by an initial cat
        if (widget.initialCat == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  _selectedDate == null
                      ? 'All History'
                      : 'Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedDate = null),
                    tooltip: 'Clear filter',
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                  tooltip: 'Filter by date',
                ),
              ],
            ),
          ),
        Expanded(
           child: RefreshIndicator(
              onRefresh: () => widget.initialCat != null 
                  ? _loadHistoryForCat(widget.initialCat!.catId!) 
                  : _loadAllHistory(),
            
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No history found.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final record = filteredList[index];
                    final text = record.textTranslation ?? 'Unknown';
                    final catName = record.catName ?? _selectedCat?.name ?? 'Unknown Cat';
                    String subtitle = '';
                    if (record.translationDatetime != null) {
                      subtitle = DateFormat.yMMMd().add_jm().format(record.translationDatetime!.toLocal());
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(Icons.graphic_eq, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(
                          text,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.initialCat == null)
                              Text(
                                catName,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            if (subtitle.isNotEmpty)
                              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        trailing: null,
                      ),
                    );
                  },
                ),
           )
        ),
      ],
    );
  }
}