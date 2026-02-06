import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

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

  Future<void> _deleteAccount() async {
    if (!_understandConsequences) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm you understand the consequences'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }

    if (_confirmationController.text.trim().toLowerCase() !=
        'delete my account') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type "delete my account" to confirm'),
          backgroundColor: kDangerColor,
        ),
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
          title: const Text(
            'Final Confirmation',
            style: TextStyle(color: kDangerColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This is your last chance to cancel. Your account and all data will be permanently deleted. This action cannot be undone.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: kMutedTextColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: kDangerColor),
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        await _performAccountDeletion(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to delete account';
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: kDangerColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: kDangerColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performAccountDeletion(String userId) async {
    try {
      // Delete user data from Firestore first
      await _deleteUserData(userId);

      // Delete Firebase Auth user
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();

      // Sign out
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      await authViewModel.logout();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: kSuccessColor,
          ),
        );

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during account deletion: $e'),
          backgroundColor: kDangerColor,
        ),
      );
    }
  }

  Future<void> _deleteUserData(String userId) async {
    final firestore = FirebaseFirestore.instance;

    // Delete user document
    await firestore.collection('users').doc(userId).delete();

    // You might want to delete other user-related data here
    // For example:
    // - User's services
    // - User's bookings
    // - User's messages
    // - User's reviews

    // Example: Delete user's services if they're a provider
    final servicesSnapshot = await firestore
        .collection('services')
        .where('providerId', isEqualTo: userId)
        .get();

    for (final doc in servicesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Example: Delete user's bookings
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        backgroundColor: kDangerColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kLightTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Delete Account",
          style: TextStyle(
            color: kLightTextColor,
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
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 50,
                    color: kDangerColor,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Account Deletion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDangerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This action is permanent and cannot be undone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: kDangerColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Consequences
            const Text(
              'What will be deleted:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: kDarkTextColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildConsequenceItem('Your profile information'),
            _buildConsequenceItem('All your service listings (if provider)'),
            _buildConsequenceItem('Your booking history'),
            _buildConsequenceItem('Your messages and chats'),
            _buildConsequenceItem('Your reviews and ratings'),
            _buildConsequenceItem('All app preferences and settings'),
            const SizedBox(height: 20),

            // Current User Info
            if (currentUser?.email != null) ...[
              const Text(
                'Account to be deleted:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kDarkTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentUser!.email!,
                style: const TextStyle(
                  fontSize: 16,
                  color: kMutedTextColor,
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Password Verification
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock, color: kDangerColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: kMutedTextColor,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirmation Text
            TextFormField(
              controller: _confirmationController,
              decoration: InputDecoration(
                labelText: 'Type "delete my account" to confirm',
                prefixIcon: const Icon(Icons.warning, color: kDangerColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                ),
                const Expanded(
                  child: Text(
                    'I understand that this action is permanent and all my data will be lost forever',
                    style: TextStyle(fontSize: 14),
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
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDangerColor,
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
                    : const Text(
                        'Delete Account Permanently',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                  side: BorderSide(color: kMutedTextColor.withOpacity(0.5)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kMutedTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequenceItem(String text) {
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
                color: kMutedTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
