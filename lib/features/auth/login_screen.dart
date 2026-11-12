import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final AuthProvider authProvider;
  const LoginScreen({super.key, required this.authProvider});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  String? _selectedUserName;
  List<String> _userNames = [];
  bool _isLoading = true;
  bool _hasUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final hasUsers = await widget.authProvider.hasUsers();
    if (hasUsers) {
      final users = await widget.authProvider.db.select(widget.authProvider.db.users).get();
      setState(() {
        _userNames = users.map((u) => u.name).toList();
        _selectedUserName = _userNames.first;
      });
    }
    setState(() {
      _hasUsers = hasUsers;
      _isLoading = false;
    });
  }

  Future<void> _login() async {
    if (_selectedUserName == null || _pinController.text.isEmpty) return;

    final success = await widget.authProvider.login(_selectedUserName!, _pinController.text);

    if (success && mounted) {
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PIN'), backgroundColor: AppTheme.warningRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no users exist, we show the "Create Owner Account" form
    if (!_hasUsers) {
      return _buildFirstTimeSetup();
    }

    // Normal Login
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 60, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Enter your PIN to continue', style: TextStyle(color: AppTheme.textLight)),
              const SizedBox(height: 32),

              DropdownButtonFormField<String>(
                value: _selectedUserName,
                decoration: const InputDecoration(labelText: 'Select User'),
                items: _userNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (val) => setState(() => _selectedUserName = val),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirstTimeSetup() {
    final nameController = TextEditingController();
    final pinController = TextEditingController();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.storefront, size: 80, color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              const Text('Setup Your Shop', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Create your owner account', style: TextStyle(color: AppTheme.textLight)),
              const SizedBox(height: 32),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Create a PIN (4-6 digits)', counterText: ''),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = await widget.authProvider.createUser(
                      name: nameController.text,
                      pin: pinController.text,
                    );
                    if (user != null && mounted) {
                      context.go('/dashboard');
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN must be at least 4 digits')),
                      );
                    }
                  },
                  child: const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}