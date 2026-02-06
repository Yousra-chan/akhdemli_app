import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'search_constants.dart';

class CustomServiceSearchDelegate extends SearchDelegate<String> {
  final SearchViewModel _searchViewModel;

  CustomServiceSearchDelegate() : _searchViewModel = SearchViewModel();

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: kCardBackgroundColor,
        iconTheme: theme.iconTheme.copyWith(color: kDarkTextColor),
        titleTextStyle: const TextStyle(
          color: kDarkTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Exo2',
        ),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: kMutedTextColor, fontFamily: 'Exo2'),
        border: InputBorder.none,
      ),
      scaffoldBackgroundColor: kLightBackgroundColor,
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(CupertinoIcons.clear_thick_circled),
        color: kMutedTextColor,
        onPressed: () {
          if (query.isEmpty) {
            close(context, '');
          } else {
            query = '';
          }
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(CupertinoIcons.back),
      color: kDarkTextColor,
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _searchViewModel,
      child: Consumer<SearchViewModel>(
        builder: (context, viewModel, child) {
          if (query.isEmpty) {
            return _buildEmptyState(
              context,
              "Type a service or provider name to search",
            );
          }

          // Trigger search when query changes
          if (viewModel.providerResults.isEmpty && !viewModel.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.searchProvidersOnly(query);
            });
          }

          return _buildSearchResults(context, viewModel);
        },
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchViewModel viewModel) {
    if (viewModel.isLoading) {
      return _buildLoadingState(context);
    }

    if (viewModel.error != null) {
      return _buildEmptyState(context, viewModel.error!);
    }

    final providers = viewModel.providerResults;

    if (providers.isEmpty) {
      return _buildEmptyState(context, "No providers found for '$query'");
    }

    return _buildProvidersList(context, providers, "Search Results");
  }

  Widget _buildProvidersList(
    BuildContext context,
    List<ProviderModel> providers,
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Exo2',
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: kLightBackgroundColor,
            child: ListView.builder(
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];
                return _buildProviderCard(context, provider);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard(BuildContext context, ProviderModel provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shadowColor: kSoftShadowColor,
      color: kCardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getProfessionIcon(provider.profession),
            color: kPrimaryBlue,
            size: 24,
          ),
        ),
        title: Text(
          provider.name,
          style: const TextStyle(
            color: kDarkTextColor,
            fontFamily: 'Exo2',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              provider.profession,
              style: TextStyle(
                color: kPrimaryBlue,
                fontFamily: 'Exo2',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            if (provider.wilaya.isNotEmpty || provider.commune.isNotEmpty)
              Row(
                children: [
                  Icon(
                    CupertinoIcons.location_solid,
                    color: kMutedTextColor,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${provider.commune.isNotEmpty ? '${provider.commune}, ' : ''}${provider.wilaya}',
                      style: TextStyle(
                        color: kMutedTextColor,
                        fontSize: 12,
                        fontFamily: 'Exo2',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (provider.rating > 0) ...[
                  Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    provider.rating.toStringAsFixed(1),
                    style: TextStyle(
                      color: kDarkTextColor,
                      fontSize: 12,
                      fontFamily: 'Exo2',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (provider.subscriptionActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: kPrimaryBlue,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: kPrimaryBlue,
                            fontSize: 10,
                            fontFamily: 'Exo2',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          color: kMutedTextColor,
          size: 16,
        ),
        onTap: () {
          close(context, provider.name);
          // Navigate to provider profile
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (context) => ProviderProfilePage(provider: provider),
          // ));
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<FilterOption> suggestions = query.isEmpty
        ? allSearchOptions.take(8).toList()
        : allSearchOptions
            .where(
              (option) =>
                  option.label.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    return Container(
      color: kLightBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (query.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Popular Services",
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ] else if (suggestions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Suggestions",
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return _buildSuggestionItem(context, suggestion);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(BuildContext context, FilterOption suggestion) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shadowColor: kSoftShadowColor,
      color: kCardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getSuggestionColor(suggestion.value),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getSuggestionIcon(suggestion.value),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          suggestion.label,
          style: const TextStyle(
            color: kDarkTextColor,
            fontFamily: 'Exo2',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _getSuggestionSubtitle(suggestion.value),
          style: TextStyle(
            color: kMutedTextColor.withOpacity(0.8),
            fontFamily: 'Exo2',
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          color: kMutedTextColor,
          size: 14,
        ),
        onTap: () {
          query = suggestion.label;
          showResults(context);
        },
      ),
    );
  }

  Color _getSuggestionColor(String value) {
    if (serviceFilters.any((filter) => filter.value == value)) {
      return kPrimaryBlue;
    } else if (cityFilters.any((filter) => filter.value == value)) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  IconData _getSuggestionIcon(String value) {
    if (serviceFilters.any((filter) => filter.value == value)) {
      return CupertinoIcons.briefcase_fill;
    } else if (cityFilters.any((filter) => filter.value == value)) {
      return CupertinoIcons.location_fill;
    } else {
      return CupertinoIcons.star_fill;
    }
  }

  String _getSuggestionSubtitle(String value) {
    if (serviceFilters.any((filter) => filter.value == value)) {
      return 'Service Category';
    } else if (cityFilters.any((filter) => filter.value == value)) {
      return 'Location';
    } else {
      return 'Filter';
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kPrimaryBlue),
          const SizedBox(height: 16),
          Text(
            "Searching...",
            style: TextStyle(
              color: kMutedTextColor,
              fontFamily: 'Exo2',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, color: kMutedTextColor, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: kMutedTextColor,
              fontFamily: 'Exo2',
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getProfessionIcon(String profession) {
    final lowerProfession = profession.toLowerCase();

    if (lowerProfession.contains('electric')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerProfession.contains('doctor') ||
        lowerProfession.contains('medical')) {
      return CupertinoIcons.heart_fill;
    } else if (lowerProfession.contains('plumb')) {
      return CupertinoIcons.drop_fill;
    } else if (lowerProfession.contains('tutor') ||
        lowerProfession.contains('teacher')) {
      return CupertinoIcons.book_fill;
    } else if (lowerProfession.contains('handyman') ||
        lowerProfession.contains('repair')) {
      return CupertinoIcons.wrench_fill;
    } else if (lowerProfession.contains('clean') ||
        lowerProfession.contains('nettoy')) {
      return CupertinoIcons.house_fill;
    } else if (lowerProfession.contains('carpent') ||
        lowerProfession.contains('menuis')) {
      return CupertinoIcons.hammer_fill;
    } else if (lowerProfession.contains('paint') ||
        lowerProfession.contains('peint')) {
      return CupertinoIcons.paintbrush_fill;
    } else if (lowerProfession.contains('garden') ||
        lowerProfession.contains('jardin')) {
      return CupertinoIcons.clear_fill;
    } else if (lowerProfession.contains('move') ||
        lowerProfession.contains('déménag')) {
      return CupertinoIcons.car_fill;
    } else {
      return CupertinoIcons.person_fill;
    }
  }

  @override
  void dispose() {
    _searchViewModel.clearResults();
    super.dispose();
  }
}
