// cats_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fl_chart/fl_chart.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import '../models/cat.dart';
import '../snackbar_helper.dart';
import '../models/user.dart';

// ─── Main Tab ────────────────────────────────────────────────────────────────

class CatsTab extends StatelessWidget {
  const CatsTab({super.key});

  static final _firebase = FirebaseService();

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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      if (context.mounted) SnackBarHelper.showSuccess(context, '${cat.name} deleted.');
    } catch (e) {
      if (context.mounted) SnackBarHelper.showError(context, 'Failed to delete ${cat.name}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = User.currentUser?.userId;

    return Scaffold(
      appBar: AppBar(title: const Text('My Cats'), centerTitle: true),
      body: StreamBuilder<List<Cat>>(
        stream: userId != null ? _firebase.streamCats(userId) : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red)));
          }

          final cats = snapshot.data ?? [];
          if (cats.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.pets, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No Cats Registered', style: Theme.of(context).textTheme.headlineSmall),
              ]),
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
          onPressed: () => User.isLoggedIn
              ? _openCatDialog(context)
              : SnackBarHelper.showError(context, 'Please log in.'),
          icon: const Icon(Icons.add),
          label: const Text('Add Cat'),
        ),
      ),
    );
  }
}

// ─── Add/Edit Dialog ─────────────────────────────────────────────────────────

class _CatDialog extends StatefulWidget {
  final Cat? cat;
  const _CatDialog({this.cat});

  @override
  State<_CatDialog> createState() => _CatDialogState();
}

class _CatDialogState extends State<_CatDialog> {
  static final _firebase = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _age;

  String _gender = 'Male';
  String? _imageName;       // filename stored in Firestore
  String? _previewPath;     // full local path for showing image
  bool _loading = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _name  = TextEditingController(text: widget.cat?.name ?? '');
    _breed = TextEditingController(text: widget.cat?.breed ?? '');
    _age   = TextEditingController(text: widget.cat?.age.toString() ?? '');
    _gender = widget.cat?.gender ?? 'Male';
    _imageName = widget.cat?.imgPath;
    if (_imageName != null) _resolvePreviewPath();
  }

  @override
  void dispose() {
    _name.dispose(); _breed.dispose(); _age.dispose();
    super.dispose();
  }

  // Convert stored filename → full device path for the preview image
  Future<void> _resolvePreviewPath() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) setState(() => _previewPath = p.join(dir.path, p.basename(_imageName!)));
  }

  // Gallery → crop → save locally → store filename
  Future<void> _pickImage() async {
    setState(() => _loading = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Cat Photo',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Cat Photo', aspectRatioLockEnabled: true),
        ],
      );
      if (cropped == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'cat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = p.join(dir.path, fileName);
      await File(destPath).writeAsBytes(await cropped.readAsBytes(), flush: true);

      if (mounted) {
        setState(() {
          _imageName  = fileName;
          _previewPath = destPath;
          _imageError  = null;
        });
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Image error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageName == null) {
      setState(() => _imageError = 'Image required');
      return;
    }

    final user = User.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    final payload = Cat(
      catId:  widget.cat?.catId,
      userId: user.userId,
      name:   _name.text.trim(),
      breed:  _breed.text.trim(),
      gender: _gender,
      age:    int.tryParse(_age.text) ?? 0,
      imgPath: _imageName,  // save filename only, not full path
    );

    try {
      if (widget.cat != null) {
        await _firebase.updateCat(payload.catId!, payload.toJson());
      } else {
        await _firebase.createCat(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, widget.cat != null ? 'Updated!' : 'Added!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to save: $e');
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.cat != null ? 'Edit Cat' : 'Add New Cat'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar / image picker
              GestureDetector(
                onTap: _loading ? null : _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage: _previewPath != null ? FileImage(File(_previewPath!)) : null,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : (_previewPath == null ? const Icon(Icons.camera_alt, size: 32) : null),
                ),
              ),
              if (_imageError != null)
                Text(_imageError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              const SizedBox(height: 24),
              TextFormField(controller: _name,  decoration: _inputDeco('Name',  Icons.pets)),
              const SizedBox(height: 16),
              TextFormField(controller: _breed, decoration: _inputDeco('Breed', Icons.category)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _age,
                    decoration: _inputDeco('Age', Icons.cake),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'Male',   child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                    decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _loading ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

// ─── Cat Card (list item) ─────────────────────────────────────────────────────

class _CatCard extends StatelessWidget {
  final Cat cat;
  final VoidCallback onEdit, onDelete;
  const _CatCard({required this.cat, required this.onEdit, required this.onDelete});

  Future<String> _getImagePath() async {
    if (cat.imgPath == null || cat.imgPath!.isEmpty) return '';
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, p.basename(cat.imgPath!));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatDetailScreen(cat: cat))),
        child: Column(
          children: [
            if (cat.imgPath != null)
              FutureBuilder<String>(
                future: _getImagePath(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox(height: 200);
                  final file = File(snapshot.data!);
                  if (!file.existsSync()) {
                    return const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image)));
                  }
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.file(
                      file, height: 200, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                    ),
                  );
                },
              ),
            ListTile(
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${cat.breed} • ${cat.age} years'),
              trailing: PopupMenuButton(
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit',   child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cat Detail Screen ────────────────────────────────────────────────────────

class CatDetailScreen extends StatefulWidget {
  final Cat cat;
  const CatDetailScreen({super.key, required this.cat});

  @override
  State<CatDetailScreen> createState() => _CatDetailScreenState();
}

class _CatDetailScreenState extends State<CatDetailScreen> {
  final _firebase = FirebaseService();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.cat.imgPath != null && widget.cat.imgPath!.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      _imagePath = p.join(dir.path, p.basename(widget.cat.imgPath!));
    }
    await _loadHistory();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadHistory() async {
    try {
      final records = await _firebase.getHistoryForCat(widget.cat.catId!);
      _history = await Future.wait(records.map((r) async {
        String label = 'Unknown';
        if (r.translationId != null) {
          final doc = await _firebase.collection('translations').doc(r.translationId).get();
          label = doc.exists ? (doc.data()?['className'] ?? 'Unknown') : 'Unknown';
        }
        return {
          'label': label,
          'translation': r.textTranslation ?? '',
          'time': r.translationDatetime?.toIso8601String() ?? '',
        };
      }));
    } catch (e) {
      debugPrint('[CatDetail] Error: $e');
    }
  }

  Color _colorForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'food':        return Colors.orangeAccent;
      case 'angry':       return Colors.redAccent;
      case 'resting':     return Colors.greenAccent;
      case 'mothercall':  return Colors.blueAccent;
      case 'isolation':   return Colors.deepPurpleAccent;
      default:            return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cat.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _buildHeader(),
                const SizedBox(height: 50),
                if (_history.isNotEmpty) ...[
                  _buildAnalytics(),
                  const Divider(height: 48, indent: 20, endIndent: 20),
                ],
                Padding(
                  padding: EdgeInsets.fromLTRB(20, _history.isEmpty ? 24 : 0, 20, 12),
                  child: Text(
                    'Translation History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Center(child: Text('No translation history found for this cat.')),
                  )
                else
                  ..._history.map((item) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline, size: 20)),
                        title: Text(item['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['translation']),
                        trailing: Text(
                          item['time'].isNotEmpty
                              ? DateFormat.yMMMd().format(DateTime.parse(item['time']))
                              : '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final file = _imagePath != null ? File(_imagePath!) : null;
    final hasImage = file != null && file.existsSync();
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover image
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            image: hasImage ? DecorationImage(image: FileImage(file), fit: BoxFit.cover) : null,
          ),
          child: hasImage ? null : Center(child: Icon(Icons.pets, size: 80, color: cs.primary.withOpacity(0.2))),
        ),
        // Floating info card
        Positioned(
          bottom: -40, left: 20, right: 20,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _infoChip(Icons.category_outlined, 'Breed',  widget.cat.breed),
                  _divider(),
                  _infoChip(Icons.cake_outlined,     'Age',    '${widget.cat.age}y'),
                  _divider(),
                  _infoChip(widget.cat.gender == 'Male' ? Icons.male : Icons.female, 'Gender', widget.cat.gender),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(height: 30, width: 1, color: Theme.of(context).dividerColor.withOpacity(0.5));

  Widget _infoChip(IconData icon, String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Theme.of(context).primaryColor, size: 22),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
    ],
  );

  Widget _buildAnalytics() {
    final counts = <String, int>{};
    for (final item in _history) {
      final label = item['label'] as String;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final total = _history.length;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PieChart(PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                    sections: counts.entries.map((e) => PieChartSectionData(
                      color: _colorForLabel(e.key),
                      value: e.value.toDouble(),
                      title: '',
                      radius: 18,
                    )).toList(),
                  )),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: counts.entries.map((e) {
                      final percent = (e.value / total * 100).toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorForLabel(e.key), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key.toLowerCase() == 'mothercall' ? 'Mother Call' : e.key,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('$percent%', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}