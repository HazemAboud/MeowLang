import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meow_lang/server_config.dart';
import 'package:meow_lang/models/user.dart';
import 'package:meow_lang/models/cat.dart';

class CatsTab extends StatefulWidget {
  const CatsTab({super.key});

  @override
  State<CatsTab> createState() => _CatsTabState();
}

class _CatsTabState extends State<CatsTab> {
  List<Cat> _cats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (User.isLoggedIn) {
      _loadCats();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCats() async {
    setState(() => _isLoading = true);
    try {
      _error = null;
      final user = User.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(Uri.parse(serverUrl('/cats?userId=${user.userId}')));
      if (response.statusCode == 200) {
        final List<dynamic> catMaps = jsonDecode(response.body);
        final cats = catMaps.map((catMap) => Cat.fromJson(catMap)).toList();
        if (mounted) {
          setState(() {
            _cats = cats;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load cats: ${response.body}');
      }
    } catch (e) {
      debugPrint('[CatsTab] Failed to load cats: $e');
      if (mounted) {
        _error = 'Failed to load cats: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _cats = []; // Clear cats on error
        });
      }
    }
  }

  void _showCatDialog({Cat? catToEdit}) {
    final nameController = TextEditingController(text: catToEdit?.name ?? '');
    final breedController = TextEditingController(text: catToEdit?.breed ?? '');
    final ageController =
        TextEditingController(text: catToEdit?.age.toString() ?? '');
    String gender = catToEdit?.gender ?? 'Male';
    String? selectedImage = catToEdit?.imgPath;
    bool isPickingImage = false;
    bool isSaving = false;
    String? imageError;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // helper to pick an image and copy it to app directory
            Future<void> pickImage() async {
              if (isPickingImage) return;
              setState(() => isPickingImage = true);
              try {
                final picker = ImagePicker();
                final picked =
                    await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final dest = File(
                      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
                  await File(picked.path).copy(dest.path);
                  if (context.mounted) {
                    setState(() {
                      selectedImage = dest.path;
                      imageError = null;
                    });
                  }
                }
              } catch (e) {
                debugPrint('Error picking image: $e');
              } finally {
                if (context.mounted) {
                  setState(() => isPickingImage = false);
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: Text(catToEdit == null ? 'Add New Cat' : 'Edit Cat'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: pickImage,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: imageError != null
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                              backgroundImage: selectedImage != null
                                  ? FileImage(File(selectedImage!))
                                  : null,
                              child: selectedImage == null
                                  ? Icon(Icons.camera_alt,
                                      size: 32,
                                      color: imageError != null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer)
                                  : null,
                            ),
                            if (imageError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  imageError!,
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
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.pets),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: breedController,
                        decoration: InputDecoration(
                          labelText: 'Breed',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a breed'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ageController,
                              decoration: InputDecoration(
                                labelText: 'Age',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: gender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Male', child: Text('Male')),
                                DropdownMenuItem(
                                    value: 'Female', child: Text('Female')),
                              ],
                              onChanged: (value) =>
                                  setState(() => gender = value!),
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
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    if (selectedImage == null) {
                      setState(() => imageError = 'Image required');
                      return;
                    }

                    setState(() => isSaving = true);

                    final user = User.currentUser;
                    if (user == null) {
                       // Should not happen if UI is correct, but safety check
                       setState(() => isSaving = false);
                       return;
                    }

                    final age = int.parse(ageController.text);
                    final cat = Cat(
                      catId: catToEdit?.catId,
                      name: nameController.text,
                      breed: breedController.text,
                      gender: gender,
                      age: age,
                      imgPath: selectedImage,
                    );
                    
                    final catData = cat.toJson();
                    // Add userId to the payload so the server knows who owns this cat
                    catData['userId'] = user.userId;

                    try {
                      http.Response response;
                      // Use PUT for update, POST for create
                      if (cat.catId != null) {
                        response = await http.put(
                          Uri.parse(serverUrl('/cats/${cat.catId}')),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(catData),
                        );
                      } else {
                        response = await http.post(
                          Uri.parse(serverUrl('/cats')),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(catData),
                        );
                      }

                      if (response.statusCode != 200 && response.statusCode != 201) {
                        throw Exception('Failed to save cat: ${response.body}');
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        // Reload cats from server to get the new/updated one
                        await _loadCats();
                      }
                    } catch (e) {
                      debugPrint("[CatsTab] Error saving cat: $e");
                      if (context.mounted) {
                        setState(() => isSaving = false);
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCat(Cat cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cat'),
        content: Text('Are you sure you want to delete ${cat.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(Uri.parse(serverUrl('/cats/${cat.catId}')));
        if (response.statusCode != 200) {
          throw Exception('Failed to delete cat: ${response.body}');
        }
        await _loadCats();
      } catch (e) {
        debugPrint('[CatsTab] Error deleting cat: $e');
      }
    }
  }

  Widget _buildCatCard(Cat cat) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CatDetailScreen(cat: cat)),
            );
          },
          onLongPress: () => _showCatDialog(catToEdit: cat),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              child: Icon(
                                Icons.pets,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                    .withOpacity(0.5),
                              ),
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
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showCatDialog(catToEdit: cat);
                          } else if (value == 'delete') {
                            _deleteCat(cat);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Icon(
                          cat.gender == 'Female' ? Icons.female : Icons.male,
                          color: cat.gender == 'Female'
                              ? Colors.pinkAccent
                              : Colors.blueAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cat.breed} • ${cat.age} years old',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.8),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Cats'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())          
          : _cats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      Icon(Icons.pets,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.2)),
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 10),
                  itemCount: _cats.length,
                  itemBuilder: (context, index) {
                    return _buildCatCard(_cats[index]);
                  },
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton.extended(
          onPressed: () {            final isLoggedIn = User.isLoggedIn;
            if (!isLoggedIn) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to add a cat.')),
                );
              }
              return;
            }
            _showCatDialog();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Cat'),
        ),
      ),
    );
  }
}

class CatDetailScreen extends StatefulWidget {
  final Cat cat;

  const CatDetailScreen({super.key, required this.cat});

  @override
  State<CatDetailScreen> createState() => _CatDetailScreenState();
}

class _CatDetailScreenState extends State<CatDetailScreen> {
  List<Map<String, dynamic>> _history = [];
  Map<String, double> _labelCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.cat.catId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
   try {
      final response = await http.get(Uri.parse(serverUrl('/history/${widget.cat.catId}')));
      if (response.statusCode != 200) {
        throw Exception('Failed to load history: ${response.body}');
      }

      final List<dynamic> history = jsonDecode(response.body);
      final historyMaps = history.cast<Map<String, dynamic>>();

      if (mounted) {
        final counts = <String, double>{};
        for (var record in historyMaps) {
          final label = (record['textTranslation'] as String?) ?? 'Unknown';
          counts[label] = (counts[label] ?? 0) + 1;
        }
        setState(() {
          _history = historyMaps;
          _labelCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      } 
    
    
    }
  }

  List<PieChartSectionData> _buildPieChartSections() {
    if (_labelCounts.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '',
          radius: 80,
        )
      ];
    }
    final List<Color> colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
      Colors.purple.shade400,
      Colors.yellow.shade700,
      Colors.cyan.shade400,
      Colors.pink.shade300,
    ];
    int colorIndex = 0;
    return _labelCounts.entries.map((entry) {
      final color = colors[colorIndex++ % colors.length];
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${entry.key}\n(${entry.value.toInt()})',
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300.0,
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
                                size: 100, color: Colors.white54)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoChip(Icons.category, widget.cat.breed),
                            _buildInfoChip(
                                widget.cat.gender == 'Female'
                                    ? Icons.female
                                    : Icons.male,
                                widget.cat.gender),
                            _buildInfoChip(Icons.cake, '${widget.cat.age} years'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Translation Analytics',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        _labelCounts.isEmpty
                            ? const Center(
                                child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child:
                                    Text('No translation history to analyze.'),
                              ))
                            : SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _buildPieChartSections(),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Recent History',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                _history.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
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
                            final dtString = (record['translation_datetime'] ?? record['hist_time']) as String?;
                            String formattedDate = 'No date';
                            if (dtString != null) {
                              try {
                                final dt = DateTime.parse(dtString);
                                formattedDate =
                                    DateFormat.yMMMd().add_jm().format(dt);
                              } catch (e) {
                                // ignore
                              }
                            }
                            return ListTile(
                              leading: const Icon(Icons.volume_up),
                              title: Text(record['textTranslation']),
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
    );
  }
}
