import 'package:flutter/material.dart';

class AdminRolesScreen extends StatelessWidget {
  const AdminRolesScreen({super.key});

  static const _deepMint = Color(0xFF17A2A2);
  static const _bg = Color(0xFFF6FFFA);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'ElderLinks',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: _deepMint,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Roles & Permissions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Control what each role can access.',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                title: 'Admin',
                subtitle: 'Full access (system owner)',
                color: _deepMint,
                icon: Icons.admin_panel_settings_rounded,
                permissions: const [
                  'View dashboard',
                  'Manage staff',
                  'Manage roles & permissions',
                  'View logs',
                  'Change system settings',
                  'Export reports',
                ],
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Nurse',
                subtitle: 'Clinical monitoring & alerts',
                color: Colors.teal,
                icon: Icons.medical_services_rounded,
                permissions: const [
                  'View dashboard',
                  'View elders',
                  'Manage medicines',
                  'View alerts',
                  'Mark alerts resolved',
                  'View care notes',
                ],
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Caretaker',
                subtitle: 'Daily support & tracking',
                color: Colors.green,
                icon: Icons.volunteer_activism_rounded,
                permissions: const [
                  'View elders',
                  'View schedules',
                  'Log basic activity',
                  'View assigned alerts',
                  'Add care notes',
                ],
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Supervisor',
                subtitle: 'Oversight & reporting',
                color: Colors.indigo,
                icon: Icons.supervisor_account_rounded,
                permissions: const [
                  'View dashboard',
                  'View staff activity',
                  'View logs',
                  'Approve changes',
                  'Generate reports',
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'People',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Individuals grouped by role (dummy data).',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 14),
              ..._people.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PersonCard(person: p),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Person {
  final String name;
  final String role;
  final bool isActive;
  final String lastActive;
  final List<String> assignedElders;
  final Color roleColor;
  final IconData roleIcon;

  const _Person({
    required this.name,
    required this.role,
    required this.isActive,
    required this.lastActive,
    required this.assignedElders,
    required this.roleColor,
    required this.roleIcon,
  });
}

class _PersonCard extends StatelessWidget {
  final _Person person;

  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final statusColor = person.isActive ? Colors.green : Colors.red;
    final statusBg = person.isActive ? Colors.green.withOpacity(0.10) : Colors.red.withOpacity(0.10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: person.roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(person.roleIcon, color: person.roleColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.role,
                      style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.62)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.22)),
                ),
                child: Text(
                  person.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: Colors.black.withOpacity(0.45)),
              const SizedBox(width: 6),
              Text(
                'Last active: ${person.lastActive}',
                style: TextStyle(fontSize: 12.5, color: Colors.black.withOpacity(0.65), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...person.assignedElders.map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: person.roleColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: person.roleColor.withOpacity(0.18)),
                  ),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<String> permissions;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.60)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: permissions
                .map(
                  (p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

const _people = <_Person>[
  _Person(
    name: 'Aisha Rahman',
    role: 'Admin',
    isActive: true,
    lastActive: 'Today, 9:12 AM',
    assignedElders: ['System', 'All Facilities'],
    roleColor: AdminRolesScreen._deepMint,
    roleIcon: Icons.admin_panel_settings_rounded,
  ),
  _Person(
    name: 'Daniel Okafor',
    role: 'Admin',
    isActive: true,
    lastActive: 'Yesterday, 6:48 PM',
    assignedElders: ['Reports', 'Audit'],
    roleColor: AdminRolesScreen._deepMint,
    roleIcon: Icons.admin_panel_settings_rounded,
  ),
  _Person(
    name: 'Meera Patel',
    role: 'Nurse',
    isActive: true,
    lastActive: 'Today, 10:05 AM',
    assignedElders: ['Elder: Fatima A.', 'Elder: Joseph K.'],
    roleColor: Colors.teal,
    roleIcon: Icons.medical_services_rounded,
  ),
  _Person(
    name: 'Lucas Nguyen',
    role: 'Nurse',
    isActive: false,
    lastActive: '3 days ago',
    assignedElders: ['Elder: Maria S.'],
    roleColor: Colors.teal,
    roleIcon: Icons.medical_services_rounded,
  ),
  _Person(
    name: 'Grace Mensah',
    role: 'Caretaker',
    isActive: true,
    lastActive: 'Today, 8:41 AM',
    assignedElders: ['Elder: Ahmed R.', 'Elder: Lila N.', 'Elder: Sofia T.'],
    roleColor: Colors.green,
    roleIcon: Icons.volunteer_activism_rounded,
  ),
  _Person(
    name: 'Hassan Ali',
    role: 'Caretaker',
    isActive: true,
    lastActive: 'Today, 7:55 AM',
    assignedElders: ['Elder: Peter M.', 'Elder: Sunita P.'],
    roleColor: Colors.green,
    roleIcon: Icons.volunteer_activism_rounded,
  ),
  _Person(
    name: 'Chloe Martin',
    role: 'Supervisor',
    isActive: true,
    lastActive: 'Today, 9:35 AM',
    assignedElders: ['Wing A', 'Wing B'],
    roleColor: Colors.indigo,
    roleIcon: Icons.supervisor_account_rounded,
  ),
  _Person(
    name: 'Omar Hassan',
    role: 'Supervisor',
    isActive: false,
    lastActive: '1 week ago',
    assignedElders: ['Night Shift'],
    roleColor: Colors.indigo,
    roleIcon: Icons.supervisor_account_rounded,
  ),
];
