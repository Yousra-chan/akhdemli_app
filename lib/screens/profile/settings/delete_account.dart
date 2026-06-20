import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _understandConsequences = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount(LanguageProvider languageProvider) async {
    if (!_understandConsequences) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('pleaseConfirmDelete', category: 'profile'),
      );
      return;
    }

    final confirmationText = languageProvider.tr('delete_my_account_cmd', category: 'profile');
    if (_confirmationController.text.trim().toLowerCase() !=
        confirmationText.toLowerCase()) {
      AppSnackBar.showError(
        context,
        languageProvider.trParams('type_exact_to_confirm', 
            category: 'profile', 
            params: {'cmd': confirmationText}),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Show final confirmation dialog
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            languageProvider.tr('finalConfirmation', category: 'profile'),
            style: const TextStyle(
              color: kDangerColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            languageProvider.tr('deleteLastChance', category: 'profile'),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                languageProvider.tr('cancel', category: 'profile'),
                style: const TextStyle(color: kMutedTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: kDangerColor),
              child: Text(
                languageProvider.tr('deleteForever', category: 'profile'),
              ),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        if (!context.mounted) return;
        await _performAccountDeletion(user.uid, languageProvider);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          languageProvider.tr('failedChangePassword', category: 'profile');
      if (e.code == 'wrong-password') {
        errorMessage =
            languageProvider.tr('incorrectPassword', category: 'profile');
      }

      if (!context.mounted) return;
      AppSnackBar.showError(context, errorMessage);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(
        context,
        '${languageProvider.tr('errorAccountDeletion', category: 'profile')} $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performAccountDeletion(
    String userId,
    LanguageProvider languageProvider,
  ) async {
    try {
      // Delete user data from Firestore first
      await _deleteUserData(userId);

      // Delete Firebase Auth user
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();

      // Sign out
      if (!context.mounted) return;
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      await authViewModel.logout();

      if (mounted) {
        if (!context.mounted) return;
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('accountDeletedSuccess', category: 'profile'),
        );

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(
        context,
        '${languageProvider.tr('errorAccountDeletion', category: 'profile')} $e',
      );
    }
  }

  Future<void> _deleteUserData(String userId) async {
    final firestore = FirebaseFirestore.instance;

    // Delete user document
    await firestore.collection('users').doc(userId).delete();

    // Delete user's services if they're a provider
    final servicesSnapshot = await firestore
        .collection('services')
        .where('providerId', isEqualTo: userId)
        .get();

    for (final doc in servicesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete user's bookings
    final bookingsSnapshot = await firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in bookingsSnapshot.docs) {
      await doc.reference.delete();
    }

    print('User data deleted successfully for: $userId');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: kDangerColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          languageProvider.tr('deleteAccount', category: 'profile'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Exo2',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kDangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kDangerColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 50,
                    color: kDangerColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    languageProvider.tr('deleteAccountPermanent',
                        category: 'profile'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDangerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageProvider.tr('deleteAccountIsPermanent',
                        category: 'profile'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: kDangerColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Consequences
            Text(
              languageProvider.tr('whatWillBeDeleted', category: 'profile'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color ?? kDarkTextColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildConsequenceItem(
              languageProvider.tr('profileInfo', category: 'profile'),
              theme,
            ),
            _buildConsequenceItem(
              languageProvider.tr('serviceListings', category: 'profile'),
              theme,
            ),
            _buildConsequenceItem(
              languageProvider.tr('bookingHistory', category: 'profile'),
              theme,
            ),
            _buildConsequenceItem(
              languageProvider.tr('messagesChats', category: 'profile'),
              theme,
            ),
            _buildConsequenceItem(
              languageProvider.tr('reviewsRatings', category: 'profile'),
              theme,
            ),
            _buildConsequenceItem(
              languageProvider.tr('appPreferences', category: 'profile'),
              theme,
            ),
            const SizedBox(height: 20),

            // Current User Info
            if (currentUser?.email != null) ...[
              Text(
                languageProvider.tr('accountToBeDeleted', category: 'profile'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleSmall?.color ?? kDarkTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentUser!.email!,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : kMutedTextColor,
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Password Verification
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText:
                    languageProvider.tr('currentPassword', category: 'profile'),
                labelStyle: TextStyle(color: isDark ? Colors.white54 : kMutedTextColor),
                prefixIcon: const Icon(Icons.lock, color: kDangerColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: isDark ? Colors.white54 : kMutedTextColor,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirmation Text
            TextFormField(
              controller: _confirmationController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: languageProvider.tr('typeDeleteConfirm',
                    category: 'profile'),
                labelStyle: TextStyle(color: isDark ? Colors.white54 : kMutedTextColor),
                prefixIcon: const Icon(Icons.warning, color: kDangerColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Understanding Checkbox
            Row(
              children: [
                Checkbox(
                  value: _understandConsequences,
                  onChanged: (value) =>
                      setState(() => _understandConsequences = value!),
                  activeColor: kDangerColor,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey),
                ),
                Expanded(
                  child: Text(
                    languageProvider.tr('understandConsequences',
                        category: 'profile'),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : () => _deleteAccount(languageProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDangerColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        languageProvider.tr('deleteAccountPermanently',
                            category: 'profile'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: isDark ? Colors.white24 : kMutedTextColor.withOpacity(0.5)),
                  foregroundColor: isDark ? Colors.white70 : kMutedTextColor,
                ),
                child: Text(
                  languageProvider.tr('cancel', category: 'profile'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequenceItem(String text, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.remove, size: 16, color: kDangerColor.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : kMutedTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
