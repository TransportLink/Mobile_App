import 'package:flutter/material.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/features/auth/view/pages/signup_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'How will you\nuse Smart Trotro?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to get started',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),
              // Driver card
              _RoleCard(
                icon: Icons.directions_car,
                title: "I'm a Driver",
                subtitle: 'Find passengers, manage trips, and earn money driving your trotro.',
                color: Colors.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SignupPage(role: UserRole.driver),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Passenger card
              _RoleCard(
                icon: Icons.hail_rounded,
                title: "I'm a Passenger",
                subtitle: 'Find nearby trotros, check in at bus stops, and track your ride.',
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SignupPage(role: UserRole.passenger),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final MaterialColor color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 32, color: color.shade700),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: color.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.shade400, size: 24),
          ],
        ),
      ),
    );
  }
}
