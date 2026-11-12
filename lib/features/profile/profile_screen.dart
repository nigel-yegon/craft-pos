import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/business_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final BusinessProvider provider;
  const ProfileScreen({super.key, required this.provider});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _populateFields(BusinessesData biz) {
    if (_initialized) return;
    _nameController.text = biz.name;
    _phoneController.text = biz.phone ?? '';
    _emailController.text = biz.email ?? '';
    _addressController.text = biz.address ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    await widget.provider.updateBusiness(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      address: _addressController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shop profile updated!'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: 'Save',
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: StreamBuilder<BusinessesData?>(
        stream: widget.provider.businessStream,
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
          final hasImage =
              imagePath != null && File(imagePath).existsSync();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen
                                .withValues(alpha: 0.1),
                            border: Border.all(
                              color: AppTheme.primaryGreen
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                            image: hasImage
                                ? DecorationImage(
                              image: FileImage(File(imagePath)),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: !hasImage
                              ? const Icon(
                            Icons.storefront,
                            size: 60,
                            color: AppTheme.primaryGreen,
                          )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isSaving
                                ? null
                                : () async {
                              await widget.provider
                                  .pickAndSaveImage();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Tap the camera icon to change your shop photo',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textLight),
                  ),

                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Shop Name *',
                      prefixIcon: Icon(Icons.store),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 2) {
                        return 'Enter at least 2 characters';
                      }
                      return null;
                    },
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
                      final valid = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
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
                      labelText: 'Address / Location',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.save),
                      label: Text(
                          _isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'These details are stored locally on your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textLight),
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