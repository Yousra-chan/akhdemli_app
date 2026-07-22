import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/screens/Booking/my_booking_page.dart'
    hide kLightBackgroundColor, kMutedTextColor, kPrimaryBlue;
import 'package:service_app/screens/service/provider_services_screen.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/auth_service.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/profile/settings/settings_page.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/subscription_page.dart';
import 'package:service_app/screens/admin/admin_codes_page.dart' hide kPrimaryBlue;
import 'package:service_app/screens/profile/my_posts_screen.dart' hide kPrimaryBlue;
import 'package:service_app/utils/ui_widgets.dart';

import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/screens/profile/about_us_page.dart';

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
      // Get user's rating from ratings collection
      final ratings = await _firestoreService.getUserRatings(widget.user.uid);
      double averageRating = 0;

      if (ratings.isNotEmpty) {
        final totalRating =
            ratings.fold(0.0, (sum, rating) => sum + rating['rating']);
        averageRating = totalRating / ratings.length;
      }

      // Get total jobs from bookings collection
      final bookingsAsProvider =
          await _firestoreService.getBookingsByProvider(widget.user.uid);
      final bookingsAsClient =
          await _firestoreService.getBookingsByClient(widget.user.uid);

      int totalJobs = widget.user.isProvider
          ? bookingsAsProvider.length
          : bookingsAsClient.length;

      // Get completed jobs
      int completedJobs = widget.user.isProvider
          ? bookingsAsProvider
              .where((booking) => booking['status'] == 'completed')
              .length
          : bookingsAsClient
              .where((booking) => booking['status'] == 'completed')
              .length;

      if (mounted) {
        setState(() {
          _userStats = {
            'address': widget.user.address,
            'totalJobs': totalJobs,
            'rating': averageRating,
            'completedJobs': completedJobs,
            'averageRating': averageRating,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
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

  Widget _buildSectionHeader(String title, ThemeMode? themeMode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
              letterSpacing: 1.2,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, thickness: 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final theme = Theme.of(context);

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final UserModel currentUser = authViewModel.currentUser ?? widget.user;
        final bool isProvider = currentUser.isProvider;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildAppBar(context, languageProvider),
                    _buildProfileHeader(currentUser),
                    _buildStatisticsRow(currentUser, languageProvider),
                    
                    // SECTION: ACCOUNT
                    _buildSectionHeader(languageProvider.tr('account', category: 'profile') ?? 'ACCOUNT', null),
                    _buildUserInfoSection(currentUser, languageProvider),

                    // SECTION: ACTIVITY
                    _buildSectionHeader(languageProvider.tr('activity', category: 'profile') ?? 'ACTIVITY', null),
                    _buildActivitySection(context, isProvider, languageProvider),

                    // SECTION: SETTINGS & TOOLS
                    _buildSectionHeader(languageProvider.tr('preferences', category: 'profile') ?? 'PREFERENCES', null),
                    _buildSettingsSection(context, languageProvider),

                    // SECTION: ACTIONS
                    _buildSectionHeader(languageProvider.tr('actions', category: 'profile') ?? 'ACTIONS', null),
                    _buildRoleSwitchSection(context, currentUser, authViewModel, languageProvider),
                    const SizedBox(height: 20),
                    _buildLogoutButton(context, languageProvider),
                    
                    const SizedBox(height: 50),
                  ],
                ),
              ),
              if (_isSwitchingRole)
                Container(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitySection(BuildContext context, bool isProvider, LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isProvider)
            _buildCustomListTile(
              icon: CupertinoIcons.wrench_fill,
              iconColor: theme.primaryColor,
              title: languageProvider.tr('myServices', category: 'common'),
              subtitle: languageProvider.tr('manageServices', category: 'common'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesPage())),
              useGradient: true,
            ),
          if (isProvider) const Divider(height: 1, indent: 60),
          _buildCustomListTile(
            icon: CupertinoIcons.doc_text_fill,
            iconColor: Colors.orange,
            title: languageProvider.tr('myPosts', category: 'common'),
            subtitle: languageProvider.tr('viewManagePosts', category: 'common'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen())),
            useGradient: true,
            gradientColors: [Colors.orange, const Color(0xFFFFB300)],
          ),
          const Divider(height: 1, indent: 60),
          _buildCustomListTile(
            icon: CupertinoIcons.calendar_today,
            iconColor: theme.primaryColor,
            title: languageProvider.tr('myBookings', category: 'common'),
            subtitle: isProvider
                ? languageProvider.tr('viewManageRequests', category: 'common')
                : languageProvider.tr('viewManageBookings', category: 'common'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
            useGradient: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: theme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Text(
            languageProvider.tr('profileTitle', category: 'common'),
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color ?? Colors.black87,
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
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.settings_outlined,
                color: theme.primaryColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? Colors.white10 : theme.cardColor,
                backgroundImage: ImageUtils.getImageProvider(user.photoUrl),
                child: _buildImageLoadingFallback(user),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
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
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color ?? Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (user.profession != null && user.profession!.isNotEmpty)
            Text(
              user.profession!,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
                fontSize: 16,
              ),
            )
          else if (user.phone.isNotEmpty)
            Text(
              user.phone,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build User Info Section - Wrapped to ensure it rebuilds with language
  Widget _buildUserInfoSection(
      UserModel user, LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoItem(
            icon: Icons.email_outlined,
            label: languageProvider.tr('email', category: 'common'),
            value: user.email,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildInfoItem(
            icon: Icons.phone_outlined,
            label: languageProvider.tr('phone', category: 'common'),
            value: user.phone,
          ),
          if (user.profession != null && user.profession!.isNotEmpty) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildInfoItem(
              icon: Icons.work_outline,
              label: languageProvider.tr('profession', category: 'common'),
              value: user.profession!,
            ),
          ],
          if (user.wilaya != null || user.commune != null) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildInfoItem(
              icon: Icons.location_on_outlined,
              label: languageProvider.tr('location', category: 'common'),
              value: user.getLocalizedLocation(languageProvider),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color.fromARGB(255, 12, 94, 153),
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
                    color: theme.textTheme.bodySmall?.color ?? Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
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

  Widget _buildSettingsSection(
      BuildContext context, LanguageProvider languageProvider) {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser ?? widget.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (user.isProvider)
            _buildCustomListTile(
              icon: Icons.subscriptions_outlined,
              iconColor: Colors.blue,
              title: languageProvider.tr('mySubscription', category: 'common'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPage())),
            ),
          if (user.isProvider) const Divider(height: 1, indent: 60),
          if (user.isAdmin)
            _buildCustomListTile(
              icon: Icons.vpn_key_outlined,
              iconColor: Colors.purple,
              title: languageProvider.tr('manageSubCodes', category: 'common'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCodesPage())),
            ),
          if (user.isAdmin) const Divider(height: 1, indent: 60),
          _buildCustomListTile(
            icon: Icons.info_outline,
            iconColor: Colors.teal,
            title: languageProvider.tr('aboutUs', category: 'common'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool useGradient = false,
    List<Color>? gradientColors,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: useGradient
              ? LinearGradient(
                  colors: gradientColors ?? [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: useGradient ? null : iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: useGradient ? Colors.white : iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: theme.textTheme.bodyLarge?.color,
          fontFamily: 'Exo2',
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontFamily: 'Exo2',
              ),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
    );
  }



  // Logout Button - Updated for real-time language
  Widget _buildLogoutButton(
      BuildContext context, LanguageProvider languageProvider) {
    final String logoutText = languageProvider.tr('logout', category: 'common');

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
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          foregroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text(
              logoutText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLoadingFallback(UserModel user) {
    return FutureBuilder<bool>(
      future: _checkImageValidity(user.photoUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color.fromARGB(255, 12, 94, 153),
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
        final response = await http.head(Uri.parse(photoUrl)).timeout(const Duration(seconds: 5));
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
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 50,
      backgroundColor: theme.cardColor,
      child: user.name.isNotEmpty
          ? Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 36,
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'Exo2',
              ),
            )
          : Icon(
              CupertinoIcons.person_fill,
              color: theme.primaryColor,
              size: 60,
            ),
    );
  }


  // Role Switch Section - Updated for real-time language
  Widget _buildRoleSwitchSection(BuildContext context, UserModel user,
      AuthViewModel authViewModel, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _buildRoleSwitchButton(
          context, user, authViewModel, languageProvider),
    );
  }

  // Role Switch Button - Updated for real-time language
  Widget _buildRoleSwitchButton(BuildContext context, UserModel user,
      AuthViewModel authViewModel, LanguageProvider languageProvider) {
    final String switchText =
        languageProvider.tr('switchRole', category: 'common');
    final String tapToChangeText =
        languageProvider.tr('tapToChangeRole', category: 'common');
    final String targetRole = user.isProvider
        ? languageProvider.tr('client', category: 'common')
        : languageProvider.tr('provider', category: 'common');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color.fromARGB(255, 12, 94, 153).withValues(alpha: 0.9),
            const Color(0xFF4A6FDC).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 12, 94, 153).withValues(alpha: 0.3),
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
              : () => _showRoleSwitchDialog(
                  context, user, authViewModel, languageProvider),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
                      '$switchText $targetRole',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tapToChangeText,
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
                  const SizedBox(
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
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show Role Switch Dialog - Updated for real-time language
  void _showRoleSwitchDialog(BuildContext context, UserModel user,
      AuthViewModel authViewModel, LanguageProvider languageProvider) {
    final String newRole = user.isProvider ? 'client' : 'provider';
    final String currentRole = languageProvider.tr(user.role.toLowerCase(), category: 'common');
    final String targetRole = languageProvider.tr(newRole, category: 'common');

    final String title =
        languageProvider.tr('switchRoleQuestion', category: 'common');
    final String description =
        languageProvider.tr('aboutToSwitch', category: 'common');
    final String descriptionDetail = user.isProvider
        ? languageProvider.tr('asClient', category: 'common')
        : languageProvider.tr('asProvider', category: 'common');
    final String cancelBtn = languageProvider.tr('cancel', category: 'common');
    final String switchBtn = languageProvider.tr('switch', category: 'common');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
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
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    user.isProvider
                        ? CupertinoIcons.person_fill
                        : CupertinoIcons.briefcase_fill,
                    color: theme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textTheme.titleLarge?.color ?? Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  '$description $currentRole to $targetRole.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Additional info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        color: theme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          descriptionDetail,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color ?? Colors.black87,
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
                          foregroundColor: isDark ? Colors.white70 : Colors.grey.shade600,
                          side: BorderSide(color: theme.dividerColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cancelBtn,
                          style: const TextStyle(
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
                          await _switchUserRole(context, user, newRole,
                              authViewModel, languageProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
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
                            const Icon(
                              CupertinoIcons.arrow_2_circlepath,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              switchBtn,
                              style: const TextStyle(
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

  // Switch User Role - Updated for real-time language messages
  Future<void> _switchUserRole(
      BuildContext context,
      UserModel user,
      String newRole,
      AuthViewModel authViewModel,
      LanguageProvider languageProvider) async {
    try {
      if (mounted) {
        setState(() {
          _isSwitchingRole = true;
        });
      }

      print('🔄 Starting role switch from ${user.role} to $newRole');

      // Update role using AuthViewModel
      await authViewModel.updateUserRole(newRole);

      print('✅ Role update completed');

      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });

        if (!context.mounted) return;
        // Show success message - Gets translated text in real-time
        final successMsg =
            languageProvider.tr('roleSwitchSuccess', category: 'common');
        AppSnackBar.showSuccess(context, successMsg);
      }
    } catch (e) {
      print('❌ Error during role switch: $e');

      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });

        if (!context.mounted) return;
        // Show error message - Gets translated text in real-time
        final errorMsg =
            languageProvider.tr('failedSwitch', category: 'common');
        AppSnackBar.showError(context, '$errorMsg: $e');
      }
    }
  }


  // Statistics Row - Updated for real-time language
  Widget _buildStatisticsRow(
      UserModel user, LanguageProvider languageProvider) {
    final int totalJobs = _userStats?['totalJobs'] ?? user.totalJobs;
    final double rating = _userStats?['rating'] ?? user.rating;
    final int completedJobs = _userStats?['completedJobs'] ?? 0;

    final String totalJobsLabel =
        languageProvider.tr('totalJobs', category: 'common');
    final String ratingLabel =
        languageProvider.tr('rating', category: 'common');
    final String completedLabel =
        languageProvider.tr('completed', category: 'common');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget statItem(String label, dynamic value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.primaryColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label == ratingLabel
                    ? (value is double
                        ? value.toStringAsFixed(1)
                        : value.toString())
                    : value.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
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
          statItem(totalJobsLabel, totalJobs, CupertinoIcons.briefcase_fill),
          const SizedBox(width: 10),
          statItem(ratingLabel, rating, CupertinoIcons.star_fill),
          const SizedBox(width: 10),
          statItem(completedLabel, completedJobs,
              CupertinoIcons.checkmark_alt_circle_fill),
        ],
      ),
    );
  }

}
