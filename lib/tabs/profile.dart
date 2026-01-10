import 'package:flutter/material.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/user.dart';
import 'package:meow_lang/DB/database_helper.dart';

class ProfileMenu extends StatefulWidget {
  const ProfileMenu({super.key});

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  User? user;
  List<Cat> cats = [];
  bool _isLoading = true;
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = await DatabaseHelper.instance.getUser();
    final currentCats = await DatabaseHelper.instance.getCats();
    if (mounted) {
      setState(() {
        user = currentUser;
        cats = currentCats;
        _isLoading = false;
      });
    }
  }
  
  void _showCatDialog({Cat? catToEdit}) {
    final nameController = TextEditingController(text: catToEdit?.name ?? '');
    final breedController = TextEditingController(text: catToEdit?.breed ?? '');
    final ageController = TextEditingController(text: catToEdit?.age?.toString() ?? '');
    String gender = catToEdit?.gender ?? 'Male';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(catToEdit == null ? 'Add Cat' : 'Edit Cat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: breedController,
                      decoration: const InputDecoration(labelText: 'Breed'),
                    ),
                    TextField(
                      controller: ageController,
                      decoration: const InputDecoration(labelText: 'Age'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButton<String>(
                      value: gender,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (value) => setState(() => gender = value!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final age = int.tryParse(ageController.text);
                    if (nameController.text.isEmpty ||
                        breedController.text.isEmpty ||
                        age == null) {
                      return;
                    }
                    final cat = Cat(
                      catId: catToEdit?.catId,
                      name: nameController.text,
                      breed: breedController.text,
                      gender: gender,
                      age: age,
                    );
                    
                    if (catToEdit == null) {
                      await DatabaseHelper.instance.insertCat(cat);
                    } else {
                      await DatabaseHelper.instance.updateCat(cat);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  },
                  child: const Text('Save'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteCat(cat.catId!);
      _loadData();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This will also delete all registered cats. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && user != null) {
      for (var cat in cats) {
        if (cat.catId != null) {
          await DatabaseHelper.instance.deleteCat(cat.catId!);
        }
      }
      await DatabaseHelper.instance.deleteUser(user!.userId!);
      _loadData();
    }
  }

  Widget _buildRegistrationForm() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Create Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _regNameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _regEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _regPasswordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (_regNameController.text.isNotEmpty &&
                      _regEmailController.text.isNotEmpty &&
                      _regPasswordController.text.isNotEmpty) {
                    await DatabaseHelper.instance.registerUser(
                      _regNameController.text,
                      _regEmailController.text,
                      _regPasswordController.text,
                    );
                    _loadData();
                  }
                },
                child: const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (user == null) {
      return _buildRegistrationForm();
    }
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width * 0.8,
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    SizedBox(height:50),
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade100,
                      child: Icon(Icons.person, size: 48,color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user!.name!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user!.email!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),

              Card(
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(user!.name!,style: Theme.of(context).textTheme.bodyMedium),
                        subtitle:Text('Name',style: Theme.of(context).textTheme.titleSmall),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: Text(user!.email!,style: Theme.of(context).textTheme.bodyMedium),
                        subtitle: Text('Email',style: Theme.of(context).textTheme.titleSmall),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteAccount,
                          icon: const Icon(Icons.person_off, color: Colors.red),
                          label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registered Cats',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: () => _showCatDialog(),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                itemCount: cats.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final cat = cats[idx];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Icon(
                          Icons.pets,
                          color: Colors.grey.shade100,
                        ),
                      ),
                      title: Text(cat.name),
                      subtitle: Text('${cat.breed}, Age: ${cat.age}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showCatDialog(catToEdit: cat);
                          } else if (value == 'delete') {
                            _deleteCat(cat);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
