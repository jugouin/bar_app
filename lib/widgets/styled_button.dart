import 'package:flutter/material.dart';

class StyledButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const StyledButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 150, 201, 222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2D5478),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2D5478),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}