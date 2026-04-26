import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import '../models/user.dart';
import '../snackbar_helper.dart';
import '../models/cat.dart';

class ProfileMenu extends StatefulWidget {
  const ProfileMenu({super.key});

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  bool _showLoginForm = true; // false for register, true for login

  void _onAuthSuccess() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // A better approach for this would be to use a proper state management solution
    // like Provider or Riverpod to listen to authentication state changes.
    // For this refactoring, we'll use callbacks and setState.
    if (!User.isLoggedIn) {
      return _showLoginForm
          ? _LoginWidget(
              onLoggedIn: _onAuthSuccess,
              onSwitchToRegister: () => setState(() => _showLoginForm = false),
            )
          : _RegisterWidget(
              onRegistered: _onAuthSuccess,
              onSwitchToLogin: () => setState(() => _showLoginForm = true),
            );
    }

    return _UserProfileView(onLogout: _onAuthSuccess);
  }
}

class _LoginWidget extends StatefulWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback onSwitchToRegister;

  const _LoginWidget({
    required this.onLoggedIn,
    required this.onSwitchToRegister,
  });

  @override
  State<_LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<_LoginWidget> {
  final FirebaseService _firebase = FirebaseService();
  bool _isProcessing = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      final userCred = await _firebase.login(email, password);
      if (userCred != null) {
        User.login(User(
          userId: userCred['uid'],
          name: userCred['name'] ?? userCred['email'],
          email: userCred['email'],
          regDate: null,
        ));
        widget.onLoggedIn();
      } else {
        SnackBarHelper.showError(context, 'Login failed: unknown user or invalid credentials');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error connecting to auth: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Log in',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _login,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log in'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: widget.onSwitchToRegister,
                    child: const Text("Register"),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterWidget extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback onSwitchToLogin;

  const _RegisterWidget({
    required this.onRegistered,
    required this.onSwitchToLogin,
  });

  @override
  State<_RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<_RegisterWidget> {
  final FirebaseService _firebase = FirebaseService();
  bool _isProcessing = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isProcessing = true);
    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      final authUser = await _firebase.register(name, email, password);
      if (authUser != null) {
        User.login(User(
          userId: authUser['uid'],
          name: name,
          email: email,
          regDate: DateTime.now().toIso8601String(),
        ));
        SnackBarHelper.showSuccess(context, 'Registration successful — logged in.');
        widget.onRegistered();
      } else {
        SnackBarHelper.showError(context, 'Registration failed: unknown error');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error connecting to server: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _register,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Register'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: widget.onSwitchToLogin,
                    child: const Text("Log in"),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfileView extends StatefulWidget {
  final VoidCallback onLogout;

  const _UserProfileView({required this.onLogout});

  @override
  State<_UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<_UserProfileView> {
  @override
  void initState() {
    super.initState();
    User.currentUser?.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    User.currentUser?.removeListener(_onUserChanged);
    super.dispose();
  }

  final FirebaseService _firebaseService = FirebaseService();

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Log out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    User.logout();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    // User is guaranteed to be non-null here because this widget is only shown when logged in.
    final user = User.currentUser!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person,
                      size: 60, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                StreamBuilder<int>(
                  stream: _firebaseService.streamUserTranslationCount(user.userId!),
                  builder: (context, translationSnapshot) {
                    final translations = translationSnapshot.data ?? 0;
                    return StreamBuilder<int>(
                      stream: _firebaseService.streamUserCorrectionCount(user.userId!),
                      builder: (context, correctionSnapshot) {
                        final corrections = correctionSnapshot.data ?? 0;
                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Translations',
                                translationSnapshot.connectionState == ConnectionState.waiting
                                    ? '...'
                                    : translations.toString(),
                                Icons.translate,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Corrections',
                                correctionSnapshot.connectionState == ConnectionState.waiting
                                    ? '...'
                                    : corrections.toString(),
                                Icons.feedback_outlined,
                                Colors.orange,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Registered Cats',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Cat>>(
                  stream: _firebaseService.streamCats(user.userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error loading cats: ${snapshot.error}',
                            style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      );
                    }

                    final cats = snapshot.data ?? [];
                    if (cats.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.pets, color: Colors.grey.shade400, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'No cats registered yet.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildCatListItem(cats[index]),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatListItem(Cat cat) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              cat.imgPath != null ? FileImage(File(cat.imgPath!)) : null,
          child: cat.imgPath == null
              ? const Icon(Icons.pets, size: 22, color: Colors.grey)
              : null,
        ),
        title: Text(
          cat.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${cat.age} years old",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
