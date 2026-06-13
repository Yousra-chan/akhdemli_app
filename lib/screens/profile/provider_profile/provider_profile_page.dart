import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/services/chat_service.dart';
import 'package:service_app/services/booking_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:flutter/services.dart';

const kPrimaryColor = Color(0xFF667EEA);
const kSecondaryColor = Color(0xFF764BA2);
const kAccentColor = Color(0xFFFF6B6B);
const kSuccessColor = Color(0xFF4ECDC4);
const kWarningColor = Color(0xFFFFD166);
const kCardBg = Color(0xFFF8FAFF);
const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kBorderColor = Color(0xFFE2E8F0);
const kShadowColor = Color(0x1A000000);
const kLightBg = Color(0xFFF7FAFC);

class ProviderProfileScreen extends StatefulWidget {
  final ProviderModel provider;
  final String serviceCategory;

  const ProviderProfileScreen({
    required this.provider,
    required this.serviceCategory,
    super.key,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late double _currentRating;
  bool _hasRated = false;
  bool _isSubmitting = false;
  late ProviderModel _provider;
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _providerServices = [];
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _notes = '';
  bool _loadingServices = true;
  bool _showBookingForm = false;
  int _bookedCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _currentRating = _provider.rating;
    _checkIfUserHasRated();
    _loadProviderServices();
    _loadBookedCount();
  }

  Future<void> _loadBookedCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _provider.uid)
          .get();
      setState(() {
        _bookedCount = snapshot.docs.length;
      });
    } catch (e) {
      // keep default 0
    }
  }

  Future<void> _openWhatsAppSupport() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('subscription')
          .get();

      String? adminPhone;
      if (doc.exists) {
        final d = doc.data();
        if (d != null && d is Map<String, dynamic>) {
          adminPhone = d['adminPhone'] as String?;
        }
      }
      if (adminPhone == null || adminPhone == '') {
        _showSnackbar(
            'Admin phone not configured. Contact support.', kAccentColor);
        return;
      }

      final message = Uri.encodeComponent(
          'Hello, I want to buy a subscription for my provider account (uid: ${_provider.uid}).');
      final url = Uri.parse('https://wa.me/$adminPhone?text=$message');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Could not open WhatsApp.', kAccentColor);
      }
    } catch (e) {
      _showSnackbar('Error opening WhatsApp: $e', kAccentColor);
    }
  }

  Future<void> _showEnterCodeDialog() async {
    final TextEditingController _codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr(context, 'enter_subscription_code')),
          content: TextField(
            controller: _codeController,
            decoration: InputDecoration(hintText: _tr(context, 'code')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tr(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = _codeController.text.trim();
                Navigator.of(context).pop();
                if (code.isNotEmpty) await _applySubscriptionCode(code);
              },
              child: Text(_tr(context, 'apply')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applySubscriptionCode(String code) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final query = await FirebaseFirestore.instance
          .collection('subscription_codes')
          .where('code', isEqualTo: code)
          .where('validUntil', isGreaterThan: now)
          .get();

      if (query.docs.isEmpty) {
        _showSnackbar(_tr(context, 'invalid_or_expired_code'), kAccentColor);
        return;
      }

      QueryDocumentSnapshot? matched;
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final used = data['used'] ?? false;
        final assignedTo = data['providerId'] as String?;
        if (used == true) continue;
        if (assignedTo == null || assignedTo == _provider.uid) {
          matched = doc;
          break;
        }
      }

      if (matched == null) {
        _showSnackbar(_tr(context, 'code_not_available_for_you'), kAccentColor);
        return;
      }

      final data = matched.data() as Map<String, dynamic>;
      final validUntil = data['validUntil'] as Timestamp?;
      if (validUntil == null || validUntil.toDate().isBefore(DateTime.now())) {
        _showSnackbar(_tr(context, 'invalid_or_expired_code'), kAccentColor);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid)
          .update({
        'subscriptionActive': true,
        'subscriptionExpiry': validUntil,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await matched.reference.update({
        'used': true,
        'usedBy': _provider.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _provider = _provider.copyWith(subscriptionActive: true);
      });

      _showSnackbar(_tr(context, 'subscription_activated'), kSuccessColor);
    } catch (e) {
      _showSnackbar(
          _trParams(context, 'error', {'error': e.toString()}), kAccentColor);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _tr(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.tr(key, category: 'provider_profile');
  }

  String _trParams(
      BuildContext context, String key, Map<String, String> params) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.trParams(key,
        category: 'provider_profile', params: params);
  }

  Future<void> _loadProviderServices() async {
    try {
      final services = await _getProviderServices(_provider.uid ?? '');
      setState(() {
        _providerServices = services;
        _loadingServices = false;
      });
    } catch (e) {
      setState(() {
        _loadingServices = false;
      });
    }
  }

  Future<void> _checkIfUserHasRated() async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    try {
      final ratingDoc = await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${authViewModel.currentUser!.uid}_${_provider.uid}')
          .get();

      if (ratingDoc.exists) {
        setState(() {
          _hasRated = true;
        });
      }
    } catch (e) {
      // Error checking rating, continue anyway
    }
  }

  Future<void> _submitRating(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    if (authViewModel.currentUser == null) {
      _showSnackbar(_tr(context, 'sign_in_to_rate'), kAccentColor);
      return;
    }

    if (_provider.uid == null || _provider.uid!.isEmpty) {
      _showSnackbar(_tr(context, 'provider_info_incomplete'), kAccentColor);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = authViewModel.currentUser!;
      final ratingId = '${currentUser.uid}_${_provider.uid!}';

      await FirebaseFirestore.instance.collection('ratings').doc(ratingId).set({
        'userId': currentUser.uid,
        'providerId': _provider.uid!,
        'rating': _currentRating,
        'createdAt': FieldValue.serverTimestamp(),
        'userName': currentUser.name,
        'userPhoto': currentUser.photoUrl,
      });

      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('providerId', isEqualTo: _provider.uid!)
          .get();

      double totalRating = 0;
      int ratingCount = ratingsSnapshot.docs.length;

      for (var doc in ratingsSnapshot.docs) {
        final data = doc.data();
        if (data['rating'] != null) {
          totalRating += (data['rating'] as num).toDouble();
        }
      }

      final newAverageRating =
          ratingCount > 0 ? totalRating / ratingCount : 0.0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid!)
          .update({
        'rating': newAverageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasRated = true;
        _provider = _provider.copyWith(rating: newAverageRating);
        _currentRating = newAverageRating;
      });

      _showSnackbar(
          _trParams(context, 'thank_you_rating',
              {'name': _provider.name, 'rating': _currentRating.toString()}),
          kSuccessColor);
    } catch (e) {
      _showSnackbar(
          _trParams(context, 'failed_submit_rating', {'error': e.toString()}),
          kAccentColor);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _bookService() async {
    final authViewModel = context.read<AuthViewModel>();
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      _showSnackbar(_tr(context, 'sign_in_to_book'), kAccentColor);
      return;
    }

    if (_selectedService == null) {
      _showSnackbar(_tr(context, 'please_select_service'), kAccentColor);
      return;
    }

    if (_selectedDate == null) {
      _showSnackbar(_tr(context, 'please_select_date'), kAccentColor);
      return;
    }

    if (_selectedTime == null) {
      _showSnackbar(_tr(context, 'please_select_time'), kAccentColor);
      return;
    }

    try {
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (appointmentDateTime.isBefore(DateTime.now())) {
        _showSnackbar(_tr(context, 'select_future_datetime'), kAccentColor);
        return;
      }

      final booking = BookingModel(
        id: '',
        clientId: currentUser.uid,
        providerId: _provider.uid!,
        serviceId: _selectedService!['id'],
        serviceTitle: _selectedService!['title'],
        servicePrice: (_selectedService!['price'] ?? 0).toDouble(),
        appointmentDate: appointmentDateTime,
        status: 'pending',
        notes: _notes,
        createdAt: DateTime.now(),
        clientName: currentUser.name,
        providerName: _provider.name,
        clientPhone: currentUser.phone,
        providerPhone: _provider.phone,
      );

      final success = await _bookingService.createBooking(booking);

      if (success) {
        await BookingNotificationService.createNewBookingNotification(
          providerId: _provider.uid!,
          clientName: currentUser.name,
          serviceTitle: _selectedService!['title'],
          clientId: currentUser.uid,
          bookingId: booking.id,
        );

        // Refresh booked count after successful booking
        await _loadBookedCount();
        _showSuccessDialog(appointmentDateTime);
      } else {
        _showSnackbar(_tr(context, 'failed_create_booking'), kAccentColor);
      }
    } catch (e) {
      _showSnackbar(
          _trParams(context, 'error', {'error': e.toString()}), kAccentColor);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kTextPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kTextPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.white,
                expandedHeight: 280.0,
                pinned: true,
                elevation: 0,
                leading: Container(
                  margin: EdgeInsets.only(left: 8, top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kShadowColor,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: kPrimaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeaderBackground(),
                  centerTitle: false,
                  titlePadding: EdgeInsets.only(left: 16, bottom: 16),
                  title: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _provider.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Contact information moved to top
                    _buildContactSection(),
                    SizedBox(height: 16),
                    _buildServicesSection(),
                    SizedBox(height: 16),
                    if (_showBookingForm) _buildBookingForm(),
                    _buildStatsSection(),
                    SizedBox(height: 16),
                    _buildRatingSection(),
                    SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          if (!_showBookingForm && _providerServices.isNotEmpty)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (_providerServices.isNotEmpty) {
                    setState(() {
                      _selectedService = _providerServices.first;
                      _showBookingForm = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    });
                  }
                },
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: Icon(Icons.calendar_today),
                label: Text(
                  _tr(context, 'book_now'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (!_showBookingForm)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: kShadowColor,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.message,
                        label: _tr(context, 'message'),
                        color: kPrimaryColor,
                        onTap: () => _startChat(context),
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.call,
                      label: _tr(context, 'call'),
                      color: kSuccessColor,
                      onTap: () => _makePhoneCall(_provider.phone),
                      isSmall: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: isSmall
              ? EdgeInsets.all(12)
              : EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isSmall ? 18 : 20, color: color),
              if (!isSmall) SizedBox(width: 8),
              if (!isSmall)
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return _buildSectionCard(
      title: _tr(context, 'services_offered'),
      icon: Icons.work_outline,
      child: _loadingServices
          ? Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _providerServices.isEmpty
              ? Column(
                  children: [
                    Icon(Icons.work_off, size: 60, color: kBorderColor),
                    SizedBox(height: 12),
                    Text(
                      _tr(context, 'no_services_listed'),
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ],
                )
              : Column(
                  children: _providerServices.map((service) {
                    final isSelected = _selectedService?['id'] == service['id'];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimaryColor.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? kPrimaryColor : kBorderColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kShadowColor,
                            blurRadius: isSelected ? 12 : 4,
                            offset: Offset(0, isSelected ? 4 : 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedService = service;
                              _showBookingForm = true;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? kPrimaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? kPrimaryColor
                                          : kBorderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              service['title'] ??
                                                  _tr(context, 'service'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? kPrimaryColor
                                                    : kTextPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${service['price'] ?? '0'} ${_tr(context, 'dzd')}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: kPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (service['description'] != null &&
                                          service['description']
                                              .isNotEmpty) ...[
                                        SizedBox(height: 8),
                                        Text(
                                          service['description'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isSelected
                                                ? kPrimaryColor.withOpacity(0.8)
                                                : kTextSecondary,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      SizedBox(height: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? kPrimaryColor.withOpacity(0.1)
                                              : kCardBg,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          service['category'] ??
                                              _tr(context, 'general'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? kPrimaryColor
                                                : kTextSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildBookingForm() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kSecondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.calendar_today,
                        size: 20, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _tr(context, 'book_service'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: kTextSecondary),
                onPressed: () {
                  setState(() {
                    _showBookingForm = false;
                    _selectedService = null;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_selectedService != null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: kSuccessColor, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedService!['title'] ?? _tr(context, 'service'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_selectedService!['price'] ?? '0'} ${_tr(context, 'dzd')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24),
          _buildBookingSteps(),
          SizedBox(height: 24),
          _buildSelectionCard(
            icon: Icons.calendar_month,
            title: _tr(context, 'date'),
            value: _selectedDate != null
                ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                : _tr(context, 'select_appointment_date'),
            onTap: () => _selectDate(context),
            color: kAccentColor,
          ),
          SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.access_time,
            title: _tr(context, 'time'),
            value: _selectedTime != null
                ? _selectedTime!.format(context)
                : _tr(context, 'select_appointment_time'),
            onTap: () => _selectTime(context),
            color: Color(0xFF4ECDC4),
          ),
          SizedBox(height: 24),
          Text(
            _tr(context, 'additional_notes'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kShadowColor,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => _notes = value,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _tr(context, 'add_instructions'),
                hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: kBorderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: kBorderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: kPrimaryColor, width: 2),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_selectedService != null &&
                          _selectedDate != null &&
                          _selectedTime != null)
                      ? kPrimaryColor.withOpacity(0.3)
                      : kTextSecondary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: (_selectedService != null &&
                        _selectedDate != null &&
                        _selectedTime != null)
                    ? _bookService
                    : null,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: (_selectedService != null &&
                            _selectedDate != null &&
                            _selectedTime != null)
                        ? LinearGradient(
                            colors: [kPrimaryColor, kSecondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              kBorderColor,
                              kBorderColor.withOpacity(0.7)
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _tr(context, 'confirm_booking'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSteps() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStep(1, _tr(context, 'step_service'), _selectedService != null),
        _buildDivider(),
        _buildStep(2, _tr(context, 'step_time'),
            _selectedDate != null && _selectedTime != null),
        _buildDivider(),
        _buildStep(3, _tr(context, 'step_confirm'), false),
      ],
    );
  }

  Widget _buildStep(int number, String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCompleted
                ? LinearGradient(
                    colors: [kSuccessColor, Color(0xFF6BCF7F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [kBorderColor, kBorderColor.withOpacity(0.7)],
                  ),
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: kSuccessColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                color: isCompleted ? Colors.white : kTextSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCompleted ? kTextPrimary : kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kBorderColor, kBorderColor.withOpacity(0.3)],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: kShadowColor,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: kBorderColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kPrimaryColor, kSecondaryColor],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildProfileImage(),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _provider.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _provider.profession.isNotEmpty
                      ? _provider.profession
                      : _tr(context, 'service_provider'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    final String? imageUrl = _provider.photoUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1)
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildRatingSection() {
    return _buildSectionCard(
      title: _tr(context, 'rate_provider'),
      icon: Icons.star,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  if (!_hasRated && !_isSubmitting) {
                    setState(() {
                      _currentRating = (index + 1).toDouble();
                    });
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    index < _currentRating.floor()
                        ? Icons.star
                        : Icons.star_border,
                    color: _hasRated
                        ? Colors.amber.withOpacity(0.5)
                        : Colors.amber,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 16),
          Text(
            _currentRating == 0
                ? _tr(context, 'tap_to_rate')
                : _trParams(context, 'stars',
                    {'rating': _currentRating.toStringAsFixed(1)}),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _getRatingDescription(_currentRating),
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 20),
          if (!_hasRated)
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isSubmitting || _currentRating == 0
                      ? null
                      : () => _submitRating(context),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kSecondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star, size: 22, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  _tr(context, 'submit_rating'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _viewAllRatings(context),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPrimaryColor, width: 2),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.reviews, size: 22, color: kPrimaryColor),
                        SizedBox(width: 12),
                        Text(
                          _tr(context, 'view_all_reviews'),
                          style: TextStyle(
                            color: kPrimaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingDescription(double rating) {
    if (rating == 0) return _tr(context, 'be_first_to_rate');
    if (rating < 2) return _tr(context, 'rating_poor');
    if (rating < 3) return _tr(context, 'rating_fair');
    if (rating < 4) return _tr(context, 'rating_good');
    if (rating < 4.5) return _tr(context, 'rating_very_good');
    return _tr(context, 'rating_excellent');
  }

  Widget _buildStatsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_tr(context, 'rating'),
              '${_currentRating.toStringAsFixed(1)}', Icons.star),
          _buildStatItem(_tr(context, 'services'),
              '${_providerServices.length}', Icons.work_outline),
          _buildStatItem(
              _tr(context, 'booked'), '$_bookedCount', Icons.verified_user),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                kPrimaryColor.withOpacity(0.1),
                kSecondaryColor.withOpacity(0.1)
              ],
            ),
          ),
          child: Icon(icon, color: kPrimaryColor, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryColor, kSecondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildSectionCard(
      title: _tr(context, 'contact_information'),
      icon: Icons.contact_phone,
      child: Column(
        children: [
          _buildContactItem(
            Icons.phone,
            _tr(context, 'phone'),
            _provider.phone,
            kSuccessColor,
            () => _makePhoneCall(_provider.phone),
          ),
          SizedBox(height: 12),
          if (_provider.whatsapp.isNotEmpty)
            _buildContactItem(
              Icons.chat,
              _tr(context, 'whatsapp'),
              _provider.whatsapp,
              Color(0xFF25D366),
              () => _openWhatsApp(_provider.whatsapp),
            ),
          if (_provider.whatsapp.isNotEmpty) SizedBox(height: 12),
          _buildContactItem(
            Icons.location_on,
            _tr(context, 'address'),
            _provider.address,
            kAccentColor,
            () => _openLocationInMaps(_provider.address),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: kBorderColor),
            ],
          ),
        ),
      ),
    );
  }

  void _startChat(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatService = ChatService();

    if (authViewModel.currentUser == null) {
      _showSnackbar(_tr(context, 'sign_in_to_book'), kAccentColor);
      return;
    }

    try {
      final chatId = await chatService.createChat(
        clientId: authViewModel.currentUser!.uid,
        providerId: _provider.uid!,
      );

      if (chatId != null) {
        _showSnackbar(
          _trParams(context, 'chat_started', {'name': _provider.name}),
          kSuccessColor,
        );
      } else {
        _showSnackbar(
          _tr(context, 'failed_start_chat'),
          kAccentColor,
        );
      }
    } catch (e) {
      _showSnackbar(
        _trParams(context, 'failed_start_chat', {'error': e.toString()}),
        kAccentColor,
      );
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:${_cleanPhoneNumber(phoneNumber)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openWhatsApp(String whatsappNumber) async {
    final cleanNumber = _cleanPhoneNumber(whatsappNumber);
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openLocationInMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse('https://maps.google.com/?q=$encodedAddress');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccessDialog(DateTime appointmentDateTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [kSuccessColor, Color(0xFF6BCF7F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kSuccessColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.check, size: 40, color: Colors.white),
            ),
            SizedBox(height: 24),
            Text(
              _tr(context, 'booking_confirmed'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              _trParams(
                  context, 'appointment_scheduled', {'name': _provider.name}),
              style: TextStyle(
                fontSize: 15,
                color: kTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy • h:mm a')
                  .format(appointmentDateTime),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedService = null;
                      _selectedDate = null;
                      _selectedTime = null;
                      _notes = '';
                      _showBookingForm = false;
                    });
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kSecondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _tr(context, 'done'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getProviderServices(
      String providerId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _viewAllRatings(BuildContext context) async {
    if (_provider.uid == null || _provider.uid!.isEmpty) {
      _showSnackbar(_tr(context, 'provider_info_incomplete'), kAccentColor);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryColor, kSecondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _tr(context, 'all_reviews'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ratings')
                      .where('providerId', isEqualTo: _provider.uid!)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: kPrimaryColor));
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 60, color: kAccentColor),
                            SizedBox(height: 16),
                            Text(
                              _tr(context, 'error_loading_reviews'),
                              style: TextStyle(
                                fontSize: 16,
                                color: kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reviews, size: 60, color: kBorderColor),
                            SizedBox(height: 16),
                            Text(
                              _tr(context, 'no_reviews'),
                              style: TextStyle(
                                fontSize: 16,
                                color: kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final ratings = snapshot.data!.docs;

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: ratings.length,
                      itemBuilder: (context, index) {
                        final rating = ratings[index];
                        final data = rating.data() as Map<String, dynamic>;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: kShadowColor,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: data['userPhoto'] != null &&
                                        data['userPhoto'].isNotEmpty
                                    ? NetworkImage(data['userPhoto'])
                                    : null,
                                backgroundColor: kPrimaryColor.withOpacity(0.1),
                                child: data['userPhoto'] == null ||
                                        data['userPhoto'].isEmpty
                                    ? Icon(Icons.person, color: kPrimaryColor)
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['userName'] ??
                                                _tr(context, 'anonymous'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: kTextPrimary,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children:
                                              List.generate(5, (starIndex) {
                                            final ratingValue =
                                                (data['rating'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;
                                            return Icon(
                                              starIndex < ratingValue.floor()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (data['createdAt'] != null)
                                      Text(
                                        _formatDate(
                                            (data['createdAt'] as Timestamp)
                                                .toDate()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return _tr(context, 'just_now');
        return _trParams(context, 'minutes_ago',
            {'minutes': difference.inMinutes.toString()});
      }
      return _trParams(
          context, 'hours_ago', {'hours': difference.inHours.toString()});
    } else if (difference.inDays == 1) {
      return _tr(context, 'yesterday');
    } else if (difference.inDays < 7) {
      return _trParams(
          context, 'days_ago', {'days': difference.inDays.toString()});
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
