import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/providers/business_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';

class AobScreen extends ConsumerStatefulWidget {
  final BusinessProvider businessProvider;
  final AuthProvider authProvider;

  const AobScreen({
    super.key,
    required this.businessProvider,
    required this.authProvider,
  });

  @override
  ConsumerState<AobScreen> createState() => _AobScreenState();
}

class _AobScreenState extends ConsumerState<AobScreen> {
  final _formKey = GlobalKey<FormState>();

  // Business Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  // User Controllers
  late TextEditingController _userNameController;

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _userNameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  void _populateFields(BusinessesData biz) {
    if (_initialized) return;
    _nameController.text = biz.name;
    _phoneController.text = biz.phone ?? '';
    _emailController.text = biz.email ?? '';
    _addressController.text = biz.address ?? '';
    _userNameController.text = widget.authProvider.currentUser?.name ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 1. Update Business Details
      await widget.businessProvider.updateBusiness(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
      );

      // 2. Update User Details (Owner Name)
      final db = ref.read(databaseProvider);
      final user = widget.authProvider.currentUser;
      if (user != null && _userNameController.text.trim() != user.name) {
        await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
          UsersCompanion(
            name: drift.Value(_userNameController.text.trim()),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details updated successfully!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Business & User Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check, color: AppTheme.inkBlack),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: StreamBuilder<BusinessesData?>(
        stream: widget.businessProvider.businessStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final biz = snapshot.data;
          if (biz == null) {
            return const Center(child: Text('No business found.'));
          }

          _populateFields(biz);

          final imagePath = biz.imagePath;
          final hasImage = imagePath != null && File(imagePath).existsSync();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ BUSINESS LOGO ═══
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.softMint,
                            border: Border.all(
                              color: AppTheme.heroGreen.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            image: hasImage
                                ? DecorationImage(
                              image: FileImage(File(imagePath)),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: !hasImage
                              ? const Icon(Icons.storefront,
                              size: 40, color: AppTheme.heroGreen)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isSaving
                                ? null
                                : () async {
                              await widget.businessProvider.pickAndSaveImage();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.brightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: AppTheme.inkBlack,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ═══ SECTION: BUSINESS DETAILS ═══
                  const Text(
                    'Business Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkBlack,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Business Name',
                      prefixIcon: Icon(Icons.store),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return null;
                      final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email);
                      return valid ? null : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.words,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Physical Address',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),

                  // ═══ SECTION: OWNER DETAILS ═══
                  const Text(
                    'Owner Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkBlack,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _userNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 40),

                  // ═══ SAVE BUTTON ═══
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}