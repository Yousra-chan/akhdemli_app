import 'package:flutter/material.dart';
import 'package:service_app/screens/service/category_section.dart';
import 'package:service_app/screens/service/sub_category_section.dart';
import 'package:service_app/screens/service/price_section.dart';
import 'package:service_app/screens/service/location_section.dart';
import 'package:service_app/screens/service/input_field.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/providers/theme_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  late List<String> _stepTitles;

  // Form data
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // State
  String _selectedPriceUnit = 'per service';
  final List<String> _selectedTags = [];
  CategoryModel? _selectedCategory;
  SubcategoryModel? _selectedSubcategory;
  String _locationAddress = '';
  double? _latitude;
  double? _longitude;

  // Validation
  bool _titleValid = false;
  bool _descriptionValid = false;
  bool _priceValid = false;
  bool _categoryValid = false;
  bool _subcategoryValid = false;
  bool _locationValid = false;

  final List<String> _priceUnits = [
    'per hour',
    'per service',
    'per day',
    'per item',
    'per square meter',
    'per session'
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_validateTitle);
    _descriptionController.addListener(_validateDescription);
    _priceController.addListener(_validatePrice);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    setState(() {
      _titleValid = _titleController.text.trim().isNotEmpty &&
          _titleController.text.trim().length >= 5;
    });
  }

  void _validateDescription() {
    setState(() {
      _descriptionValid = _descriptionController.text.trim().isNotEmpty &&
          _descriptionController.text.trim().length >= 20;
    });
  }

  void _validatePrice() {
    setState(() {
      try {
        final price = double.parse(_priceController.text.trim());
        _priceValid = price > 0 && price <= 1000000;
      } catch (e) {
        _priceValid = false;
      }
    });
  }

  bool get _currentStepValid {
    switch (_currentStep) {
      case 0:
        return _titleValid && _descriptionValid;
      case 1:
        return _categoryValid && _subcategoryValid;
      case 2:
        return _priceValid;
      case 3:
        return _locationValid;
      case 4:
        return _validateAllSteps();
      default:
        return true;
    }
  }

  bool _validateAllSteps() {
    return _titleValid &&
        _descriptionValid &&
        _categoryValid &&
        _subcategoryValid &&
        _priceValid &&
        _locationValid;
  }

  void _nextStep() {
    print(
        'Next step pressed. Current step: $_currentStep, Valid: $_currentStepValid');

    if (_currentStepValid && _currentStep < _stepTitles.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == _stepTitles.length - 1) {
      print('Creating service...');
      _submitService();
    } else {
      print('Validation failed for step $_currentStep');
      _showValidationErrorForCurrentStep();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _showValidationErrorForCurrentStep() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String message = '';

    switch (_currentStep) {
      case 0:
        message = lang.tr('validation_service_details', category: 'service');
        break;
      case 1:
        message = lang.tr('validation_category', category: 'service');
        break;
      case 2:
        message = lang.tr('validation_price', category: 'service');
        break;
      case 3:
        message = lang.tr('validation_location', category: 'service');
        break;
      case 4:
        message = lang.tr('validation_complete', category: 'service');
        break;
    }

    AppSnackBar.showError(context, message);
  }

  Widget _buildStepIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _stepTitles.length,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_stepTitles.length, (index) {
                bool isActive = index == _currentStep;
                bool isCompleted = index < _currentStep;

                return GestureDetector(
                  onTap: () {
                    if (index <= _currentStep) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentStep = index);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(end: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? kSuccessGreen
                                : isActive
                                    ? theme.primaryColor
                                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : (isDark ? Colors.white38 : Colors.grey.shade700),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stepTitles[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.normal,
                            color:
                                isActive ? theme.primaryColor : (isDark ? Colors.white38 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final serviceViewModel = Provider.of<ServiceViewModel>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!authViewModel.isInitialized) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: serviceViewModel.isLoading ? null : _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: _currentStep == 0 ? Colors.grey : theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentStep == 0
                        ? lang.tr('cancel', category: 'service')
                        : lang.tr('back', category: 'service'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _currentStep == 0 ? Colors.grey : theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: authViewModel.currentUser == null
                ? ElevatedButton(
                    onPressed: _showLoginRequiredDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.tr('login_required', category: 'service'),
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.white),
                    ),
                  )
                : ElevatedButton(
                    onPressed: serviceViewModel.isLoading || !_currentStepValid
                        ? null
                        : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStepValid
                          ? theme.primaryColor
                          : (isDark ? Colors.white10 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: serviceViewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentStep == _stepTitles.length - 1
                                    ? lang.tr('create', category: 'service')
                                    : lang.tr('next', category: 'service'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_currentStep < _stepTitles.length - 1) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward,
                                    size: 18, color: Colors.white),
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showLoginRequiredDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            Icon(Icons.login, color: theme.primaryColor),
            const SizedBox(width: 12),
            Text(lang.tr('login_required_title', category: 'service'), style: TextStyle(color: theme.textTheme.titleLarge?.color)),
          ],
        ),
        content: Text(
          lang.tr('login_required_message', category: 'service'),
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('cancel', category: 'service'), style: TextStyle(color: theme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              lang.tr('go_to_login', category: 'service'),
            ),
          ),
        ],
      ),
    );
  }

  void _submitService() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    print('=== STARTING SERVICE CREATION ===');

    FocusScope.of(context).unfocus();

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final serviceViewModel =
        Provider.of<ServiceViewModel>(context, listen: false);

    final currentUser = authViewModel.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      _showError(lang.tr('error_login_required', category: 'service'));
      return;
    }

    final selectedCategory = _selectedCategory;
    final selectedSubcategory = _selectedSubcategory;

    if (!_validateAllSteps() || selectedCategory == null || selectedSubcategory == null) {
      print('❌ Final validation failed:');
      print('  Title valid: $_titleValid');
      print('  Description valid: $_descriptionValid');
      print('  Category valid: $_categoryValid');
      print('  Subcategory valid: $_subcategoryValid');
      print('  Price valid: $_priceValid');
      print('  Location valid: $_locationValid');
      _showError(lang.tr('error_complete_fields', category: 'service'));
      return;
    }

    print('✅ All validations passed!');
    print('  Title: ${_titleController.text}');
    print('  Category: ${selectedCategory.name}');
    print('  Subcategory: ${selectedSubcategory.name}');
    print('  Price: ${_priceController.text}');
    print('  Location: $_locationAddress');

    try {
      double price;
      try {
        price = double.parse(_priceController.text.trim());
        print('✅ Price parsed: $price');
      } catch (e) {
        print('❌ Price parsing error: $e');
        _showError(lang.tr('error_invalid_price', category: 'service'));
        return;
      }

      print('=== Calling createServiceFromData ===');
      final success = await serviceViewModel.createServiceFromData(
        providerId: currentUser.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: selectedCategory.name,
        subcategory: selectedSubcategory.name,
        price: price,
        priceUnit: _selectedPriceUnit,
        location: _locationAddress,
        latitude: _latitude,
        longitude: _longitude,
        tags: _selectedTags,
        images: const [],
      );

      if (success && mounted) {
        print('✅ Service created successfully!');
        _showSuccess(lang.tr('success_service_created', category: 'service'));

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        print('❌ ServiceViewModel returned false');
        print('Error: ${serviceViewModel.error}');
        _showError(serviceViewModel.error ??
            lang.tr('error_create_failed', category: 'service'));
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION in _submitService:');
      print('  Error: $e');
      print('  Stack trace: $stackTrace');

      if (mounted) {
        String errorMessage;
        if (e.toString().contains('permission') ||
            e.toString().contains('denied')) {
          errorMessage =
              lang.tr('error_permission_denied', category: 'service');
        } else if (e.toString().contains('network')) {
          errorMessage = lang.tr('error_network', category: 'service');
        } else {
          errorMessage = lang.trParams('error_generic',
              category: 'service',
              params: {'error': e.toString().split('\n').first});
        }
        _showError(errorMessage);
      }
    }

    print('=== SERVICE CREATION ENDED ===');
  }

  void _showError(String message) {
    AppSnackBar.showError(context, message);
  }

  void _showSuccess(String message) {
    AppSnackBar.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // Force rebuild on theme change
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _stepTitles = [
      languageProvider.tr('step_details', category: 'service'),
      languageProvider.tr('step_category', category: 'service'),
      languageProvider.tr('step_pricing', category: 'service'),
      languageProvider.tr('step_location', category: 'service'),
      languageProvider.tr('step_review', category: 'service'),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.trParams('step_progress', category: 'service', params: {
                'current': (_currentStep + 1).toString(),
                'total': _stepTitles.length.toString(),
                'step': _stepTitles[_currentStep]
              }),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : kMutedTextColor,
              ),
            ),
          ],
        ),
        backgroundColor: theme.cardColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: theme.primaryColor,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: theme.primaryColor,
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(context),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildReviewStep(context),
              ],
            ),
          ),
          _buildNavigationButtons(context),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final lang = Provider.of<LanguageProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          InputField(
            label: lang.tr('service_title', category: 'service'),
            hint: lang.tr('service_title_hint', category: 'service'),
            controller: _titleController,
            icon: Icons.work_rounded,
            maxLength: 60,
            validator: (value) {
              if (value!.isEmpty) {
                return lang.tr('error_title_required', category: 'service');
              }
              if (value.length < 5) {
                return lang.tr('error_title_min_length', category: 'service');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          InputField(
            label: lang.tr('service_description', category: 'service'),
            hint: lang.tr('service_description_hint', category: 'service'),
            controller: _descriptionController,
            icon: Icons.description_rounded,
            maxLines: 5,
            maxLength: 500,
            validator: (value) {
              if (value!.isEmpty) {
                return lang.tr('error_description_required',
                    category: 'service');
              }
              if (value.length < 20) {
                return lang.tr('error_description_min_length',
                    category: 'service');
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final lang = Provider.of<LanguageProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.category,
            title: lang.tr('category_title', category: 'service'),
            subtitle: lang.tr('category_subtitle', category: 'service'),
          ),
          const SizedBox(height: 24),
          CategorySection(
            onCategorySelected: (category) {
              setState(() {
                _selectedCategory = category;
                _selectedSubcategory = null;
                _categoryValid = true;
              });
            },
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 32),
            SubcategorySection(
              selectedCategory: _selectedCategory!,
              onSubcategorySelected: (subcategory) {
                setState(() {
                  _selectedSubcategory = subcategory;
                  _subcategoryValid = true;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final lang = Provider.of<LanguageProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.attach_money,
            title: lang.tr('pricing_title', category: 'service'),
            subtitle: lang.tr('pricing_subtitle', category: 'service'),
          ),
          const SizedBox(height: 24),
          PriceSection(
            priceController: _priceController,
            selectedPriceUnit: _selectedPriceUnit,
            priceUnits: _priceUnits,
            onPriceUnitChanged: (value) {
              setState(() {
                _selectedPriceUnit = value!;
              });
            },
            onPriceChanged: () => _validatePrice(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    final lang = Provider.of<LanguageProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.location_on,
            title: lang.tr('location_title', category: 'service'),
            subtitle: lang.tr('location_subtitle', category: 'service'),
          ),
          const SizedBox(height: 24),
          LocationSection(
            onLocationUpdated: (address, lat, lng) {
              setState(() {
                _locationAddress = address;
                _latitude = lat;
                _longitude = lng;
                _locationValid = true;
              });
            },
          ),
          if (!_locationValid) ...[
            const SizedBox(height: 40),
            _buildSelectionPrompt(
              icon: Icons.location_searching,
              title: lang.tr('location_required', category: 'service'),
              description:
                  lang.tr('location_required_desc', category: 'service'),
            ),
          ] else ...[
            const SizedBox(height: 24),
            _buildSelectionConfirmation(
              icon: Icons.check_circle,
              title: lang.tr('location_detected', category: 'service'),
              description: _locationAddress.length > 60
                  ? '${_locationAddress.substring(0, 60)}...'
                  : _locationAddress,
              color: kSuccessGreen,
            ),
          ],
          const SizedBox(height: 24),
          _buildTipCard(
            lang.tr('location_tip', category: 'service'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.preview,
            title: lang.tr('review_title', category: 'service'),
            subtitle: lang.tr('review_subtitle', category: 'service'),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewItem(
                    label: lang.tr('service_title', category: 'service'),
                    value: _titleController.text.isNotEmpty
                        ? _titleController.text
                        : lang.tr('not_set', category: 'service'),
                    icon: Icons.work,
                    isValid: _titleValid,
                  ),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: lang.tr('category', category: 'service'),
                    value: _selectedCategory?.getTranslatedName(lang) ??
                        lang.tr('not_selected', category: 'service'),
                    icon: Icons.category,
                    isValid: _categoryValid,
                  ),
                  if (_selectedSubcategory != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 32),
                      child: _buildReviewItem(
                        label: lang.tr('subcategory', category: 'service'),
                        value: _selectedSubcategory!.getTranslatedName(lang),
                        icon: Icons.list,
                        isValid: _subcategoryValid,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: lang.tr('price', category: 'service'),
                    value: _priceController.text.isNotEmpty
                        ? lang.trParams('price_with_unit_review',
                            category: 'service',
                            params: {
                                'price': _priceController.text,
                                'unit': _getTranslatedPriceUnit(
                                    _selectedPriceUnit, lang)
                              })
                        : lang.tr('not_set', category: 'service'),
                    icon: Icons.attach_money,
                    isValid: _priceValid,
                  ),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: lang.tr('location', category: 'service'),
                    value: _locationAddress.isNotEmpty
                        ? _locationAddress
                        : lang.tr('not_set', category: 'service'),
                    icon: Icons.location_on,
                    isValid: _locationValid,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedTags.isNotEmpty) ...[
                    _buildReviewItem(
                      label: lang.tr('features', category: 'service'),
                      value: _selectedTags.join(', '),
                      icon: Icons.local_offer,
                      isValid: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildReviewItem(
                    label: lang.tr('description', category: 'service'),
                    value: _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : lang.tr('not_set', category: 'service'),
                    icon: Icons.description,
                    isValid: _descriptionValid,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.tr('review_info', category: 'service'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : kDarkTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTranslatedPriceUnit(String unit, LanguageProvider lang) {
    switch (unit) {
      case 'per hour':
        return lang.tr('price_unit_hour', category: 'service');
      case 'per service':
        return lang.tr('price_unit_service', category: 'service');
      case 'per day':
        return lang.tr('price_unit_day', category: 'service');
      case 'per item':
        return lang.tr('price_unit_item', category: 'service');
      case 'per square meter':
        return lang.tr('price_unit_square_meter', category: 'service');
      case 'per session':
        return lang.tr('price_unit_session', category: 'service');
      default:
        return unit;
    }
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: theme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : kMutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSelectionPrompt({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: isDark ? Colors.white38 : kMutedTextColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleMedium?.color ?? kDarkTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : kMutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionConfirmation({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : kDarkTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isValid,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isValid ? kSuccessGreen : (isDark ? Colors.white38 : kMutedTextColor),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleSmall?.color ?? kDarkTextColor,
              ),
            ),
            const Spacer(),
            Icon(
              isValid ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: isValid ? kSuccessGreen : kErrorRed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 26),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : kDarkTextColor.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(String tip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: theme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: isDark ? Colors.white70 : kDarkTextColor,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(lang.tr('help_title', category: 'service'), style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  theme,
                  lang.tr('help_step1_title', category: 'service'),
                  lang.tr('help_step1_desc', category: 'service'),
                ),
                _buildHelpItem(
                  theme,
                  lang.tr('help_step2_title', category: 'service'),
                  lang.tr('help_step2_desc', category: 'service'),
                ),
                _buildHelpItem(
                  theme,
                  lang.tr('help_step3_title', category: 'service'),
                  lang.tr('help_step3_desc', category: 'service'),
                ),
                _buildHelpItem(
                  theme,
                  lang.tr('help_step4_title', category: 'service'),
                  lang.tr('help_step4_desc', category: 'service'),
                ),
                _buildHelpItem(
                  theme,
                  lang.tr('help_step5_title', category: 'service'),
                  lang.tr('help_step5_desc', category: 'service'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('got_it', category: 'service'), style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(ThemeData theme, String title, String description) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleMedium?.color ?? kDarkTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.white54 : kMutedTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
