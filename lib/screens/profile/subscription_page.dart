import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';

import 'package:service_app/screens/auth/constants.dart';

const kPrimaryColor = Color(0xFF143EAE);
const kMutedTextColor = Color(0xFF5A6670);
const kBorderColor = Color(0xFFE0E0E0);

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final SubscriptionService _service = SubscriptionService();
  bool _loading = false;

  Future<void> _openWhatsApp() async {
    final auth = context.read<AuthViewModel>();

    try {
      String? adminPhone;

      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        adminPhone = adminQuery.docs.first.data()['phone'] as String?;
      }

      if (adminPhone == null || adminPhone.isEmpty) {
        showErrorSnackBar(context, 'Admin phone not configured');
        return;
      }

      final user = auth.currentUser;

      final message = Uri.encodeComponent(
        'Hello admin, I want to buy a subscription.\n'
        'UID: ${user?.uid}\n'
        'Name: ${user?.name}',
      );

      final url = Uri.parse('https://wa.me/$adminPhone?text=$message');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      showErrorSnackBar(context, 'Error: $e');
    }
  }

  Future<void> _applyCode() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;

    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      showErrorSnackBar(context, 'Enter a code');
      return;
    }

    if (user == null) {
      showErrorSnackBar(context, 'Please sign in');
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.activateSubscription(
        providerId: user.uid,
        code: code,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Subscription activated');
      }

      try {
        await auth.refreshCurrentUser();
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (_) {}

      _codeCtrl.clear();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    final expiry = user?.subscriptionExpiresAt ?? user?.subscriptionExpiry;

    final isActive = (user?.subscriptionActive ?? false) &&
        expiry != null &&
        expiry.toDate().isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'My Subscription',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(isActive, expiry),
            const SizedBox(height: 16),
            _buildActionCard(),
            const SizedBox(height: 16),
            _buildCodeCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isActive, dynamic expiry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Subscription Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expiry != null
                ? 'Expires: ${expiry.toDate().toString().split(" ")[0]}'
                : 'No active subscription',
            style: const TextStyle(
              color: kMutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need a subscription?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Contact admin directly on WhatsApp to purchase or activate your plan.',
            style: TextStyle(color: kMutedTextColor),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat),
              label: const Text('Contact Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activate with Code',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            decoration: InputDecoration(
              hintText: 'Enter subscription code',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _applyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: kSuccessColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Activate Subscription'),
            ),
          ),
        ],
      ),
    );
  }
}
