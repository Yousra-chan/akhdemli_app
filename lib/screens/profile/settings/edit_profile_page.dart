import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_optimizer.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/Services/wilaya_service.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  String? _selectedWilaya;
  String? _selectedCommune;
  String? _photoUrl;
  Map<String, String> _wilayasMap = {};
  Map<String, String> _communesMap = {};

  List<String> _portfolio = [];
  List<CategoryModel> _categories = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _fetchingCategories = false;

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final user = authVM.currentUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _professionController = TextEditingController(text: user?.profession ?? '');
    _descriptionController =
        TextEditingController(text: user?.description ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _portfolio = List.from(user?.portfolio ?? []);
    _photoUrl = user?.photoUrl;

    _selectedWilaya = user?.wilaya;
    _selectedCommune = user?.commune;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    _loadWilayas();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (!(authVM.currentUser?.isProvider ?? false)) return;

    setState(() => _fetchingCategories = true);
    try {
      final categories = await FirebaseService.getCategoriesList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _fetchingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _fetchingCategories = false);
    }
  }

  void _loadWilayas() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    setState(() {
      _wilayasMap = WilayaService.getWilayasLocalizedMap(
          languageProvider.locale.languageCode);
      if (_selectedWilaya != null) {
        _communesMap = WilayaService.getCommunesLocalizedMap(
            _selectedWilaya!, languageProvider.locale.languageCode);
      }
    });
  }

  void _onWilayaChanged(String? newValue) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _selectedWilaya = newValue;
      _selectedCommune = null;
      _communesMap = newValue != null
          ? WilayaService.getCommunesLocalizedMap(
              newValue, languageProvider.locale.languageCode)
          : {};
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedBytes =
          await ImageOptimizer.compressImage(File(image.path));
      final base64Image = base64Encode(compressedBytes);
      setState(() {
        _photoUrl = 'data:image/jpeg;base64,$base64Image';
      });
    } catch (e) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      AppSnackBar.showError(
          context,
          lang.trParams('error_changing_photo',
              category: 'profile', params: {'error': e.toString()}));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPortfolioImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedBytes =
          await ImageOptimizer.compressImage(File(image.path));
      final base64Image = base64Encode(compressedBytes);
      setState(() {
        _portfolio.add('data:image/jpeg;base64,$base64Image');
      });
    } catch (e) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      AppSnackBar.showError(
          context,
          lang.trParams('error_adding_image',
              category: 'profile', params: {'error': e.toString()}));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(LanguageProvider languageProvider) async {
    setState(() => _isLoading = true);

    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);

      if (authVM.currentUser != null) {
        final updatedUser = authVM.currentUser!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          profession: _professionController.text.trim(),
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          wilaya: _selectedWilaya,
          commune: _selectedCommune,
          portfolio: _portfolio,
          photoUrl: _photoUrl,
        );
        await authVM.updateUserProfile(updatedUser);
      }

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('updatePersonalInfo', category: 'profile'),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${languageProvider.tr('error_occurred', category: 'common')}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.currentUser;
    final isProvider = user?.isProvider ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: theme.cardColor,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  languageProvider.tr('editProfile', category: 'profile'),
                  style: const TextStyle(
                      fontFamily: 'Exo2', fontWeight: FontWeight.bold),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildPhotoSection(theme),
                      const SizedBox(height: 32),

                      _buildSectionTitle(
                          languageProvider.tr('general_info', category: 'admin'),
                          theme),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _emailController,
                        label: languageProvider.tr('email', category: 'auth'),
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _nameController,
                        label:
                            languageProvider.tr('full_name', category: 'auth'),
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _phoneController,
                        label: languageProvider.tr('phone_number',
                            category: 'auth'),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionTitle(
                          languageProvider.tr('location', category: 'common'),
                          theme),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        theme: theme,
                        label:
                            languageProvider.tr('wilaya', category: 'search'),
                        value: _selectedWilaya,
                        itemsMap: _wilayasMap,
                        icon: Icons.map_outlined,
                        onChanged: _onWilayaChanged,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        theme: theme,
                        label:
                            languageProvider.tr('commune', category: 'search'),
                        value: _selectedCommune,
                        itemsMap: _communesMap,
                        icon: Icons.location_city_outlined,
                        onChanged: (value) =>
                            setState(() => _selectedCommune = value),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _addressController,
                        label:
                            languageProvider.tr('address', category: 'auth'),
                        icon: Icons.location_on_outlined,
                      ),

                      if (isProvider) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle(
                            languageProvider.tr('professional_profile',
                                category: 'provider_profile'),
                            theme),
                        const SizedBox(height: 16),
                        _buildProfessionDropdown(languageProvider, theme),
                        const SizedBox(height: 16),
                        _buildTextField(
                          theme: theme,
                          controller: _descriptionController,
                          label: languageProvider.tr('about_me',
                              category: 'provider_profile'),
                          icon: Icons.description_outlined,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        _buildPortfolioEditor(languageProvider, theme),
                      ],

                      const SizedBox(height: 48),
                      _buildSaveButton(languageProvider, theme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 12, 94, 153))),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: theme.primaryColor,
        letterSpacing: 1.2,
        fontFamily: 'Exo2',
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.primaryColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? Builder(
                      builder: (context) {
                        final provider =
                            ImageUtils.getImageProvider(_photoUrl!);
                        if (provider == null) {
                          return const Icon(Icons.person, size: 60);
                        }
                        return Image(
                          image: provider,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 60),
                        );
                      },
                    )
                  : const Icon(Icons.person, size: 60),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _changeProfilePhoto,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionDropdown(LanguageProvider lang, ThemeData theme) {
    if (_categories.isEmpty && !_fetchingCategories) {
      return _buildTextField(
        theme: theme,
        controller: _professionController,
        label: lang.tr('profession', category: 'common'),
        icon: Icons.work_outline,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _categories.any((c) => c.name == _professionController.text)
              ? _professionController.text
              : null,
          decoration: InputDecoration(
            labelText: lang.tr('profession', category: 'common'),
            prefixIcon: Icon(Icons.work_outline, color: theme.primaryColor),
            border: InputBorder.none,
            labelStyle: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white38
                    : kMutedTextColor),
          ),
          items: _categories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat.name,
              child: Text(
                cat.getTranslatedName(lang),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _professionController.text = val);
            }
          },
          dropdownColor: theme.cardColor,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required ThemeData theme,
    required String label,
    required String? value,
    required Map<String, String> itemsMap,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value != null && itemsMap.containsKey(value) ? value : null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: theme.primaryColor),
            border: InputBorder.none,
            labelStyle: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white38
                    : kMutedTextColor),
          ),
          items: itemsMap.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: theme.cardColor,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildPortfolioEditor(LanguageProvider lang, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.tr('my_work_portfolio', category: 'provider_profile'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
                fontFamily: 'Exo2',
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addPortfolioImage,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: Text(lang.tr('add', category: 'common')),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: theme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: _portfolio.isEmpty
              ? Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text(
                      lang.tr('no_images', category: 'common'),
                      style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white38
                              : kMutedTextColor,
                          fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _portfolio.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                             showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => ImageViewerDialog(imageUrls: _portfolio, initialIndex: index),
                              );
                          },
                          child: Container(
                            width: 120,
                            margin: const EdgeInsetsDirectional.only(end: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Builder(
                                builder: (context) {
                                  final provider = ImageUtils.getImageProvider(
                                      _portfolio[index]);
                                  if (provider == null) {
                                    return const Icon(Icons.broken_image_outlined);
                                  }
                                  return Image(
                                    image: provider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image_outlined),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 5,
                          end: 17,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _portfolio.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? theme.cardColor : theme.disabledColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (enabled)
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon,
              color: enabled ? theme.primaryColor : theme.disabledColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.white38
                  : kMutedTextColor),
        ),
        style: TextStyle(
          color:
              enabled ? theme.textTheme.bodyLarge?.color : theme.disabledColor,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSaveButton(LanguageProvider lang, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _updateProfile(lang),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
          shadowColor: theme.primaryColor.withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                lang.tr('save', category: 'common'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Exo2',
                ),
              ),
      ),
    );
  }
}
