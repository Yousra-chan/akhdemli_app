import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'search_constants.dart';
import 'package:service_app/services/wilaya_service.dart';
import 'package:service_app/services/categories_service.dart';
import 'package:service_app/services/geocoding_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:service_app/providers/language_provider.dart';

class SearchFilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onFiltersApplied;
  final String? initialWilaya;
  final String? initialCategory;
  final String? initialSubcategory;

  const SearchFilterDialog({
    super.key,
    required this.onFiltersApplied,
    this.initialWilaya,
    this.initialCategory,
    this.initialSubcategory,
  });

  @override
  State<SearchFilterDialog> createState() => _SearchFilterDialogState();
}

class _SearchFilterDialogState extends State<SearchFilterDialog> {
  String? _selectedWilaya;
  String? _selectedCommune;
  String? _selectedCategory;
  String? _selectedSubcategory;
  double _selectedDistance = 20.0;
  bool _useDistanceFilter = false;

  // Services
  final CategoriesService _categoriesService = CategoriesService();

  // Data
  List<String> _wilayas = [];
  List<String> _communes = [];
  Map<String, List<String>> _categoriesWithSubcategories = {};
  List<String> _categories = [];
  List<String> _availableSubcategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load wilayas
      _wilayas = WilayaService.getAllWilayaNames();

      // Load categories
      _categoriesWithSubcategories =
          await _categoriesService.getCategoriesForFilter();
      _categories = _categoriesWithSubcategories.keys.toList()..sort();

      // Set initial values
      _selectedWilaya = widget.initialWilaya;
      _selectedCategory = widget.initialCategory;
      _selectedSubcategory = widget.initialSubcategory;

      // Load communes if wilaya is selected
      if (_selectedWilaya != null) {
        _communes = WilayaService.getCommunesForWilaya(_selectedWilaya!);
      }

      // Update subcategories if category is selected
      if (_selectedCategory != null) {
        _updateAvailableSubcategories();
      }
    } catch (e) {
      print('Error loading filter data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateAvailableSubcategories() {
    if (_selectedCategory == null) {
      setState(() {
        _availableSubcategories = [];
        _selectedSubcategory = null;
      });
      return;
    }

    setState(() {
      _availableSubcategories =
          _categoriesWithSubcategories[_selectedCategory!] ?? [];

      // Reset subcategory if not in new list
      if (_selectedSubcategory != null &&
          !_availableSubcategories.contains(_selectedSubcategory)) {
        _selectedSubcategory = null;
      }
    });
  }

  // Helper method to get translation key for category
  String _getCategoryKey(String categoryName) {
    final option = getFilterOptionByValue(categoryName);
    return option?.labelKey ?? '';
  }

  // Update this method to use GeocodingService.getWilayaCoordinates()
  Future<LatLng?> _getWilayaCoordinates(String wilayaName) async {
    try {
      return await GeocodingService.getWilayaCoordinates(wilayaName);
    } catch (e) {
      print('Error getting coordinates for $wilayaName: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 500,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: theme.primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          languageProvider.tr('loading_filters', category: 'search'),
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark ? Colors.white70 : kMutedTextColor,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: _buildHeader(languageProvider),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),

                            // Selected Filters Indicator
                            _buildSelectedFiltersIndicator(languageProvider),
                            const SizedBox(height: 24),

                            // Category Section
                            _buildCategorySection(languageProvider),
                            const SizedBox(height: 16),

                            // Subcategory Section (if category selected)
                            _buildSubcategorySection(languageProvider),
                            if (_selectedCategory != null &&
                                _availableSubcategories.isNotEmpty)
                              const SizedBox(height: 16),

                            // Location Section
                            _buildLocationSection(languageProvider),
                            const SizedBox(height: 16),

                            // Distance Section
                            _buildDistanceSection(languageProvider),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _buildActionButtons(languageProvider),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('filter_results', category: 'search'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Exo2',
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.tr('select_criteria', category: 'search'),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Exo2',
                  color: theme.brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.xmark, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang.tr('main_category', category: 'search'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: theme.primaryColor))
            else if (_categories.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    lang.tr('no_categories_available', category: 'search'),
                    style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : kMutedTextColor),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  final categoryKey = _getCategoryKey(category);

                  return FilterChip(
                    label: Text(
                      categoryKey.isNotEmpty
                          ? lang.tr(categoryKey, category: 'categories')
                          : category,
                      style: TextStyle(
                        fontFamily: 'Exo2',
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    avatar: Icon(
                      getCategoryIcon(category),
                      color: isSelected ? Colors.white : theme.primaryColor,
                      size: 18,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
                        _selectedSubcategory = null;
                      });
                      _updateAvailableSubcategories();
                    },
                    backgroundColor: theme.scaffoldBackgroundColor,
                    selectedColor: theme.primaryColor,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected
                            ? theme.primaryColor
                            : (theme.brightness == Brightness.dark ? Colors.white12 : kMutedTextColor.withOpacity(0.3)),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategorySection(LanguageProvider lang) {
    if (_selectedCategory == null || _availableSubcategories.isEmpty) {
      return const SizedBox();
    }
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_outlined, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang.tr('service_type', category: 'search'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubcategory,
              dropdownColor: theme.cardColor,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: theme.dividerColor),
                ),
                hintText: lang.tr('select_specific_type', category: 'search'),
                hintStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor),
              ),
              icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
              items: _availableSubcategories.map((subcategory) {
                return DropdownMenuItem<String>(
                  value: subcategory,
                  child: Text(
                    subcategory,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Exo2',
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubcategory = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang.tr('location', category: 'search'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('wilaya', category: 'search'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: theme.primaryColor)),
                        )
                      : DropdownButton<String>(
                          value: _selectedWilaya,
                          dropdownColor: theme.cardColor,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon:
                              Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                          hint: Text(
                            lang.tr('choose_wilaya', category: 'search'),
                            style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontFamily: 'Exo2'),
                          ),
                          items: _wilayas.map((wilaya) {
                            return DropdownMenuItem<String>(
                              value: wilaya,
                              child: Text(
                                wilaya,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedWilaya = value;
                              _communes = value != null
                                  ? WilayaService.getCommunesForWilaya(value)
                                  : [];
                              _selectedCommune = null;
                            });
                          },
                        ),
                ),
              ],
            ),
            if (_selectedWilaya != null) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('commune', category: 'search'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Exo2',
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: theme.dividerColor),
                    ),
                    child: _communes.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              lang.tr('no_communes_available',
                                  category: 'search'),
                              style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor),
                            ),
                          )
                        : DropdownButton<String>(
                            value: _selectedCommune,
                            dropdownColor: theme.cardColor,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down,
                                color: theme.primaryColor),
                            hint: Text(
                              lang.tr('choose_commune', category: 'search'),
                              style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontFamily: 'Exo2'),
                            ),
                            items: _communes.map((commune) {
                              return DropdownMenuItem<String>(
                                value: commune,
                                child: Text(
                                  commune,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCommune = value;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSection(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_searching_outlined,
                    color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang.tr('distance', category: 'search'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Switch(
                  value: _useDistanceFilter,
                  onChanged: (value) {
                    setState(() {
                      _useDistanceFilter = value;
                    });
                  },
                  activeThumbColor: theme.primaryColor,
                  activeTrackColor: theme.primaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang.tr('limit_by_distance', category: 'search'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Exo2',
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
            if (_useDistanceFilter) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.tr('max_distance', category: 'search'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Exo2',
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          lang.trParams('distance_value',
                              category: 'search',
                              params: {
                                'distance': _selectedDistance.toInt().toString()
                              }),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _selectedDistance,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    onChanged: (value) {
                      setState(() {
                        _selectedDistance = value;
                      });
                    },
                    activeColor: theme.primaryColor,
                    inactiveColor: theme.brightness == Brightness.dark ? Colors.white12 : kMutedTextColor.withOpacity(0.3),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(lang.tr('min_distance', category: 'search'),
                          style:
                              TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontSize: 12)),
                      Text(lang.tr('max_distance_50', category: 'search'),
                          style:
                              TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFiltersIndicator(LanguageProvider lang) {
    final theme = Theme.of(context);
    final List<String> activeFilters = [];

    if (_selectedCategory != null) {
      final categoryKey = _getCategoryKey(_selectedCategory!);
      activeFilters.add(categoryKey.isNotEmpty
          ? lang.tr(categoryKey, category: 'categories')
          : _selectedCategory!);
    }

    if (_selectedWilaya != null) activeFilters.add(_selectedWilaya!);
    if (_useDistanceFilter) {
      activeFilters.add(lang.trParams('distance_km',
          category: 'search',
          params: {'distance': _selectedDistance.toInt().toString()}));
    }

    if (activeFilters.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: theme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('active_filters', category: 'search'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeFilters.join(' • '),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                    fontFamily: 'Exo2',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedWilaya = null;
                  _selectedCommune = null;
                  _selectedCategory = null;
                  _selectedSubcategory = null;
                  _selectedDistance = 20.0;
                  _useDistanceFilter = false;
                  _communes = [];
                  _availableSubcategories = [];
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 18, color: theme.textTheme.bodyMedium?.color),
                  const SizedBox(width: 8),
                  Text(
                    lang.tr('clear_all', category: 'search'),
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontFamily: 'Exo2',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      // Get coordinates for the selected wilaya if available
                      LatLng? wilayaCoordinates;
                      if (_selectedWilaya != null) {
                        wilayaCoordinates =
                            await _getWilayaCoordinates(_selectedWilaya!);
                      }

                      final filters = {
                        'wilaya': _selectedWilaya,
                        'wilayaCoordinates': wilayaCoordinates,
                        'commune': _selectedCommune,
                        'category': _selectedCategory,
                        'subcategory': _selectedSubcategory,
                        'maxDistance':
                            _useDistanceFilter ? _selectedDistance : null,
                        'useDistanceFilter': _useDistanceFilter,
                      };

                      widget.onFiltersApplied(filters);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          lang.tr('apply_filters', category: 'search'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
