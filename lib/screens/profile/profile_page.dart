import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/screens/Booking/my_booking_page.dart'
    hide kLightBackgroundColor, kMutedTextColor;
import 'package:service_app/screens/service/provider_services_screen.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/services/auth_service.dart';
import 'package:service_app/services/firestore_service.dart';
import 'package:service_app/screens/auth/login/login_screen.dart'
    hide AuthService;
import 'package:service_app/screens/profile/profile_constants.dart'
    hide kDarkTextColor, kPrimaryBlue;
import 'package:service_app/screens/profile/settings/settings_page.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/utils/image_utils.dart';

class ProfilePage extends StatefulWidget {
  final UserModel user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSwitchingRole = false;
  late FirestoreService _firestoreService;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await _firestoreService.getUserStats(widget.user.uid);
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
      // Fallback to user model data
      if (mounted) {
        setState(() {
          _userStats = {
            'address': widget.user.address,
            'totalJobs': widget.user.totalJobs,
            'rating': widget.user.rating,
            'completedJobs': 0,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        // Use the latest user from AuthViewModel or fallback to initial user
        final UserModel currentUser = authViewModel.currentUser ?? widget.user;
        final bool isProvider = currentUser.isProvider;

        return Scaffold(
          backgroundColor: Colors.white, // Changed to white
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Simple App Bar (back button removed)
                    _buildAppBar(context),

                    // Profile Header
                    _buildProfileHeader(currentUser),

                    // User Info Section
                    _buildUserInfoSection(currentUser),

                    // Statistics Row
                    _buildStatisticsRow(currentUser),

                    // Settings Section
                    _buildSettingsSection(context),

                    // Role Switch Button
                    _buildRoleSwitchSection(
                        context, currentUser, authViewModel),

                    // My Services Tile (only for providers)
                    if (isProvider) _buildMyServicesTile(context),

                    // My Bookings Tile (only for providers) - ADDED SECTION
                    if (isProvider) _buildMyBookingsTile(context),

                    const SizedBox(height: 20),

                    // Dynamic Info Card
                    _buildRoleOrAddressCard(currentUser, isProvider),

                    const SizedBox(height: 15),

                    // Logout Button
                    _buildLogoutButton(context),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Loading overlay
              if (_isSwitchingRole)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(
                          255, 12, 94, 153), // Changed to ChatScreen blue
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =================== ADDED METHOD: My Bookings Tile ===================
  Widget _buildMyBookingsTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Changed to white
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Changed shadow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyBookingsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 12, 94, 153)
                          .withOpacity(0.1), // Changed to ChatScreen blue
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.calendar_today,
                      color: const Color.fromARGB(
                          255, 12, 94, 153), // Changed to ChatScreen blue
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "My Bookings",
                          style: TextStyle(
                            color: Colors.grey.shade800, // Changed to dark gray
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Exo2',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "View and manage all service requests",
                          style: TextStyle(
                            color:
                                Colors.grey.shade600, // Changed to medium gray
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.grey.shade500, // Changed to gray
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Removed back button - only empty space
          const SizedBox(width: 40), // Keep space for alignment
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black87, // Changed to black
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white, // Changed to white
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.settings_outlined,
                color: const Color.fromARGB(
                    255, 12, 94, 153), // Changed to ChatScreen blue
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white, // Changed to white
                backgroundImage: ImageUtils.getImageProvider(user.photoUrl),
                child: _buildImageLoadingFallback(user),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                      255, 12, 94, 153), // Changed to ChatScreen blue
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(
              color: Colors.black87, // Changed to black
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 4),
          // Use phone or profession as subtitle
          if (user.profession != null && user.profession!.isNotEmpty)
            Text(
              user.profession!,
              style: TextStyle(
                color: Colors.grey.shade600, // Changed to medium gray
                fontSize: 16,
              ),
            )
          else if (user.phone.isNotEmpty)
            Text(
              user.phone,
              style: TextStyle(
                color: Colors.grey.shade600, // Changed to medium gray
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 12, 94, 153)
                  .withOpacity(0.1), // Changed to ChatScreen blue
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                color: const Color.fromARGB(
                    255, 12, 94, 153), // Changed to ChatScreen blue
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Changed shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoItem(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildInfoItem(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phone,
          ),
          if (user.profession != null && user.profession!.isNotEmpty) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildInfoItem(
              icon: Icons.work_outline,
              label: 'Profession',
              value: user.profession!,
            ),
          ],
          if (user.wilaya != null || user.commune != null) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildInfoItem(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value:
                  '${user.commune ?? ''}${user.commune != null && user.wilaya != null ? ', ' : ''}${user.wilaya ?? ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color.fromARGB(
                255, 12, 94, 153), // Changed to ChatScreen blue
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600, // Changed to medium gray
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87, // Changed to black
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ));
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () async {
          final authService = AuthService();
          await authService.logout();

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          foregroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // KEEP ALL EXISTING METHODS BELOW - Only design changes above
  // ============================================================

  Widget _buildImageLoadingFallback(UserModel user) {
    return FutureBuilder<bool>(
      future: _checkImageValidity(user.photoUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color.fromARGB(
                  255, 12, 94, 153), // Changed to ChatScreen blue
            ),
          );
        }

        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return _buildFallbackAvatar(user);
        }

        return Container();
      },
    );
  }

  Future<bool> _checkImageValidity(String photoUrl) async {
    try {
      if (ImageUtils.isNetworkImage(photoUrl)) {
        final response = await http.head(Uri.parse(photoUrl));
        return response.statusCode == 200;
      } else if (ImageUtils.isBase64Image(photoUrl)) {
        final bytes = ImageUtils.decodeBase64Image(photoUrl);
        return bytes != null && bytes.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('❌ Image validation error: $e');
      return false;
    }
  }

  Widget _buildFallbackAvatar(UserModel user) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.white, // Changed to white
      child: user.name.isNotEmpty
          ? Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 36,
                color: const Color.fromARGB(
                    255, 12, 94, 153), // Changed to ChatScreen blue
                fontWeight: FontWeight.bold,
                fontFamily: 'Exo2',
              ),
            )
          : Icon(
              CupertinoIcons.person_fill,
              color: const Color.fromARGB(
                  255, 12, 94, 153), // Changed to ChatScreen blue
              size: 60,
            ),
    );
  }

  Widget _buildMyServicesTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Changed to white
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Changed shadow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyServicesPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 12, 94, 153)
                          .withOpacity(0.1), // Changed to ChatScreen blue
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.wrench_fill,
                      color: const Color.fromARGB(
                          255, 12, 94, 153), // Changed to ChatScreen blue
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "My Services",
                          style: TextStyle(
                            color: Colors.grey.shade800, // Changed to dark gray
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Exo2',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Manage your offered services and prices",
                          style: TextStyle(
                            color:
                                Colors.grey.shade600, // Changed to medium gray
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.grey.shade500, // Changed to gray
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSwitchSection(
      BuildContext context, UserModel user, AuthViewModel authViewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _buildRoleSwitchButton(context, user, authViewModel),
    );
  }

  Widget _buildRoleSwitchButton(
      BuildContext context, UserModel user, AuthViewModel authViewModel) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color.fromARGB(255, 12, 94, 153)
                .withOpacity(0.9), // Changed to ChatScreen blue
            const Color(0xFF4A6FDC)
                .withOpacity(0.9), // Gradient matches ChatScreen
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 12, 94, 153)
                .withOpacity(0.3), // Changed to ChatScreen blue
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isSwitchingRole
              ? null
              : () => _showRoleSwitchDialog(context, user, authViewModel),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    user.isProvider
                        ? CupertinoIcons.person_fill
                        : CupertinoIcons.briefcase_fill,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch to ${user.isProvider ? 'Client' : 'Provider'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to change your role',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_isSwitchingRole)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    CupertinoIcons.arrow_right_circle_fill,
                    color: Colors.white.withOpacity(0.9),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleSwitchDialog(
      BuildContext context, UserModel user, AuthViewModel authViewModel) {
    final String newRole = user.isProvider ? 'client' : 'provider';
    final String currentRole = user.role.toUpperCase();
    final String targetRole = newRole.toUpperCase();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white, // Changed to white
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 12, 94, 153)
                        .withOpacity(0.1), // Changed to ChatScreen blue
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    user.isProvider
                        ? CupertinoIcons.person_fill
                        : CupertinoIcons.briefcase_fill,
                    color: const Color.fromARGB(
                        255, 12, 94, 153), // Changed to ChatScreen blue
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Switch Role?',
                  style: TextStyle(
                    color: Colors.black87, // Changed to black
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'You are about to switch from $currentRole to $targetRole mode.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600, // Changed to medium gray
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Additional info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 12, 94, 153)
                        .withOpacity(0.05), // Changed to ChatScreen blue
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 12, 94, 153)
                          .withOpacity(0.2), // Changed to ChatScreen blue
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        color: const Color.fromARGB(
                            255, 12, 94, 153), // Changed to ChatScreen blue
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user.isProvider
                              ? 'As a Client, you can request services from providers.'
                              : 'As a Provider, you can offer services and get hired.',
                          style: TextStyle(
                            color: Colors.black87, // Changed to black
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.grey.shade600, // Changed to medium gray
                          side: BorderSide(
                              color: Colors
                                  .grey.shade300), // Changed to light gray
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Switch Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _switchUserRole(
                              context, user, newRole, authViewModel);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                              255, 12, 94, 153), // Changed to ChatScreen blue
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_2_circlepath,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Switch',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchUserRole(BuildContext context, UserModel user,
      String newRole, AuthViewModel authViewModel) async {
    try {
      setState(() {
        _isSwitchingRole = true;
      });

      print('🔄 Starting role switch from ${user.role} to $newRole');

      // Update role using AuthViewModel
      await authViewModel.updateUserRole(newRole);

      print('✅ Role update completed');

      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Role switched to ${newRole.toUpperCase()} successfully!'),
            backgroundColor: Colors.green, // Changed to green
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error during role switch: $e');

      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch role: $e'),
            backgroundColor: Colors.red, // Changed to red
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildStatisticsRow(UserModel user) {
    final int totalJobs = _userStats?['totalJobs'] ?? user.totalJobs;
    final double rating = _userStats?['rating'] ?? user.rating;
    final int completedJobs = _userStats?['completedJobs'] ?? 0;

    Widget statItem(String label, dynamic value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, // Changed to white
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Changed shadow
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: const Color.fromARGB(255, 12, 94, 153),
                  size: 24), // Changed to ChatScreen blue
              const SizedBox(height: 8),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(
                      255, 12, 94, 153), // Changed to ChatScreen blue
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87), // Changed to black
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          statItem("Total Jobs", totalJobs, CupertinoIcons.briefcase_fill),
          const SizedBox(width: 10),
          statItem(
              "Rating", rating.toStringAsFixed(1), CupertinoIcons.star_fill),
          const SizedBox(width: 10),
          statItem("Completed", completedJobs,
              CupertinoIcons.checkmark_alt_circle_fill),
        ],
      ),
    );
  }

  /// Builds the information card based on user address availability or role.
  Widget _buildRoleOrAddressCard(UserModel profile, bool isProvider) {
    String title;
    String content;
    IconData icon;

    // Use Firebase address if available, otherwise use profile address
    final String userAddress = _userStats?['address'] ?? profile.address;

    if (userAddress.isNotEmpty) {
      title = "Address";
      content = userAddress;
      icon = CupertinoIcons.location_solid;
    } else if (isProvider) {
      title = "My Role";
      content = "You are registered as a Service Provider.";
      icon = CupertinoIcons.briefcase_fill;
    } else {
      title = "My Role";
      content = "You are registered as a Client.";
      icon = CupertinoIcons.person_alt_circle_fill;
    }
    return _buildInfoCard(title: title, content: content, icon: icon);
  }

  /// Standardized card container for displaying information.
  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // Changed to white
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Changed shadow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: const Color.fromARGB(255, 12, 94, 153),
                    size: 20), // Changed to ChatScreen blue
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color.fromARGB(
                        255, 12, 94, 153), // Changed to ChatScreen blue
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(
              color: Color.fromARGB(255, 240, 240, 240),
              height: 20,
            ),
            Text(
              content,
              style: const TextStyle(
                color: Colors.black87, // Changed to black
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
