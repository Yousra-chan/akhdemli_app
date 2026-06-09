import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/subscription_service.dart';

const kPrimaryColor = Color(0xFF667EEA);
const kAccentColor = Color(0xFFFF6B6B);
const kSuccessColor = Color(0xFF4ECDC4);

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
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthViewModel>();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('subscription')
          .get();
      String? adminPhone;
      if (doc.exists) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          adminPhone = data['adminPhone'] as String?;
        }
      }
      if (adminPhone == null) {
        messenger.showSnackBar(
            SnackBar(content: Text('Admin phone not configured')));
        return;
      }
      final user = auth.currentUser;
      final message = Uri.encodeComponent(
          'Hello admin! I want to buy a subscription. My uid: ${user?.uid}, name: ${user?.name}');
      final url = Uri.parse('https://wa.me/$adminPhone?text=$message');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Error opening WhatsApp: $e')));
    }
  }

  Future<void> _applyCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    if (user == null) {
      messenger.showSnackBar(SnackBar(content: Text('Please sign in')));
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.activateSubscription(providerId: user.uid, code: code);
      messenger.showSnackBar(SnackBar(
          content: Text('Subscription activated'),
          backgroundColor: kSuccessColor));
      // refresh user - attempt to reload from user service if available
      try {
        await auth.refreshCurrentUser();
      } catch (_) {}
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: kAccentColor));
    } finally {
      setState(() => _loading = false);
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
      appBar: AppBar(title: Text('My Subscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${isActive ? 'Active' : 'Inactive'}',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            if (expiry != null) Text('Expires at: ${expiry.toDate()}'),
            SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _openWhatsApp,
                icon: Icon(Icons.chat),
                label: Text('Contact Admin (WhatsApp)'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: kPrimaryColor)),
            SizedBox(height: 24),
            TextField(
                controller: _codeCtrl,
                decoration:
                    InputDecoration(labelText: 'Enter subscription code')),
            SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loading ? null : _applyCode,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Activate')),
          ],
        ),
      ),
    );
  }
}
