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

import 'package:service_app/Services/search_service.dart';

class ProvidersListPage extends StatefulWidget {
  final String categoryName;
  final String subCategoryName;
  final String? selectedWilaya;
  final String? selectedCommune;
  final String? searchQuery;

  const ProvidersListPage({
    super.key,
    required this.categoryName,
    required this.subCategoryName,
    this.selectedWilaya,
    this.selectedCommune,
    this.searchQuery,
  });

  @override
  State<ProvidersListPage> createState() => _ProvidersListPageState();
}

class _ProvidersListPageState extends State<ProvidersListPage> {
  List<ProviderModel> _providers = [];
  List<ProviderModel> _filteredProviders = [];
  bool _isLoading = true;
  bool _showAllOverride = false;
  String _selectedRatingFilter = 'all';
  final SearchService _searchService = SearchService();
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

    final String? currentUserId = await _getCurrentUserId();

    if (currentUserId == null) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('please_login', category: 'providers_list_page'),
      );
      return;
    }

    if (provider.uid == null || provider.uid!.isEmpty) {
      AppSnackBar.showError(
        context,
        languageProvider.tr('cannot_start_chat',
            category: 'providers_list_page'),
      );
      return;
    }

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
      final user = FirebaseAuth.instance.currentUser;
      return user?.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadProviders() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final currentUserId = await _getCurrentUserId();
      List<ProviderModel> providers = [];

      if (_showAllOverride) {
        providers = await _searchService.getAllActiveProviders();
      } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        providers = await _searchService.searchProvidersComprehensive(widget.searchQuery!);
      } else {
        Query servicesQuery = FirebaseFirestore.instance
            .collection('services')
            .where('category', isEqualTo: widget.categoryName)
            .where('isActive', isEqualTo: true);

        if (widget.subCategoryName.isNotEmpty) {
          servicesQuery = servicesQuery.where('subcategory', isEqualTo: widget.subCategoryName);
        }

        final servicesSnapshot = await servicesQuery.get();

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

        // Use whereType<String> to ensure we have non-nullable Strings
        final providerIds = servicesSnapshot.docs
            .map((doc) => doc['providerId'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .whereType<String>()
            .toList();

        debugPrint('🔍 [ProvidersListPage] Found ${providerIds.length} provider IDs for category: ${widget.categoryName}');

        for (var providerId in providerIds) {
          try {
            final providerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(providerId)
                .get();

            if (providerDoc.exists) {
              final data = providerDoc.data() as Map<String, dynamic>?;
              if (data == null) {
                debugPrint('⚠️ [ProvidersListPage] Provider $providerId data is null');
                continue;
              }

              final role = data['role'] as String?;
              final profession = data['profession'] as String?;
              final isActive = data['isActive'] ?? true; 

              debugPrint('👤 [ProvidersListPage] User: ${data['name']}, Role: $role, Profession: $profession, Active: $isActive');

              // Inclusive check: show if they are a provider OR if they have a profession/services and are not an admin
              if ((role == 'provider' || (role == 'client' && profession != null)) && isActive == true) {
                providers.add(ProviderModel.fromFirestore(data, providerId));
              }
            }
 else {
              debugPrint('❌ [ProvidersListPage] Provider document $providerId does not exist');
            }
          } catch (e) {
            debugPrint('Error fetching provider $providerId: $e');
          }
        }
      }

      providers.sort((a, b) => b.rating.compareTo(a.rating));

      if (mounted) {
        setState(() {
          _providers = providers;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<ProviderModel> filtered = List.from(_providers);

    switch (_selectedRatingFilter) {
      case '4.5+': filtered = filtered.where((p) => p.rating >= 4.5).toList(); break;
      case '4.0+': filtered = filtered.where((p) => p.rating >= 4.0).toList(); break;
      case '3.5+': filtered = filtered.where((p) => p.rating >= 3.5).toList(); break;
      case '3.0+': filtered = filtered.where((p) => p.rating >= 3.0).toList(); break;
    }

    setState(() => _filteredProviders = filtered);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: lang.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            children: [
              Text(
                widget.searchQuery != null && widget.searchQuery!.isNotEmpty
                    ? widget.searchQuery!
                    : (widget.subCategoryName.isNotEmpty ? widget.subCategoryName : widget.categoryName),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Exo2',
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              if (widget.searchQuery == null && widget.subCategoryName.isNotEmpty)
                Text(
                  widget.categoryName,
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6), fontWeight: FontWeight.w600),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list_rounded, color: theme.primaryColor),
              onPressed: _showRatingFilter,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterChips(lang, theme, isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProviders,
                color: theme.primaryColor,
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: 4,
                        itemBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: ProviderSkeleton(),
                        ),
                      )
                    : _filteredProviders.isEmpty
                        ? _buildEmptyState(lang, theme)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredProviders.length,
                            itemBuilder: (context, index) {
                              return _buildProviderCard(_filteredProviders[index]);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(LanguageProvider lang, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _RatingFilterChip(
            label: _selectedRatingFilter == 'all'
                ? lang.tr('all_ratings', category: 'providers_list_page')
                : _selectedRatingFilter,
            isSelected: _selectedRatingFilter != 'all',
            onTap: _showRatingFilter,
            theme: theme,
          ),
          const Spacer(),
          Text(
            lang.trParams('results', category: 'providers_list_page', params: {'count': _filteredProviders.length.toString()}),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textTheme.bodySmall?.color?.withOpacity(0.5), fontFamily: 'Exo2'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang, ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded, size: 80, color: theme.primaryColor.withOpacity(0.2)),
              ),
              const SizedBox(height: 24),
              Text(
                lang.tr('no_providers_found', category: 'providers_list_page'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Exo2'),
              ),
              const SizedBox(height: 8),
              Text(
                lang.tr('try_adjusting_filter', category: 'providers_list_page'),
                style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedRatingFilter = 'all';
                    _showAllOverride = true;
                  });
                  _loadProviders();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(lang.tr('show_all_providers', category: 'providers_list_page'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingFilter() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  lang.tr('filter_by_rating', category: 'providers_list_page'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Exo2'),
                ),
              ),
              ..._ratingFilters.map((filter) {
                final isSelected = filter == _selectedRatingFilter;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: filter == 'all' ? Colors.grey.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded, color: filter == 'all' ? Colors.grey : Colors.amber, size: 20),
                  ),
                  title: Text(
                    filter == 'all'
                        ? lang.tr('all_ratings', category: 'providers_list_page')
                        : lang.trParams('stars', category: 'providers_list_page', params: {'value': filter.replaceAll('+', '')}),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.primaryColor) : null,
                  onTap: () {
                    setState(() => _selectedRatingFilter = filter);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderCard(ProviderModel provider) {
    return ProviderCard(
      provider: provider,
      onMessageTap: (provider) => _navigateToChatWithProvider(context, provider),
      onCallTap: (provider) => _makePhoneCall(provider.phone),
      onWhatsAppTap: (provider) => _openWhatsApp(provider.phone),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // 1. Clean number: keep only digits
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // 2. Add Algeria country code (213) if it looks like a local number
    if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '213${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9 && !cleanPhone.startsWith('213')) {
      cleanPhone = '213$cleanPhone';
    }

    final url = Uri.parse("https://wa.me/$cleanPhone");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some devices
        final fallbackUrl = Uri.parse("whatsapp://send?phone=$cleanPhone");
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl);
        } else {
          if (mounted) {
            AppSnackBar.showError(context, _tr('error_launch_whatsapp'));
          }
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  String _tr(String key) {
    return Provider.of<LanguageProvider>(context, listen: false)
        .tr(key, category: 'providers_list_page');
  }
}

class _RatingFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RatingFilterChip({required this.label, required this.isSelected, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? theme.primaryColor : theme.dividerColor),
          boxShadow: isSelected ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 18, color: isSelected ? Colors.white : Colors.amber),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isSelected ? Colors.white70 : theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}
