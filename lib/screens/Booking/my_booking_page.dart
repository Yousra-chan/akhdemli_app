import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:service_app/services/booking_service.dart';

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
  String _selectedFilter = 'all';
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
    setState(() {
      _loading = true;
    });

    try {
      await _bookingService.updateBookingStatus(bookingId, status);

      // Send notification to the client when provider accepts/rejects/completes
      if (status == 'accepted' ||
          status == 'rejected' ||
          status == 'completed') {
        // We need to get the booking details first to send notification
        final bookingSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();

        if (bookingSnapshot.exists) {
          final bookingData = bookingSnapshot.data() as Map<String, dynamic>;

          await BookingNotificationService.updateBookingStatusNotification(
            bookingId: bookingId,
            newStatus: status,
            providerId: bookingData['providerId'] ?? '',
            clientId: bookingData['clientId'] ?? '',
            providerName: bookingData['providerName'] ?? 'Provider',
            clientName: bookingData['clientName'] ?? 'Client',
            serviceTitle: bookingData['serviceTitle'] ?? 'Service',
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $status successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _loading = true;
              });

              try {
                await _bookingService.deleteBooking(bookingId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete booking: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _loading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorRed,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Waiting for confirmation';
      case 'confirmed':
        return 'Confirmed';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Widget _buildBookingCard(BookingModel booking, bool isProvider) {
    final statusColor = _getStatusColor(booking.status);
    final statusText = _getStatusText(booking.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(booking.appointmentDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: kMutedTextColor,
                    fontWeight: FontWeight.w600,
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
                        color: kPrimaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.work_outline,
                        color: kPrimaryBlue,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${booking.servicePrice} DZD',
                            style: TextStyle(
                              fontSize: 14,
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w600,
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
                      child: Icon(
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isProvider
                                ? booking.clientPhone
                                : booking.providerPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: kMutedTextColor,
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
                      child: Icon(
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
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(booking.appointmentDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('h:mm a')
                                .format(booking.appointmentDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: kMutedTextColor,
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
                    'Notes:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDarkTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.notes,
                    style: TextStyle(
                      fontSize: 14,
                      color: kMutedTextColor,
                    ),
                  ),
                ],

                // Actions based on status and role
                const SizedBox(height: 20),
                _buildActionButtons(booking, isProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking, bool isProvider) {
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
                  onPressed: () => _updateBookingStatus(booking.id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSuccessGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateBookingStatus(booking.id, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kErrorRed,
                    side: BorderSide(color: kErrorRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          );
        case 'accepted':
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _updateBookingStatus(booking.id, 'completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Mark as Completed'),
                ),
              ),
            ],
          );
        default:
          return Container();
      }
    } else {
      // Client actions
      switch (booking.status.toLowerCase()) {
        case 'pending':
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _deleteBooking(booking.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kErrorRed,
                    side: BorderSide(color: kErrorRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel Booking'),
                ),
              ),
            ],
          );
        case 'accepted':
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showContactProviderDialog(
                      booking.providerName, booking.providerPhone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Contact Provider'),
                ),
              ),
            ],
          );
        default:
          return Container();
      }
    }
  }

  void _showContactProviderDialog(String providerName, String providerPhone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact $providerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: $providerPhone'),
            const SizedBox(height: 16),
            const Text('You can call or send a message to the provider.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement call functionality
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 60, color: kMutedTextColor),
              const SizedBox(height: 16),
              Text(
                'Please sign in to view your bookings',
                style: TextStyle(fontSize: 16, color: kMutedTextColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final bool isProvider = currentUser.role.toLowerCase() == 'provider';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kLightBackgroundColor,
        appBar: AppBar(
          title: const Text('My Bookings'),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kPrimaryBlue),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: kPrimaryBlue,
            unselectedLabelColor: kMutedTextColor,
            indicatorColor: kPrimaryBlue,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
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
    );
  }

  Widget _buildBookingsList(String userId, bool isProvider, String filterType) {
    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.getUserBookings(userId, isProvider, filterType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 60, color: kErrorRed),
                const SizedBox(height: 16),
                const Text(
                  'Error loading bookings',
                  style: TextStyle(fontSize: 16, color: kDarkTextColor),
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyStateIcon(filterType),
                  size: 80,
                  color: kMutedTextColor.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  _getEmptyStateMessage(filterType, isProvider),
                  style: TextStyle(
                    fontSize: 16,
                    color: kMutedTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
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

  String _getEmptyStateMessage(String filterType, bool isProvider) {
    switch (filterType) {
      case 'active':
        return isProvider ? 'No active service requests' : 'No active bookings';
      case 'upcoming':
        return isProvider ? 'No upcoming appointments' : 'No upcoming bookings';
      case 'history':
        return isProvider ? 'No booking history' : 'No past bookings';
      default:
        return 'No bookings found';
    }
  }
}
