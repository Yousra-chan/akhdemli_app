import 'package:flutter/material.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';

class ProviderDetailPage extends StatefulWidget {
  final String providerId;
  final String providerName;
  final int initialTab;

  const ProviderDetailPage({
    super.key,
    required this.providerId,
    required this.providerName,
    this.initialTab = 0,
  });

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.providerName,
          style: TextStyle(
            color: kDarkTextColor,
            fontWeight: FontWeight.w700,
            fontFamily: 'Exo2',
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kDarkTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryBlue,
          unselectedLabelColor: kMutedTextColor,
          indicatorColor: kPrimaryBlue,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Book'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildBookTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add provider details here
          Text(
            'Provider Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kDarkTextColor,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 20),
          // Add more details...
        ],
      ),
    );
  }

  Widget _buildBookTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Book Service',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kDarkTextColor,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 20),
          // Add booking form...
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kDarkTextColor,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 20),
          // Add reviews...
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
