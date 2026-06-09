import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:service_app/Services/subscription_service.dart';

class AdminCodesPage extends StatefulWidget {
  const AdminCodesPage({super.key});

  @override
  State<AdminCodesPage> createState() => _AdminCodesPageState();
}

class _AdminCodesPageState extends State<AdminCodesPage> {
  final SubscriptionService _service = SubscriptionService();
  bool _loading = false;
  List<Map<String, dynamic>> _codes = [];

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _loading = true);
    try {
      final codes = await _service.getSubscriptionCodes();
      setState(() => _codes = codes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading codes: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final code = await _service.generateSubscriptionCode();
      await _loadCodes();
      // copy to clipboard
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Generated: $code')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Generate failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Subscription Codes')),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _generate,
        child: Icon(Icons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _codes.length,
              itemBuilder: (context, i) {
                final c = _codes[i];
                return ListTile(
                  title: Text(c['id'] ?? c['code'] ?? ''),
                  subtitle: Text(
                      'Used: ${c['used'] ?? false} - validUntil: ${c['validUntil']?.toDate() ?? ''}'),
                  trailing: IconButton(
                    icon: Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: c['id'] ?? c['code']));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Copied')));
                    },
                  ),
                );
              },
            ),
    );
  }
}
