import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/screens/chat/chat_screen.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/screens/home/providers_list/provider_card.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class ProvidersListPage extends StatefulWidget {
  final String categoryName;
  final String subCategoryName;
  final String? selectedWilaya;
  final String? selectedCommune;

  const ProvidersListPage({
    super.key,
    required this.categoryName,
    required this.subCategoryName,
    this.selectedWilaya,
    this.selectedCommune,
  });

  @override
  State<ProvidersListPage> createState() => _ProvidersListPageState();
}

class _ProvidersListPageState extends State<ProvidersListPage> {
  List<ProviderModel> _providers = [];
  List<ProviderModel> _filteredProviders = [];
  bool _isLoading = true;
  String _selectedRatingFilter = 'all';
  final List<String> _ratingFilters = [
    'all',
    '4.5+',
    '4.0+',
    '3.5+',
    '3.0+',
  ];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  void _navigateToChatWithProvider(
      BuildContext context, ProviderModel provider) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    // First, get the current user ID
    final String? currentUserId = await _getCurrentUserId();

    if (currentUserId == null) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('please_login', category: 'providers_list_page'),
      );
      return;
    }

    // Check if provider UID is available
    if (provider.uid == null || provider.uid!.isEmpty) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('cannot_start_chat',
            category: 'providers_list_page'),
      );
      return;
    }

    // Check if current user is trying to chat with themselves
    if (currentUserId == provider.uid!) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('cannot_chat_self',
            category: 'providers_list_page'),
      );
      return;
    }

    final chatViewModel = Provider.of<ChatViewModel?>(context, listen: false);

    if (chatViewModel == null) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('chat_service_unavailable',
            category: 'providers_list_page'),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // provider.uid! is safe here because we checked it above
      final chatId = await chatViewModel.createChat(
        clientId: currentUserId,
        providerId: provider.uid!,
      );

      if (mounted) Navigator.of(context).pop(); // Dismiss loading

      if (chatId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionPage(
              contactName: provider.name,
              isOnline: true,
              chatId: chatId,
              currentUserId: currentUserId,
              chatViewModel: chatViewModel,
              profileImageUrl: provider.photoUrl,
              contactUserId: provider.uid,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(userId: currentUserId),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Dismiss loading

      if (!mounted) return;
      AppSnackBar.showError(
        context,
        languageProvider.trParams(
          'failed_to_start_chat',
          category: 'providers_list_page',
          params: {'error': e.toString()},
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(userId: currentUserId),
        ),
      );
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      // Get current user from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // User is not logged in
        print('❌ User is not logged in');
        return null;
      }

      print('✅ Current user ID: ${user.uid}');
      return user.uid;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  Future<void> _loadProviders() async {
    try {
      print(
          '🔍 Loading providers for category: ${widget.categoryName}, subcategory: ${widget.subCategoryName}');

      // Get current user ID to filter them out
      final currentUserId = await _getCurrentUserId();

      // Step 1: Query services collection by category and subcategory
      Query servicesQuery = FirebaseFirestore.instance
          .collection('services')
          .where('category', isEqualTo: widget.categoryName)
          .where('isActive', isEqualTo: true);

      // Only filter by subcategory if it's provided and not empty
      if (widget.subCategoryName.isNotEmpty) {
        servicesQuery = servicesQuery.where('subcategory', isEqualTo: widget.subCategoryName);
      }

      final servicesSnapshot = await servicesQuery.get();
      print(
          '📊 Found ${servicesSnapshot.docs.length} services matching category and subcategory');

      if (servicesSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _providers = [];
            _filteredProviders = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Step 2: Extract unique provider IDs from services
      final providerIds = servicesSnapshot.docs
          .map((doc) => doc['providerId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      if (!mounted) return;
      print('👤 Found ${providerIds.length} unique provider IDs');

      // Step 3: Fetch provider documents from users collection
      List<ProviderModel> providers = [];

      for (var providerId in providerIds) {
        if (providerId == null) continue;

        // Skip if this provider is the current user
        if (currentUserId != null && providerId == currentUserId) {
          print('⏭️ Skipping current user from providers list');
          continue;
        }

        try {
          final providerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(providerId)
              .get();

          if (providerDoc.exists) {
            final data = providerDoc.data();
            if (data == null) continue;

            // Check if user is a provider and is active
            final role = data['role'] as String?;
            final isActive = data['isActive'] as bool? ?? true;

            if (role == 'provider' && isActive) {
              final provider = ProviderModel.fromFirestore(data, providerId);
              providers.add(provider);
              print('✅ Added provider: ${provider.name}');
            }
          }
        } catch (e) {
          print('⚠️ Error fetching provider $providerId: $e');
        }
      }

      // Sort providers by rating (highest first)
      providers.sort((a, b) => b.rating.compareTo(a.rating));

      print(
          '✅ Loaded ${providers.length} active providers (excluding current user)');

      if (mounted) {
        setState(() {
          _providers = providers;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading providers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<ProviderModel> filtered = List.from(_providers);

    // Apply rating filter
    switch (_selectedRatingFilter) {
      case '4.5+':
        filtered =
            filtered.where((provider) => provider.rating >= 4.5).toList();
        break;
      case '4.0+':
        filtered =
            filtered.where((provider) => provider.rating >= 4.0).toList();
        break;
      case '3.5+':
        filtered =
            filtered.where((provider) => provider.rating >= 3.5).toList();
        break;
      case '3.0+':
        filtered =
            filtered.where((provider) => provider.rating >= 3.0).toList();
        break;
      case 'all':
      default:
        // No rating filter applied
        break;
    }

    setState(() {
      _filteredProviders = filtered;
    });
  }

  void _showRatingFilter() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider.tr('filter_by_rating',
                      category: 'providers_list_page'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 20),
                ..._ratingFilters.map((filter) {
                  return ListTile(
                    title: Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: filter == 'all'
                              ? Colors.grey
                              : Colors.amber.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          filter == 'all'
                              ? languageProvider.tr('all_ratings',
                                  category: 'providers_list_page')
                              : languageProvider.trParams(
                                  'stars',
                                  category: 'providers_list_page',
                                  params: {'value': filter.replaceAll('+', '')},
                                ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: filter == _selectedRatingFilter
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: filter == _selectedRatingFilter
                                ? theme.primaryColor
                                : theme.textTheme.bodyLarge?.color,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                    trailing: filter == _selectedRatingFilter
                        ? Icon(
                            Icons.check_rounded,
                            color: theme.primaryColor,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedRatingFilter = filter;
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      languageProvider.tr('done',
                          category: 'providers_list_page'),
                      style: const TextStyle(fontFamily: 'Exo2'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        AppSnackBar.showError(context, lang.tr('error_launch_call', category: 'providers_list_page'));
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-numeric characters from the phone number
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final url = "https://wa.me/$cleanPhone";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        AppSnackBar.showError(context, lang.tr('error_launch_whatsapp', category: 'providers_list_page'));
      }
    }
  }

  Widget _buildProviderCard(ProviderModel provider) {
    return ProviderCard(
      provider: provider,
      onMessageTap: (provider) {
        _navigateToChatWithProvider(context, provider);
      },
      onCallTap: (provider) {
        _makePhoneCall(provider.phone);
      },
      onWhatsAppTap: (provider) {
        _openWhatsApp(provider.phone);
      },
    );
  }

  Widget _buildFilterChips() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? theme.cardColor : Colors.grey[50],
      child: Row(
        children: [
          // Rating Filter Chip
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: _selectedRatingFilter == 'all'
                      ? Colors.grey
                      : Colors.amber.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedRatingFilter == 'all'
                      ? languageProvider.tr('all_ratings',
                          category: 'providers_list_page')
                      : _selectedRatingFilter,
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedRatingFilter == 'all'
                        ? (isDark ? Colors.white70 : Colors.grey[700])
                        : (isDark ? Colors.amber[200] : Colors.amber.shade800),
                    fontFamily: 'Exo2',
                  ),
                ),
              ],
            ),
            selected: _selectedRatingFilter != 'all',
            onSelected: (_) => _showRatingFilter(),
            backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
            selectedColor: isDark ? Colors.amber.withOpacity(0.2) : Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _selectedRatingFilter == 'all'
                    ? (isDark ? Colors.white10 : Colors.grey.shade300)
                    : (isDark ? Colors.amber.withOpacity(0.5) : Colors.amber.shade200),
              ),
            ),
          ),
          const Spacer(),
          // Results count
          Text(
            languageProvider.trParams(
              'results',
              category: 'providers_list_page',
              params: {'count': _filteredProviders.length.toString()},
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);

    return EmptyStateWidget(
      icon: Icons.star_outline_rounded,
      message: languageProvider.tr('no_providers_found',
          category: 'providers_list_page'),
      subtitle: languageProvider.tr('try_adjusting_filter',
          category: 'providers_list_page'),
      action: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          setState(() {
            _selectedRatingFilter = 'all';
          });
          _applyFilters();
        },
        child: Text(
          languageProvider.tr('show_all_providers',
              category: 'providers_list_page'),
          style: const TextStyle(fontFamily: 'Exo2'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subCategoryName.isNotEmpty 
                        ? widget.subCategoryName 
                        : widget.categoryName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  if (widget.subCategoryName.isNotEmpty)
                    Text(
                      widget.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'Exo2',
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: _showRatingFilter,
                  tooltip: languageProvider.tr('filter_by_rating_tooltip',
                      category: 'providers_list_page'),
                ),
              ],
            ),
            body: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: 5,
                    itemBuilder: (context, index) => const ProviderSkeleton(),
                  )
                : Column(
                    children: [
                      _buildFilterChips(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadProviders,
                          child: _filteredProviders.isEmpty
                              ? SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: _buildEmptyState(),
                                )
                              : ListView.builder(
                                  itemCount: _filteredProviders.length,
                                  itemBuilder: (context, index) {
                                    return _buildProviderCard(
                                        _filteredProviders[index]);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
