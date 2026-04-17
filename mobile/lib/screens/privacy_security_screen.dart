import 'package:flutter/material.dart';

/// Informational screen about data security and privacy (no settings controls).
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  static const Color _deepMint = Color(0xFF17A2A2);

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.55,
      color: Colors.black.withOpacity(0.78),
    );
    const headingStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How we protect your data',
              style: headingStyle.copyWith(
                fontSize: 20,
                color: _deepMint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ElderLink is built for care teams. Health readings, medicine schedules, '
              'and resident information are handled with security in mind. Access to the '
              'staff panel is tied to your signed-in account so only authorized caregivers '
              'can view or manage data for your organization.',
              style: bodyStyle,
            ),
            const SizedBox(height: 24),
            const Text('Data security', style: headingStyle),
            const SizedBox(height: 10),
            Text(
              'Information moves between the mobile app and your configured backend over '
              'encrypted connections where your device and server support it. You should '
              'use strong passwords, keep your device updated, and avoid sharing your '
              'login with anyone who is not part of your care team. If you lose a device, '
              'change your password and contact your administrator promptly.',
              style: bodyStyle,
            ),
            const SizedBox(height: 24),
            const Text('Privacy', style: headingStyle),
            const SizedBox(height: 10),
            Text(
              'Vitals and alerts help staff respond quickly to residents’ needs. Data is '
              'used to operate the service—showing dashboards, reminders, and '
              'notifications—not for unrelated advertising. Any optional research or '
              'analytics features, if enabled by your deployment, use minimized or '
              'anonymized information as described in your organization’s policies.',
              style: bodyStyle,
            ),
            const SizedBox(height: 24),
            const Text('Your responsibilities', style: headingStyle),
            const SizedBox(height: 10),
            Text(
              'Treat resident information as confidential. Only use ElderLink for legitimate '
              'care purposes. Do not export or share sensitive data outside approved channels. '
              'If you notice suspicious activity or a possible breach, report it to your '
              'supervisor or IT contact immediately.',
              style: bodyStyle,
            ),
            const SizedBox(height: 24),
            Text(
              'This summary does not replace your employer’s privacy policy, employment '
              'agreements, or local regulations. For legal or compliance questions, '
              'consult your organization’s data protection officer or legal counsel.',
              style: bodyStyle.copyWith(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
