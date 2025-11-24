import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  final double size;

  const Logo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.7,
      height: size * 0.7,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      padding: EdgeInsets.all(size * 0.015),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF001276),
        ),
        padding: EdgeInsets.all(size * 0.015),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(size * 0.02),
            child: Image.asset(
              'assets/images/vcroad.webp',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_not_supported,
                size: size * 0.6,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
