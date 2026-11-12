import 'dart:io';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String? imagePath;
  final double size;
  final double borderRadius;

  const ProductImage({
    super.key,
    required this.imagePath,
    this.size = 60,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final file = imagePath != null ? File(imagePath!) : null;
    final exists = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade100,
        child: exists
            ? Image.file(
          file,
          fit: BoxFit.cover,
          width: size,
          height: size,
        )
            : Icon(
          Icons.inventory_2,
          size: size * 0.45,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}