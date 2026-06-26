import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/Services/booking_service.dart';
import 'package:service_app/Services/booking_notification_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'dart:ui' as ui;

const kPrimaryBlue = Color(0xFF007BFF);
const kDarkTextColor = Color(0xFF1A1A1A);
const kMutedTextColor = Color(0xFF666666);
const kLightBackgroundColor = Color(0xFFF8F9FA);
const kCardBackground = Color(0xFFFFFFFF);
const kSuccessGreen = Color(0xFF28A745);
const kWarningYellow = Color(0xFFFFC107);
const kErrorRed = Color(0xFFDC3545);
const kInfoBlue = Color(0xFF17A2B8);

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingService _bookingService = BookingService();
  final String _selectedFilter = 'all';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    if (mounted) setState(() => _loading = true);

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      // Get booking details before updating
      final bookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingSnapshot.exists) {
        throw Exception(
            languageProvider.tr('booking_not_found', category: 'bookings'));
      }

      final bookingData = bookingSnapshot.data() as Map<String, dynamic>;

      // Update booking status in database
      await _bookingService.updateBookingStatus(bookingId, status);

      print('✅ Booking status updated to: $status');

      // 🔔 SEND NOTIFICATION FOR STATUS CHANGE
      try {
        await BookingNotificationService.sendBookingStatusNotification(
          bookingId: bookingId,
          newStatus: status,
          providerId: bookingData['providerId'] ?? '',
          clientId: bookingData['clientId'] ?? '',
          providerName: bookingData['providerName'] ??
              languageProvider.tr('provider', category: 'bookings'),
          clientName: bookingData['clientName'] ??
              languageProvider.tr('client', category: 'bookings'),
          serviceName: bookingData['serviceTitle'] ??
              languageProvider.tr('service', category: 'bookings'),
        );
      } catch (e) {
        print('⚠️ Error sending notification: $e');
      }

      // Show appropriate success message
      String successMessage;
      switch (status.toLowerCase()) {
        case 'accepted':
          successMessage =
              languageProvider.tr('booking_accepted', category: 'bookings');
          break;
        case 'rejected':
          successMessage =
              languageProvider.tr('booking_rejected', category: 'bookings');
          break;
        case 'completed':
          successMessage =
              languageProvider.tr('booking_completed', category: 'bookings');
          break;
        case 'cancelled':
          successMessage =
              languageProvider.tr('booking_cancelled', category: 'bookings');
          break;
        default:
          successMessage =
              languageProvider.tr('booking_updated', category: 'bookings');
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, successMessage);
      }
    } catch (e) {
      print('❌ Error updating booking: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          languageProvider.trParams(
            'failed_to_update_booking',
            category: 'bookings',
            params: {'error': e.toString()},
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: AlertDialog(
          title:
              Text(languageProvider.tr('cancel_booking', category: 'bookings')),
          content: Text(
            languageProvider.tr('cancel_booking_confirmation',
                category: 'bookings'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                languageProvider.tr('keep_booking', category: 'bookings'),
                style: const TextStyle(fontFamily: 'Exo2'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (mounted) setState(() => _loading = true);

                try {
                  // Get booking details before deleting
                  final bookingSnapshot = await FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(bookingId)
                      .get();

                  if (!bookingSnapshot.exists) {
                    throw Exception(languageProvider.tr('booking_not_found',
                        category: 'bookings'));
                  }

                  final bookingData =
                      bookingSnapshot.data() as Map<String, dynamic>;

                  // Delete the booking
                  await _bookingService.deleteBooking(bookingId);

                  print('✅ Booking deleted: $bookingId');

                  // 🔔 SEND CANCELLATION NOTIFICATION
                  try {
                    await BookingNotificationService
                        .sendBookingStatusNotification(
                      bookingId: bookingId,
                      newStatus: 'cancelled',
                      providerId: bookingData['providerId'] ?? '',
                      clientId: bookingData['clientId'] ?? '',
                      providerName: bookingData['providerName'] ??
                          languageProvider.tr('provider', category: 'bookings'),
                      clientName: bookingData['clientName'] ??
                          languageProvider.tr('client', category: 'bookings'),
                      serviceName: bookingData['serviceTitle'] ??
                          languageProvider.tr('service', category: 'bookings'),
                    );
                  } catch (e) {
                    print('⚠️ Error sending cancellation notification: $e');
                  }

                  if (mounted) {
                    AppSnackBar.showSuccess(
                      context,
                      languageProvider.tr('booking_cancelled_success',
                          category: 'bookings'),
                    );
                  }
                } catch (e) {
                  print('❌ Error cancelling booking: $e');
                  if (mounted) {
                    AppSnackBar.showError(
                      context,
                      languageProvider.trParams(
                        'failed_to_cancel_booking',
                        category: 'bookings',
                        params: {'error': e.toString()},
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorRed,
              ),
              child: Text(
                languageProvider.tr('cancel_booking_button',
                    category: 'bookings'),
                style: const TextStyle(color: Colors.white, fontFamily: 'Exo2'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return kWarningYellow;
      case 'confirmed':
        return kInfoBlue;
      case 'accepted':
        return kSuccessGreen;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
      case 'rejected':
        return kErrorRed;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, LanguageProvider lang) {
    switch (status.toLowerCase()) {
      case 'pending':
        return lang.tr('status_pending', category: 'bookings');
      case 'confirmed':
        return lang.tr('status_confirmed', category: 'bookings');
      case 'accepted':
        return lang.tr('status_accepted', category: 'bookings');
      case 'completed':
        return lang.tr('status_completed', category: 'bookings');
      case 'cancelled':
        return lang.tr('status_cancelled', category: 'bookings');
      case 'rejected':
        return lang.tr('status_rejected', category: 'bookings');
      default:
        return status;
    }
  }

  Widget _buildBookingCard(BookingModel booking, bool isProvider) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final statusColor = _getStatusColor(booking.status);
        final statusText = _getStatusText(booking.status, languageProvider);

        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                      Text(
                        DateFormat(languageProvider.tr('date_format',
                                category: 'bookings'))
                            .format(booking.appointmentDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                ),

                // Booking details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.work_outline,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.serviceTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Exo2',
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${booking.servicePrice} DZD',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Provider/Client Info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isProvider
                                      ? booking.clientName
                                      : booking.providerName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Exo2',
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isProvider
                                      ? booking.clientPhone
                                      : booking.providerPhone,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Appointment Time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.access_time,
                              color: Colors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(languageProvider.tr(
                                          'full_date_format',
                                          category: 'bookings'))
                                      .format(booking.appointmentDate),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Exo2',
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(languageProvider.tr('time_format',
                                          category: 'bookings'))
                                      .format(booking.appointmentDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Notes
                      if (booking.notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '${languageProvider.tr('notes', category: 'bookings')}:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontFamily: 'Exo2',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.notes,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],

                      // Actions based on status and role
                      const SizedBox(height: 20),
                      _buildActionButtons(
                          booking, isProvider, languageProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
      BookingModel booking, bool isProvider, LanguageProvider lang) {
    if (booking.status.toLowerCase() == 'cancelled' ||
        booking.status.toLowerCase() == 'rejected' ||
        booking.status.toLowerCase() == 'completed') {
      return Container(); // No actions for finalized bookings
    }

    if (isProvider) {
      // Provider actions
      switch (booking.status.toLowerCase()) {
        case 'pending':
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _updateBookingStatus(booking.id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSuccessGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              lang.tr('accept', category: 'bookings'),
                              style: const TextStyle(fontFamily: 'Exo2'),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _updateBookingStatus(booking.id, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kErrorRed,
                    side: BorderSide(color: kErrorRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        lang.tr('reject', category: 'bookings'),
                        style: const TextStyle(fontFamily: 'Exo2'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        case 'accepted':
          return Row(
            children: [
              Expanded(
                  child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () => _updateBookingStatus(booking.id, 'completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_all, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            lang.tr('mark_completed', category: 'bookings'),
                            style: const TextStyle(fontFamily: 'Exo2'),
                          ),
                        ],
                      ),
              )),
            ],
          );
        default:
          return Container();
      }
    } else {
      // Client actions
      switch (booking.status.toLowerCase()) {
        case 'pending':
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : () => _deleteBooking(booking.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: kErrorRed,
                side: BorderSide(color: kErrorRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(kErrorRed),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          lang.tr('cancel_booking_button',
                              category: 'bookings'),
                          style: const TextStyle(fontFamily: 'Exo2'),
                        ),
                      ],
                    ),
            ),
          );
        case 'accepted':
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showContactProviderDialog(
                      booking.providerName, booking.providerPhone, lang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        lang.tr('contact_provider', category: 'bookings'),
                        style: const TextStyle(fontFamily: 'Exo2'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        default:
          return Container();
      }
    }
  }

  void _showContactProviderDialog(
      String providerName, String providerPhone, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: lang.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            lang.trParams(
              'contact_provider_title',
              category: 'bookings',
              params: {'name': providerName},
            ),
            style: const TextStyle(fontFamily: 'Exo2'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${lang.tr('phone', category: 'bookings')}: $providerPhone',
                style: const TextStyle(fontFamily: 'Exo2'),
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr('contact_provider_message', category: 'bookings'),
                style: const TextStyle(fontFamily: 'Exo2'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                lang.tr('close', category: 'bookings'),
                style: const TextStyle(fontFamily: 'Exo2'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Implement call functionality
              },
              child: Text(
                lang.tr('call', category: 'bookings'),
                style: const TextStyle(fontFamily: 'Exo2'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentUser = authViewModel.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (currentUser == null) {
      return Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 60, color: isDark ? Colors.white38 : kMutedTextColor),
                const SizedBox(height: 16),
                Text(
                  languageProvider.tr('please_sign_in', category: 'bookings'),
                  style: TextStyle(
                      fontSize: 16, color: isDark ? Colors.white70 : kMutedTextColor, fontFamily: 'Exo2'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    languageProvider.tr('sign_in', category: 'bookings'),
                    style: const TextStyle(fontFamily: 'Exo2'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isProvider = currentUser.role.toLowerCase() == 'provider';

    return DefaultTabController(
      length: 3,
      child: Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              languageProvider.tr('my_bookings', category: 'bookings'),
              style: TextStyle(fontFamily: 'Exo2', color: theme.textTheme.titleLarge?.color),
            ),
            backgroundColor: theme.cardColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.primaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              unselectedLabelColor: isDark ? Colors.white38 : kMutedTextColor,
              indicatorColor: theme.primaryColor,
              tabs: [
                Tab(text: languageProvider.tr('active', category: 'bookings')),
                Tab(
                    text:
                        languageProvider.tr('upcoming', category: 'bookings')),
                Tab(text: languageProvider.tr('history', category: 'bookings')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Active Tab
              _buildBookingsList(currentUser.uid, isProvider, 'active'),
              // Upcoming Tab
              _buildBookingsList(currentUser.uid, isProvider, 'upcoming'),
              // History Tab
              _buildBookingsList(currentUser.uid, isProvider, 'history'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(String userId, bool isProvider, String filterType) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return StreamBuilder<List<BookingModel>>(
          stream:
              _bookingService.getUserBookings(userId, isProvider, filterType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget();
            }

            if (snapshot.hasError) {
              return ErrorStateWidget(
                message: languageProvider.tr('error_loading_bookings',
                    category: 'bookings'),
                onRetry: () => setState(() {}),
              );
            }

            final bookings = snapshot.data ?? [];

            if (bookings.isEmpty) {
              return EmptyStateWidget(
                icon: _getEmptyStateIcon(filterType),
                message:
                    _getEmptyStateMessage(filterType, isProvider, languageProvider),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              color: kPrimaryBlue,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  return _buildBookingCard(bookings[index], isProvider);
                },
              ),
            );
          },
        );
      },
    );
  }

  IconData _getEmptyStateIcon(String filterType) {
    switch (filterType) {
      case 'active':
        return Icons.hourglass_empty;
      case 'upcoming':
        return Icons.calendar_today;
      case 'history':
        return Icons.history;
      default:
        return Icons.list;
    }
  }

  String _getEmptyStateMessage(
      String filterType, bool isProvider, LanguageProvider lang) {
    switch (filterType) {
      case 'active':
        return isProvider
            ? lang.tr('no_active_requests', category: 'bookings')
            : lang.tr('no_active_bookings', category: 'bookings');
      case 'upcoming':
        return isProvider
            ? lang.tr('no_upcoming_appointments', category: 'bookings')
            : lang.tr('no_upcoming_bookings', category: 'bookings');
      case 'history':
        return isProvider
            ? lang.tr('no_booking_history', category: 'bookings')
            : lang.tr('no_past_bookings', category: 'bookings');
      default:
        return lang.tr('no_bookings_found', category: 'bookings');
    }
  }
}
