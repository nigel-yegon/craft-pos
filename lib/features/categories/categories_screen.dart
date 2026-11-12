import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/category_provider.dart';
import 'category_form_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final CategoryProvider provider;
  const CategoriesScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: StreamBuilder<List<Category>>(
        stream: provider.categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                title: Text(cat.name),
                subtitle: cat.description != null ? Text(cat.description!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => provider.deleteCategory(cat.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryFormScreen(provider: provider),
          ),
        ),
      ),
    );
  }
}