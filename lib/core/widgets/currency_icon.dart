import 'package:flutter/material.dart';

class CurrencyIcon extends StatelessWidget {
  final double size;
  final Color color;
  final FontWeight weight;

  const CurrencyIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.weight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.4,
      height: size * 1.4,
      child: Center(
        child: Text(
          'KES',
          style: TextStyle(
            color: color,
            fontSize: size * 0.6,
            fontWeight: weight,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
