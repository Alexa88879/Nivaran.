// lib/screens/profile/account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/app_user_model.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Dismiss dialog, return false
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Dismiss dialog, return true
              },
            ),
          ],
        );
      },
    );

    // Proceed only if logout was confirmed
    if (confirmLogout == true) {
      late final AuthService authService;
      if (context.mounted) {
        authService = Provider.of<AuthService>(context, listen: false);
      }
      late final UserProfileService userProfileService;
      if (context.mounted) {
        userProfileService = Provider.of<UserProfileService>(context, listen: false);
      }

      // 1. Clear local user profile data FIRST.
      // Ensure UserProfileService has this method defined.
      userProfileService.clearUserProfile(); // <<< CORRECTED METHOD NAME

      // 2. Sign out from the authentication service.
      if (context.mounted) {
        await authService.signOut(context);
      }

      // 3. Explicit navigation
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context);
    final AppUser? currentUserProfile = userProfileService.currentUserProfile;

    if (userProfileService.isLoadingProfile && currentUserProfile == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: const Center(child: CircularProgressIndicator(semanticsLabel: "Loading profile...",)));
    }

    if (currentUserProfile == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('User profile not available.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
                  },
                  child: const Text('Go to Login/Signup'),
                )
              ],
            ),
          ));
    }

    final String displayName = currentUserProfile.username ?? currentUserProfile.fullName ?? currentUserProfile.email?.split('@')[0] ?? 'User';
    final String? profileImageUrl = currentUserProfile.profilePhotoUrl;
    final bool isOfficial = currentUserProfile.isOfficial;
    final String? officialDepartment = currentUserProfile.department;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl.isEmpty) && displayName.isNotEmpty
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(fontSize: 28, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (currentUserProfile.email != null && currentUserProfile.email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            currentUserProfile.email!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                        ),
                      if (isOfficial && officialDepartment != null && officialDepartment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Official: $officialDepartment",
                          style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColorDark, fontWeight: FontWeight.w500),
                        ),
                      ] else if (currentUserProfile.isPendingOfficial) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Official Account (Pending Verification)",
                          style: TextStyle(fontSize: 14, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (isOfficial) ...[
            _buildSectionTitle(context, "Official Tools"),
            _buildListTile(
              context: context,
              icon: Icons.dashboard_customize_outlined,
              title: 'Department Dashboard',
              onTap: () {
                Navigator.pushNamed(context, '/official_dashboard');
              }
            ),
            const Divider(height:1, indent: 16, endIndent: 16),
            const SizedBox(height: 10),
          ],

          _buildSectionTitle(context, "My Activity"),
          _buildListTile(
            context: context,
            icon: Icons.list_alt_outlined,
            title: 'My Reported Issues',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("My Issues - Coming Soon!")));
            }
          ),

          const SizedBox(height: 10),
          _buildSectionTitle(context, "Support & Settings"),
          _buildListTile(
            context: context,
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications - Coming Soon!")));
            }
          ),
          _buildListTile(
            context: context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Help & Support - Coming Soon!")));
            }
          ),
          _buildListTile(
            context: context,
            icon: Icons.settings_outlined,
            title: 'App Settings',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("App Settings - Coming Soon!")));
            }
          ),

          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _logout(context),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
        onTap: onTap,
      ),
    );
  }
}