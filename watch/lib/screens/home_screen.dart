import 'package:flutter/material.dart';
import 'dart:math' as math;

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  final Function(int)? onNavigateToScreen;
  
  const HomeScreen({super.key, this.onSettingsTap, this.onNavigateToScreen});

  static const Color _centerMint = Color(0xFF6BB86B); // Deeper mint than #90EE90

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF), // White background (outer circle)
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center circle: deeper mint with subtle inner shadow effect
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _centerMint,
                    ),
                  ),
                  // Subtle inner shadow (darker at edges)
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.06),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "Elder Mode" label above center icon
          Positioned(
            left: 0,
            right: 0,
            top: 118,
            child: Center(
              child: Text(
                'Elder Mode',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          // App Symbol (top) - angle: -π/2 (-90°) - Teal #17A2A2
          _buildCircularIconWithImage(
            context,
            imagePath: 'symbol.jpeg',
            color: const Color(0xFF17A2A2),
            angle: -math.pi / 2,
            onTap: () {}, // No functionality, just display
          ),
          // Medicine (top-right) - angle: -π/6 (-30°) - Blue #007BFF
          _buildCircularIcon(
            context,
            icon: Icons.medication,
            color: const Color(0xFF007BFF),
            angle: -math.pi / 6,
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(2) : () {},
          ),
          // Clock (right-lower) - angle: π/6 (30°) - Orange #FF8C00
          _buildCircularIcon(
            context,
            icon: Icons.access_time,
            color: const Color(0xFFFF8C00),
            angle: math.pi / 6,
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(3) : () {},
          ),
          // My Info (bottom) - angle: π/2 (90°) - Grey #6C757D
          _buildCircularIcon(
            context,
            icon: Icons.person,
            color: const Color(0xFF6C757D),
            angle: math.pi / 2,
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(4) : () {},
          ),
          // Fun / Staff (bottom-left) - angle: 5π/6 (150°) - Purple #6F42C1
          _buildCircularIcon(
            context,
            icon: Icons.settings,
            color: const Color(0xFF6F42C1),
            angle: 5 * math.pi / 6,
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(8) : () {},
          ),
          // Health (top-left) - angle: -5π/6 (-150°) - Green #28A745
          _buildCircularIcon(
            context,
            icon: Icons.favorite,
            color: const Color(0xFF28A745),
            angle: -5 * math.pi / 6,
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(6) : () {},
          ),
          // Panic (center) - Red #DC3545
          _buildCenterIcon(
            context,
            icon: Icons.warning,
            color: const Color(0xFFDC3545),
            onTap: onNavigateToScreen != null ? () => onNavigateToScreen!(7) : () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required double angle,
    required VoidCallback onTap,
  }) {
    // Fixed center point
    const double centerX = 180.0;
    const double centerY = 180.0;
    const double radius = 110.0; // Distance from center
    
    // Calculate position using trigonometry
    final double x = centerX + radius * math.cos(angle);
    final double y = centerY + radius * math.sin(angle);
    
    // Subtract half button size (35px) for positioning
    return Positioned(
      left: x - 35,
      top: y - 35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(35),
          splashColor: color.withOpacity(0.3),
          highlightColor: color.withOpacity(0.2),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2), // 20% opacity background
              border: Border.all(color: color, width: 2), // 2px solid border
              shape: BoxShape.circle, // Fully circular
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 36, // 36px × 36px icon
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIconWithImage(
    BuildContext context, {
    required String imagePath,
    required Color color,
    required double angle,
    required VoidCallback onTap,
  }) {
    // Fixed center point
    const double centerX = 180.0;
    const double centerY = 180.0;
    const double radius = 110.0; // Distance from center
    
    // Calculate position using trigonometry
    final double x = centerX + radius * math.cos(angle);
    final double y = centerY + radius * math.sin(angle);
    
    // Subtract half button size (35px) for positioning
    return Positioned(
      left: x - 35,
      top: y - 35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(35),
          splashColor: color.withOpacity(0.3),
          highlightColor: color.withOpacity(0.2),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2), // 20% opacity background
              border: Border.all(color: color, width: 2), // 2px solid border
              shape: BoxShape.circle, // Fully circular
            ),
            child: Center(
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Center button positioned at (180, 180) - center of watch
    return Positioned(
      left: 180 - 35, // Center minus half button width
      top: 180 - 35,  // Center minus half button height
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(35),
          splashColor: color.withOpacity(0.3),
          highlightColor: color.withOpacity(0.2),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2), // 20% opacity background
              border: Border.all(color: color, width: 2), // 2px solid border
              shape: BoxShape.circle, // Fully circular
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 36, // 36px × 36px icon
              ),
            ),
          ),
        ),
      ),
    );
  }
}
