import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:meow_lang/models/user.dart';
import 'package:http/http.dart' as http;
import 'package:meow_lang/server_config.dart';

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
      final response = await http
          .post(
            Uri.parse(serverUrl('/login')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['user'] != null && data['user'] is Map<String, dynamic>) {
          final userToSet = User.fromJson(data['user']);
          User.login(userToSet);
          widget.onLoggedIn();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Login failed: invalid server response')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${data['message']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error connecting to server: $e')));
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
      final response = await http
          .post(
            Uri.parse(serverUrl('/register')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Registration successful, now try to log in to get user data
        try {
          final loginResp = await http
              .post(
                Uri.parse(serverUrl('/login')),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'email': email, 'password': password}),
              )
              .timeout(const Duration(seconds: 10));

          if (!mounted) return;

          if (loginResp.statusCode == 200) {
            final loginData = jsonDecode(loginResp.body);
            if (loginData['user'] != null &&
                loginData['user'] is Map<String, dynamic>) {
              final createdUser = User.fromJson(loginData['user']);
              User.login(createdUser);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Registration successful — logged in.')));
              widget.onRegistered();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Registration successful! Please log in.')));
              widget.onSwitchToLogin();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Registration successful! Please log in.')));
            widget.onSwitchToLogin();
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Registration successful! Please log in.')));
          widget.onSwitchToLogin();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${data['message']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error connecting to server: $e')));
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade200,
              child: Icon(Icons.person,
                  size: 48, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 12),
            Text(
              user.name!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        context, Icons.person_outline, 'Name', user.name!),
                    const Divider(height: 24),
                    _buildDetailRow(
                        context, Icons.email_outlined, 'Email', user.email!),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Log out',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          ],
        )
      ],
    );
  }
}
