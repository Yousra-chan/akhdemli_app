import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/service/category_section.dart';
import 'package:service_app/screens/service/sub_category_section.dart';
import 'package:service_app/screens/service/price_section.dart';
import 'package:service_app/screens/service/location_section.dart';
import 'package:service_app/screens/service/input_field.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/providers/language_provider.dart';

class EditServiceScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;

  const EditServiceScreen({
    super.key,
    required this.serviceData,
  });

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
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
  bool _hasLocation = false;

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
    _loadServiceData();

    // Listen for validation
    _titleController.addListener(_validateTitle);
    _descriptionController.addListener(_validateDescription);
    _priceController.addListener(_validatePrice);
  }

  void _loadServiceData() {
    // Load existing service data
    final service = widget.serviceData;

    _titleController.text = service['title'] ?? '';
    _descriptionController.text = service['description'] ?? '';
    _priceController.text = service['price']?.toString() ?? '';
    _selectedPriceUnit = service['priceUnit'] ?? 'per service';
    _locationAddress = service['location'] ?? '';
    _latitude = service['latitude'];
    _longitude = service['longitude'];

    // Parse category and subcategory
    final categoryName = service['category'];
    final subcategoryName = service['subcategory'];

    // You'll need to load categories from your data source
    // For now, we'll set validation based on existing data
    if (categoryName != null) {
      _categoryValid = true;
    }
    if (subcategoryName != null) {
      _subcategoryValid = true;
    }
    if (_locationAddress.isNotEmpty) {
      _locationValid = true;
      _hasLocation = true;
    }

    // Set initial validation
    _validateTitle();
    _validateDescription();
    _validatePrice();
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
    final lang = Provider.of<LanguageProvider>(context, listen: false);

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
      print('Updating service...');
      _updateService();
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
        message =
            lang.tr('validation_service_details', category: 'edit_service');
        break;
      case 1:
        message = lang.tr('validation_category', category: 'edit_service');
        break;
      case 2:
        message = lang.tr('validation_price', category: 'edit_service');
        break;
      case 3:
        message = lang.tr('validation_location', category: 'edit_service');
        break;
      case 4:
        message = lang.tr('validation_complete', category: 'edit_service');
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kErrorRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final lang = Provider.of<LanguageProvider>(context);
    _stepTitles = [
      lang.tr('step_details', category: 'edit_service'),
      lang.tr('step_category', category: 'edit_service'),
      lang.tr('step_pricing', category: 'edit_service'),
      lang.tr('step_location', category: 'edit_service'),
      lang.tr('step_review', category: 'edit_service'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _stepTitles.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
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
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? kSuccessGreen
                                : isActive
                                    ? kPrimaryBlue
                                    : Colors.grey.shade300,
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
                                          : Colors.grey.shade700,
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
                                isActive ? kPrimaryBlue : Colors.grey.shade600,
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

  Widget _buildNavigationButtons() {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final serviceViewModel = Provider.of<ServiceViewModel>(context);
    final lang = Provider.of<LanguageProvider>(context);

    // Check if auth is initialized
    if (!authViewModel.isInitialized) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: kPrimaryBlue),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: _currentStep == 0 ? Colors.grey : kPrimaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentStep == 0
                        ? lang.tr('cancel', category: 'edit_service')
                        : lang.tr('back', category: 'edit_service'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _currentStep == 0 ? Colors.grey : kPrimaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: authViewModel.currentUser == null ||
                      serviceViewModel.isLoading ||
                      !_currentStepValid
                  ? null
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: authViewModel.currentUser == null
                    ? Colors.grey.shade300
                    : _currentStepValid
                        ? kPrimaryBlue
                        : Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authViewModel.currentUser == null
                  ? Text(
                      lang.tr('login_required', category: 'edit_service'),
                      style: const TextStyle(color: Colors.white),
                    )
                  : serviceViewModel.isLoading
                      ? SizedBox(
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
                                  ? lang.tr('update', category: 'edit_service')
                                  : lang.tr('next', category: 'edit_service'),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.login, color: kPrimaryBlue),
            const SizedBox(width: 12),
            Text(lang.tr('login_required_title', category: 'edit_service')),
          ],
        ),
        content: Text(
          lang.tr('login_required_message', category: 'edit_service'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('cancel', category: 'edit_service')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
            ),
            child: Text(
              lang.tr('go_to_login', category: 'edit_service'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: kErrorRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: kSuccessGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _updateService() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    print('=== STARTING SERVICE UPDATE ===');

    FocusScope.of(context).unfocus();

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final serviceViewModel =
        Provider.of<ServiceViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      print('❌ No user logged in');
      _showError(lang.tr('error_login_required', category: 'edit_service'));
      return;
    }

    if (!_validateAllSteps()) {
      print('❌ Final validation failed:');
      print('  Title valid: $_titleValid');
      print('  Description valid: $_descriptionValid');
      print('  Category valid: $_categoryValid');
      print('  Subcategory valid: $_subcategoryValid');
      print('  Price valid: $_priceValid');
      print('  Location valid: $_locationValid');
      _showError(lang.tr('error_complete_fields', category: 'edit_service'));
      return;
    }

    print('✅ All validations passed!');
    print('  Title: ${_titleController.text}');
    print('  Category: ${_selectedCategory?.name}');
    print('  Subcategory: ${_selectedSubcategory?.name}');
    print('  Price: ${_priceController.text}');
    print('  Location: $_locationAddress');

    // Check for null values before proceeding
    if (_selectedCategory == null) {
      print('❌ Category is null');
      _showError(lang.tr('error_select_category', category: 'edit_service'));
      return;
    }

    if (_selectedSubcategory == null) {
      print('❌ Subcategory is null');
      _showError(lang.tr('error_select_subcategory', category: 'edit_service'));
      return;
    }

    try {
      double price;
      try {
        price = double.parse(_priceController.text.trim());
        print('✅ Price parsed: $price');
      } catch (e) {
        print('❌ Price parsing error: $e');
        _showError(lang.tr('error_invalid_price', category: 'edit_service'));
        return;
      }

      print('=== Calling updateService ===');
      final success = await serviceViewModel.updateService(
        serviceId: widget.serviceData['id'] ?? '',
        providerId: authViewModel.currentUser!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!.name,
        subcategory: _selectedSubcategory!.name,
        price: price,
        priceUnit: _selectedPriceUnit,
        location: _locationAddress,
        latitude: _latitude,
        longitude: _longitude,
        tags: _selectedTags,
      );

      if (success && mounted) {
        print('✅ Service updated successfully!');
        _showSuccess(
            lang.tr('success_service_updated', category: 'edit_service'));

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        print('❌ ServiceViewModel returned false');
        print('Error: ${serviceViewModel.error}');
        _showError(serviceViewModel.error ??
            lang.tr('error_update_failed', category: 'edit_service'));
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION in _updateService:');
      print('  Error: $e');
      print('  Stack trace: $stackTrace');

      if (mounted) {
        String errorMessage;
        if (e.toString().contains('permission') ||
            e.toString().contains('denied')) {
          errorMessage =
              lang.tr('error_permission_denied', category: 'edit_service');
        } else if (e.toString().contains('network')) {
          errorMessage = lang.tr('error_network', category: 'edit_service');
        } else if (e.toString().contains('Null check')) {
          errorMessage =
              lang.tr('error_complete_fields', category: 'edit_service');
        } else {
          errorMessage = lang.trParams('error_generic',
              category: 'edit_service',
              params: {'error': e.toString().split('\n').first});
        }
        _showError(errorMessage);
      }
    }

    print('=== SERVICE UPDATE ENDED ===');
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    _stepTitles = [
      lang.tr('step_details', category: 'edit_service'),
      lang.tr('step_category', category: 'edit_service'),
      lang.tr('step_pricing', category: 'edit_service'),
      lang.tr('step_location', category: 'edit_service'),
      lang.tr('step_review', category: 'edit_service'),
    ];

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.trParams('step_progress', category: 'edit_service', params: {
                'current': (_currentStep + 1).toString(),
                'total': _stepTitles.length.toString(),
                'step': _stepTitles[_currentStep]
              }),
              style: TextStyle(
                fontSize: 12,
                color: kMutedTextColor,
              ),
            ),
            Text(
              lang.tr('edit_service', category: 'edit_service'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kDarkTextColor,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: kPrimaryBlue,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: kPrimaryBlue,
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
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
                _buildReviewStep(),
              ],
            ),
          ),
          _buildNavigationButtons(),
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
            label: lang.tr('service_title', category: 'edit_service'),
            hint: lang.tr('service_title_hint', category: 'edit_service'),
            controller: _titleController,
            icon: Icons.work_rounded,
            maxLength: 60,
            validator: (value) {
              if (value!.isEmpty)
                return lang.tr('error_title_required',
                    category: 'edit_service');
              if (value.length < 5)
                return lang.tr('error_title_min_length',
                    category: 'edit_service');
              return null;
            },
          ),
          const SizedBox(height: 24),
          InputField(
            label: lang.tr('service_description', category: 'edit_service'),
            hint: lang.tr('service_description_hint', category: 'edit_service'),
            controller: _descriptionController,
            icon: Icons.description_rounded,
            maxLines: 5,
            maxLength: 500,
            validator: (value) {
              if (value!.isEmpty)
                return lang.tr('error_description_required',
                    category: 'edit_service');
              if (value.length < 20)
                return lang.tr('error_description_min_length',
                    category: 'edit_service');
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
            title: lang.tr('category_title', category: 'edit_service'),
            subtitle: lang.tr('category_subtitle', category: 'edit_service'),
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
            title: lang.tr('pricing_title', category: 'edit_service'),
            subtitle: lang.tr('pricing_subtitle', category: 'edit_service'),
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
            title: lang.tr('location_title', category: 'edit_service'),
            subtitle: lang.tr('location_subtitle', category: 'edit_service'),
          ),
          const SizedBox(height: 24),
          LocationSection(
            onLocationUpdated: (address, lat, lng) {
              setState(() {
                _locationAddress = address;
                _latitude = lat;
                _longitude = lng;
                _hasLocation = true;
                _locationValid = true;
              });
            },
          ),
          if (!_locationValid) ...[
            const SizedBox(height: 40),
            _buildSelectionPrompt(
              icon: Icons.location_searching,
              title: lang.tr('location_required', category: 'edit_service'),
              description:
                  lang.tr('location_required_desc', category: 'edit_service'),
            ),
          ] else ...[
            const SizedBox(height: 24),
            _buildSelectionConfirmation(
              icon: Icons.check_circle,
              title: lang.tr('location_detected', category: 'edit_service'),
              description: _locationAddress.length > 60
                  ? '${_locationAddress.substring(0, 60)}...'
                  : _locationAddress,
              color: kSuccessGreen,
            ),
          ],
          const SizedBox(height: 24),
          _buildTipCard(
            lang.tr('location_tip', category: 'edit_service'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final lang = Provider.of<LanguageProvider>(context);
    final originalService = widget.serviceData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.preview,
            title: lang.tr('review_title', category: 'edit_service'),
            subtitle: lang.tr('review_subtitle', category: 'edit_service'),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('changes_summary', category: 'edit_service'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kDarkTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonItem(
                    label: lang.tr('service_title', category: 'edit_service'),
                    original: originalService['title'] ??
                        lang.tr('not_set', category: 'edit_service'),
                    updated: _titleController.text.isNotEmpty
                        ? _titleController.text
                        : lang.tr('not_set', category: 'edit_service'),
                    icon: Icons.work,
                    isChanged:
                        originalService['title'] != _titleController.text,
                    lang: lang,
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonItem(
                    label: lang.tr('category', category: 'edit_service'),
                    original: originalService['category'] ??
                        lang.tr('not_selected', category: 'edit_service'),
                    updated: _selectedCategory?.getTranslatedName(lang) ??
                        lang.tr('not_selected', category: 'edit_service'),
                    icon: Icons.category,
                    isChanged:
                        originalService['category'] != _selectedCategory?.name,
                    lang: lang,
                  ),
                  if (_selectedSubcategory != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: _buildComparisonItem(
                        label: lang.tr('subcategory', category: 'edit_service'),
                        original: originalService['subcategory'] ??
                            lang.tr('not_selected', category: 'edit_service'),
                        updated: _selectedSubcategory!.getTranslatedName(lang),
                        icon: Icons.list,
                        isChanged: originalService['subcategory'] !=
                            _selectedSubcategory!.name,
                        lang: lang,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildComparisonItem(
                    label: lang.tr('price', category: 'edit_service'),
                    original: originalService['price'] != null
                        ? lang.trParams('price_with_unit',
                            category: 'edit_service',
                            params: {
                                'price': originalService['price'].toString(),
                                'unit': _getTranslatedPriceUnit(
                                    originalService['priceUnit'] ??
                                        'per service',
                                    lang)
                              })
                        : lang.tr('not_set', category: 'edit_service'),
                    updated: _priceController.text.isNotEmpty
                        ? lang.trParams('price_with_unit',
                            category: 'edit_service',
                            params: {
                                'price': _priceController.text,
                                'unit': _getTranslatedPriceUnit(
                                    _selectedPriceUnit, lang)
                              })
                        : lang.tr('not_set', category: 'edit_service'),
                    icon: Icons.attach_money,
                    isChanged: originalService['price']?.toString() !=
                            _priceController.text ||
                        originalService['priceUnit'] != _selectedPriceUnit,
                    lang: lang,
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonItem(
                    label: lang.tr('location', category: 'edit_service'),
                    original: originalService['location'] ??
                        lang.tr('not_set', category: 'edit_service'),
                    updated: _locationAddress.isNotEmpty
                        ? _locationAddress
                        : lang.tr('not_set', category: 'edit_service'),
                    icon: Icons.location_on,
                    isChanged: originalService['location'] != _locationAddress,
                    lang: lang,
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonItem(
                    label: lang.tr('description', category: 'edit_service'),
                    original: originalService['description'] ??
                        lang.tr('not_set', category: 'edit_service'),
                    updated: _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : lang.tr('not_set', category: 'edit_service'),
                    icon: Icons.description,
                    isChanged: originalService['description'] !=
                        _descriptionController.text,
                    lang: lang,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: kPrimaryBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.tr('review_info', category: 'edit_service'),
                    style: TextStyle(
                      color: kDarkTextColor,
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
        return lang.tr('price_unit_hour', category: 'edit_service');
      case 'per service':
        return lang.tr('price_unit_service', category: 'edit_service');
      case 'per day':
        return lang.tr('price_unit_day', category: 'edit_service');
      case 'per item':
        return lang.tr('price_unit_item', category: 'edit_service');
      case 'per square meter':
        return lang.tr('price_unit_square_meter', category: 'edit_service');
      case 'per session':
        return lang.tr('price_unit_session', category: 'edit_service');
      default:
        return unit;
    }
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: kPrimaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kDarkTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSelectionPrompt({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kLightBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: kMutedTextColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kDarkTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: kMutedTextColor,
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: kDarkTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem({
    required String label,
    required String original,
    required String updated,
    required IconData icon,
    required bool isChanged,
    required LanguageProvider lang,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isChanged ? kPrimaryBlue : kMutedTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kDarkTextColor,
              ),
            ),
            const Spacer(),
            if (isChanged)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lang.tr('changed', category: 'edit_service'),
                  style: TextStyle(
                    fontSize: 10,
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isChanged)
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.trParams('from',
                      category: 'edit_service', params: {'value': original}),
                  style: TextStyle(
                    fontSize: 12,
                    color: kMutedTextColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.trParams('to',
                      category: 'edit_service', params: {'value': updated}),
                  style: const TextStyle(
                    fontSize: 14,
                    color: kDarkTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              original,
              style: TextStyle(
                fontSize: 14,
                color: kDarkTextColor.withOpacity(0.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: kPrimaryBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: kDarkTextColor,
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('help_title', category: 'edit_service')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  lang.tr('help_step1_title', category: 'edit_service'),
                  lang.tr('help_step1_desc', category: 'edit_service'),
                ),
                _buildHelpItem(
                  lang.tr('help_step2_title', category: 'edit_service'),
                  lang.tr('help_step2_desc', category: 'edit_service'),
                ),
                _buildHelpItem(
                  lang.tr('help_step3_title', category: 'edit_service'),
                  lang.tr('help_step3_desc', category: 'edit_service'),
                ),
                _buildHelpItem(
                  lang.tr('help_step4_title', category: 'edit_service'),
                  lang.tr('help_step4_desc', category: 'edit_service'),
                ),
                _buildHelpItem(
                  lang.tr('help_step5_title', category: 'edit_service'),
                  lang.tr('help_step5_desc', category: 'edit_service'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('got_it', category: 'edit_service')),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: kDarkTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: kMutedTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
