import 'package:flutter/material.dart';

/// Onay tik widget'i
/// [type]: 'admin' -> altin degradeli tik, 'verified' -> mavi tik
class VerifiedBadge extends StatelessWidget {
  final String type;
  final double size;

  const VerifiedBadge({super.key, required this.type, this.size = 16});

  @override
  Widget build(BuildContext context) {
    if (type == 'admin') {
      return _buildGoldBadge();
    } else if (type == 'verified') {
      return _buildBlueBadge();
    }
    return const SizedBox.shrink();
  }

  Widget _buildGoldBadge() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFFD700),
          Color(0xFFFFA500),
          Color(0xFFFFD700),
          Color(0xFFDAA520),
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(Icons.verified, size: size, color: Colors.white),
    );
  }

  Widget _buildBlueBadge() {
    return Icon(Icons.verified, size: size, color: const Color(0xFF1DA1F2));
  }

  static bool hasBlueBadge(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    return userData['isVerified'] == true ||
        userData['isPremium'] == true ||
        userData['premiumStatus'] == 'active';
  }

  static bool hasAnyBadge(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    return userData['role'] == 'admin' || hasBlueBadge(userData);
  }

  /// Kullanici verisinden tik widget'i dondurur.
  /// role == 'admin' -> altin tik
  /// isVerified / isPremium / premiumStatus == 'active' -> mavi tik
  static Widget? fromUserData(
    Map<String, dynamic>? userData, {
    double size = 16,
  }) {
    if (userData == null) return null;
    if (userData['role'] == 'admin') {
      return VerifiedBadge(type: 'admin', size: size);
    }
    if (hasBlueBadge(userData)) {
      return VerifiedBadge(type: 'verified', size: size);
    }
    return null;
  }
}
