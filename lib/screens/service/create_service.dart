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

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final List<String> _stepTitles = [
    'Service Details',
    'Category',
    'Pricing',
    'Location',
    'Review'
  ];

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
    // Listen for validation
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
    String message = '';
    switch (_currentStep) {
      case 0:
        message =
            'Please provide a valid title (min 5 chars) and description (min 20 chars)';
        break;
      case 1:
        message = 'Please select a category and subcategory';
        break;
      case 2:
        message = 'Please enter a valid price (greater than 0)';
        break;
      case 3:
        message = 'Please set your service location';
        break;
      case 4:
        message = 'Please complete all required fields before creating service';
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
                    _currentStep == 0 ? 'Cancel' : 'Back',
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
                  ? const Text(
                      'Login Required',
                      style: TextStyle(color: Colors.white),
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
                                  ? 'Create'
                                  : 'Next',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.login, color: kPrimaryBlue),
            SizedBox(width: 12),
            Text('Login Required'),
          ],
        ),
        content: const Text(
          'You need to be logged in to create a service. '
          'Please login or create an account first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // Navigate to login - adjust based on your app
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
            ),
            child: const Text('Go to Login',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitService() async {
    print('=== STARTING SERVICE CREATION ===');

    FocusScope.of(context).unfocus();

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final serviceViewModel =
        Provider.of<ServiceViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      print('❌ No user logged in');
      _showError('Please log in to create a service');
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
      _showError('Please complete all required fields');
      return;
    }

    print('✅ All validations passed!');
    print('  Title: ${_titleController.text}');
    print('  Category: ${_selectedCategory?.name}');
    print('  Subcategory: ${_selectedSubcategory?.name}');
    print('  Price: ${_priceController.text}');
    print('  Location: $_locationAddress');

    try {
      double price;
      try {
        price = double.parse(_priceController.text.trim());
        print('✅ Price parsed: $price');
      } catch (e) {
        print('❌ Price parsing error: $e');
        _showError('Invalid price format. Please check your price.');
        return;
      }

      print('=== Calling createServiceFromData ===');
      final success = await serviceViewModel.createServiceFromData(
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
        images: const [],
      );

      if (success && mounted) {
        print('✅ Service created successfully!');
        _showSuccess('Service created successfully!');

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        print('❌ ServiceViewModel returned false');
        print('Error: ${serviceViewModel.error}');
        _showError(serviceViewModel.error ?? 'Failed to create service');
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION in _submitService:');
      print('  Error: $e');
      print('  Stack trace: $stackTrace');

      if (mounted) {
        String errorMessage;
        if (e.toString().contains('permission') ||
            e.toString().contains('denied')) {
          errorMessage = 'Database permission denied. Please contact support.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage =
              'Error creating service: ${e.toString().split('\n').first}';
        }
        _showError(errorMessage);
      }
    }

    print('=== SERVICE CREATION ENDED ===');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${_currentStep + 1} of ${_stepTitles.length}: ${_stepTitles[_currentStep]}',
              style: TextStyle(
                fontSize: 12,
                color: kMutedTextColor,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          InputField(
            label: 'Service Title',
            hint: 'e.g., Professional House Cleaning',
            controller: _titleController,
            icon: Icons.work_rounded,
            maxLength: 60,
            validator: (value) {
              if (value!.isEmpty) return 'Please enter service title';
              if (value.length < 5)
                return 'Title must be at least 5 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          InputField(
            label: 'Service Description',
            hint: 'Describe your service in detail...',
            controller: _descriptionController,
            icon: Icons.description_rounded,
            maxLines: 5,
            maxLength: 500,
            validator: (value) {
              if (value!.isEmpty) return 'Please enter service description';
              if (value.length < 20)
                return 'Description must be at least 20 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.category,
            title: 'Category & Subcategory',
            subtitle: 'Choose the best fit for your service',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.attach_money,
            title: 'Service Pricing',
            subtitle: 'Set your price in Algerian Dinar (DZD)',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.location_on,
            title: 'Service Location',
            subtitle: 'Set where you provide your service',
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
              title: 'Location Required',
              description: 'Please enable location detection to proceed',
            ),
          ] else ...[
            const SizedBox(height: 24),
            _buildSelectionConfirmation(
              icon: Icons.check_circle,
              title: 'Location Detected',
              description: _locationAddress.length > 60
                  ? '${_locationAddress.substring(0, 60)}...'
                  : _locationAddress,
              color: kSuccessGreen,
            ),
          ],
          const SizedBox(height: 24),
          _buildTipCard(
            'Tip: Accurate location helps local customers find you. '
            'You can adjust your service area in settings later.',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.preview,
            title: 'Review & Create',
            subtitle: 'Review your service details before publishing',
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
                  _buildReviewItem(
                    label: 'Service Title',
                    value: _titleController.text.isNotEmpty
                        ? _titleController.text
                        : 'Not set',
                    icon: Icons.work,
                    isValid: _titleValid,
                  ),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: 'Category',
                    value: _selectedCategory?.name ?? 'Not selected',
                    icon: Icons.category,
                    isValid: _categoryValid,
                  ),
                  if (_selectedSubcategory != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: _buildReviewItem(
                        label: 'Subcategory',
                        value: _selectedSubcategory!.name,
                        icon: Icons.list,
                        isValid: _subcategoryValid,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: 'Price',
                    value: _priceController.text.isNotEmpty
                        ? '${_priceController.text} DZD ($_selectedPriceUnit)'
                        : 'Not set',
                    icon: Icons.attach_money,
                    isValid: _priceValid,
                  ),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    label: 'Location',
                    value: _locationAddress.isNotEmpty
                        ? _locationAddress
                        : 'Not set',
                    icon: Icons.location_on,
                    isValid: _locationValid,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedTags.isNotEmpty) ...[
                    _buildReviewItem(
                      label: 'Features',
                      value: _selectedTags.join(', '),
                      icon: Icons.local_offer,
                      isValid: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildReviewItem(
                    label: 'Description',
                    value: _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : 'Not set',
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
                    'Your service will be reviewed within 24 hours before going live. '
                    'Make sure all information is accurate and complete.',
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

  Widget _buildReviewItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isValid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isValid ? kSuccessGreen : kMutedTextColor,
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
            Icon(
              isValid ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: isValid ? kSuccessGreen : kErrorRed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            value,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Service Help'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  'Step 1: Service Details',
                  'Provide a clear title and detailed description of your service.',
                ),
                _buildHelpItem(
                  'Step 2: Category',
                  'Select the category and subcategory that best matches your service.',
                ),
                _buildHelpItem(
                  'Step 3: Pricing',
                  'Set a competitive price based on your expertise and market rates.',
                ),
                _buildHelpItem(
                  'Step 4: Location',
                  'Enable location services to help local customers find you.',
                ),
                _buildHelpItem(
                  'Step 5: Review',
                  'Review all information before publishing your service.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
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
