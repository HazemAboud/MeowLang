import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/user.dart';

// ---------------------------------------------------------------------------
// CatsTab
// ---------------------------------------------------------------------------

class CatsTab extends StatelessWidget {
  const CatsTab({super.key});

  static final FirebaseService _firebase = FirebaseService();

  void _openCatDialog(BuildContext context, {Cat? cat}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CatDialog(cat: cat),
    );
  }

  Future<void> _deleteCat(BuildContext context, Cat cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cat'),
        content: Text('Delete ${cat.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firebase.deleteCat(cat.catId!);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${cat.name} deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete ${cat.name}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = User.currentUser?.userId;

    return Scaffold(
      appBar: AppBar(title: const Text('My Cats'), centerTitle: true),
      body: StreamBuilder<List<Cat>>(
        stream: userId != null
            ? _firebase.streamCats(userId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () {},
            );
          }

          final cats = snapshot.data ?? [];

          if (cats.isEmpty) {
            return _EmptyView(
              onAdd: () => _openCatDialog(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 100),
            itemCount: cats.length,
            itemBuilder: (context, index) => _CatCard(
              cat: cats[index],
              onEdit: () => _openCatDialog(context, cat: cats[index]),
              onDelete: () => _deleteCat(context, cats[index]),
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (!User.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please log in to add a cat.')),
              );
              return;
            }
            _openCatDialog(context);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Cat'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CatDialog — handles both create and edit
// ---------------------------------------------------------------------------

class _CatDialog extends StatefulWidget {
  final Cat? cat;
  const _CatDialog({this.cat});

  @override
  State<_CatDialog> createState() => _CatDialogState();
}

class _CatDialogState extends State<_CatDialog> {
  static final FirebaseService _firebase = FirebaseService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _age;
  String _gender = 'Male';
  String? _imagePath;
  bool _pickingImage = false;
  bool _saving = false;
  String? _imageError;

  bool get _isEdit => widget.cat != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cat;
    _name = TextEditingController(text: c?.name ?? '');
    _breed = TextEditingController(text: c?.breed ?? '');
    _age = TextEditingController(text: c?.age.toString() ?? '');
    _gender = c?.gender ?? 'Male';
    _imagePath = c?.imgPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        final dir = await getApplicationDocumentsDirectory();
        final dest = File(
            '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
        await File(picked.path).copy(dest.path);
        if (mounted) {
          setState(() {
            _imagePath = dest.path;
            _imageError = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null) {
      setState(() => _imageError = 'Image required');
      return;
    }

    final user = User.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    final payload = Cat(
      catId: widget.cat?.catId,
      userId: user.userId,
      name: _name.text.trim(),
      breed: _breed.text.trim(),
      gender: _gender,
      age: int.tryParse(_age.text) ?? 0,
      imgPath: _imagePath,
    );

    try {
      if (_isEdit) {
        await _firebase.updateCat(payload.catId!, payload.toJson());
      } else {
        await _firebase.createCat(payload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Cat updated!' : 'Cat added!')),
        );
      }
    } catch (e) {
      debugPrint('Save cat error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(_isEdit ? 'Edit Cat' : 'Add New Cat'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Image picker
              GestureDetector(
                onTap: _pickingImage ? null : _pickImage,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _imageError != null
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      backgroundImage: _imagePath != null
                          ? FileImage(File(_imagePath!))
                          : null,
                      child: _imagePath == null
                          ? Icon(
                              _pickingImage
                                  ? Icons.hourglass_empty
                                  : Icons.camera_alt,
                              size: 32,
                              color: _imageError != null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                            )
                          : null,
                    ),
                    if (_imageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _imageError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Name
              TextFormField(
                controller: _name,
                decoration: _inputDecoration('Name', Icons.pets),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Breed
              TextFormField(
                controller: _breed,
                decoration: _inputDecoration('Breed', Icons.category),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Age + Gender row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      decoration:
                          _inputDecoration('Age', Icons.calendar_today),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ---------------------------------------------------------------------------
// _CatCard
// ---------------------------------------------------------------------------

class _CatCard extends StatelessWidget {
  final Cat cat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CatCard({
    required this.cat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CatDetailScreen(cat: cat)),
          ),
          onLongPress: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with menu overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: cat.imgPath != null
                          ? Hero(
                              tag: 'cat_image_${cat.catId}',
                              child: Image.file(
                                File(cat.imgPath!),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.3),
                              child: Icon(Icons.pets,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                      .withOpacity(0.5)),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black26,
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (v) {
                          if (v == 'edit') onEdit();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Info row
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cat.breed} • ${cat.age} years old',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.8),
                              ),
                        ),
                      ],
                    ),
                    Icon(
                      cat.gender == 'Female' ? Icons.female : Icons.male,
                      color: cat.gender == 'Female'
                          ? Colors.pinkAccent
                          : Colors.blueAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets,
              size: 80,
              color:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            'No Cats Registered',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Theme.of(context).disabledColor),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load cats',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CatDetailScreen
// ---------------------------------------------------------------------------

class CatDetailScreen extends StatefulWidget {
  final Cat cat;
  const CatDetailScreen({super.key, required this.cat});

  @override
  State<CatDetailScreen> createState() => _CatDetailScreenState();
}

class _CatDetailScreenState extends State<CatDetailScreen> {
  final FirebaseService _firebase = FirebaseService();

  List<Map<String, dynamic>> _history = [];
  Map<String, double> _labelCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.cat.catId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final records = await _firebase.getHistoryForCat(widget.cat.catId!);
      final history = records
          .map((r) => {
                'label': r.textTranslation ?? 'Unknown',
                'time': r.translationDatetime?.toIso8601String(),
              })
          .toList();

      final counts = <String, double>{};
      for (final r in history) {
        final label = r['label'] as String;
        counts[label] = (counts[label] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _history = history;
          _labelCounts = counts;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _chartColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.amber,
  ];

  List<PieChartSectionData> _buildSections() {
    if (_labelCounts.isEmpty) {
      return [
        PieChartSectionData(
            color: Colors.grey.shade300, value: 1, title: '', radius: 80)
      ];
    }
    int i = 0;
    return _labelCounts.entries.map((e) {
      final color = _chartColors[i++ % _chartColors.length];
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '${e.key}\n(${e.value.toInt()})',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero app bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.cat.imgPath != null
                  ? Hero(
                      tag: 'cat_image_${widget.cat.catId}',
                      child: Image.file(
                        File(widget.cat.imgPath!),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        color: Colors.black.withOpacity(0.3),
                        colorBlendMode: BlendMode.darken,
                      ),
                    )
                  : Container(
                      color: Colors.grey,
                      child: const Icon(Icons.pets,
                          size: 100, color: Colors.white54),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoChip(Icons.category, widget.cat.breed),
                      _InfoChip(
                        widget.cat.gender == 'Female'
                            ? Icons.female
                            : Icons.male,
                        widget.cat.gender,
                      ),
                      _InfoChip(Icons.cake, '${widget.cat.age} years'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Analytics
                  Text('Translation Analytics',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  _labelCounts.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No translation history to analyze.'),
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: _buildSections(),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Recent History',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),

          // History list
          _history.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('No history records found.',
                          style: TextStyle(
                              color: Theme.of(context).disabledColor)),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final record = _history[index];
                      final timeStr = record['time'] as String?;
                      String formattedDate = 'No date';
                      if (timeStr != null) {
                        try {
                          formattedDate = DateFormat.yMMMd()
                              .add_jm()
                              .format(DateTime.parse(timeStr));
                        } catch (_) {}
                      }
                      return ListTile(
                        leading: const Icon(Icons.volume_up),
                        title: Text(record['label'] as String),
                        subtitle: Text(formattedDate),
                      );
                    },
                    childCount: _history.length,
                  ),
                ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon,
          size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
    );
  }
}