import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF2D5478),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}