import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/location_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/community_api_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _shortDescController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // Form state
  String? _category;
  String? _type;
  double? _centerLat;
  double? _centerLng;
  Position? _currentPosition;
  bool _locationEnabled = true;
  bool _isLocationLoading = false;

  final List<String> _categories = [
    'SPORTS', 'EDUCATION', 'ARTS', 'TECHNOLOGY', 'HEALTH', 'ENVIRONMENT', 'BUSINESS', 'GENERAL',
  ];
  
  final Map<String, String> _categoryLabels = {
    'SPORTS': 'Sports',
    'EDUCATION': 'Education',
    'ARTS': 'Arts',
    'TECHNOLOGY': 'Technology',
    'HEALTH': 'Health',
    'ENVIRONMENT': 'Environment',
    'BUSINESS': 'Business',
    'GENERAL': 'General',
  };

  final List<String> _types = [
    'PUBLIC', 'PRIVATE', 'REGIONAL', 'INTEREST_BASED', 'SKILL_SHARING', 'IMPACT_FOCUSED',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _shortDescController.dispose();
    _locationController.dispose();
    _rulesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({required Widget child, Color color = Colors.white, double radius = 24, bool pressed = false}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: pressed 
          ? [
               BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(0, 0), blurRadius: 0),
            ] 
          : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 10), blurRadius: 20, spreadRadius: -2),
              BoxShadow(color: Colors.white.withValues(alpha: 0.9), offset: const Offset(-5, -5), blurRadius: 10),
            ],
      ),
      child: child,
    );
  }

  // Recessed Input Style
  InputDecoration _buildRecessedDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
      filled: true,
      fillColor: const Color(0xFFEFF2F7), // Slightly darker than bg to look recessed
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(),
                  _buildLocationStep(),
                  _buildSettingsStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
            _build3DNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Create New", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text("Community", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                ],
              ),
              _build3DContainer(
                radius: 14,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _build3DStepper(),
        ],
      ),
    );
  }

  Widget _build3DStepper() {
    return Row(
      children: [
        Text("Step ${_currentStep + 1} of 4", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 1), blurRadius: 1), 
              ],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_currentStep + 1) / _totalSteps,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryMuted]),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), offset: const Offset(0, 2), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Basic Details"),
          const SizedBox(height: 16),
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(controller: _nameController, decoration: _buildRecessedDecoration("Community Name *", icon: Icons.group)),
                  const SizedBox(height: 16),
                  TextField(controller: _shortDescController, decoration: _buildRecessedDecoration("Short Description", icon: Icons.short_text)),
                  const SizedBox(height: 16),
                  TextField(controller: _descriptionController, maxLines: 4, decoration: _buildRecessedDecoration("Full Description *", icon: Icons.description)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Category"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: _categories.map((cat) => _build3DChip(_categoryLabels[cat] ?? cat, _category == cat, () => setState(() => _category = cat))).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Type"),
          const SizedBox(height: 12),
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(border: InputBorder.none),
                hint: const Text("Select Community Type"),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))).toList(),
                onChanged: (val) => setState(() => _type = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Location Center"),
          const Text("This sets the 20km radius for discovery.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _build3DContainer(
            child: Column(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Icon(Icons.map_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_isLocationLoading)
                        const BybataLoadingIndicator(size: BybataLoadingSize.compact)
                      else if (_centerLat != null)
                        Column(
                          children: [
                            TextField(
                              controller: _locationController,
                              readOnly: true,
                              decoration: _buildRecessedDecoration("Location", icon: Icons.location_on),
                            ),
                            const SizedBox(height: 10),
                            Text("Coords: ${_centerLat!.toStringAsFixed(4)}, ${_centerLng!.toStringAsFixed(4)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      else
                        const Text("Location required to proceed.", style: TextStyle(color: Colors.red)),
                      
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text("Refresh Location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Community Rules"),
          const SizedBox(height: 16),
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _rulesController,
                maxLines: 5,
                decoration: _buildRecessedDecoration("Set rules...", icon: Icons.gavel),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Tags"),
          const SizedBox(height: 16),
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _tagsController,
                decoration: _buildRecessedDecoration("e.g. eco, tech, local (comma separated)", icon: Icons.tag),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Review Details"),
          const SizedBox(height: 16),
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildReviewRow("Name", _nameController.text),
                  _buildReviewRow("Category", _category != null ? (_categoryLabels[_category] ?? _category!) : "-"),
                  _buildReviewRow("Type", _type?.replaceAll('_', ' ') ?? "-"),
                  const Divider(height: 30),
                  _buildReviewRow("Location", _locationController.text),
                  if (_centerLat != null) _buildReviewRow("Coords", "${_centerLat!.toStringAsFixed(4)}, ${_centerLng!.toStringAsFixed(4)}"),
                  const Divider(height: 30),
                  _buildReviewRow("Description", _descriptionController.text, isLong: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: InkWell(
                onTap: _previousStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text("Back", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _currentStep == _totalSteps - 1 ? (_isLoading ? null : _submit) : _nextStep,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep == _totalSteps - 1 ? "Create Community" : "Next Step", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE 3D COMPONENTS ---
  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E)));
  }

  Widget _build3DChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected 
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
          border: isSelected ? null : Border.all(color: Colors.grey[200]!),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        ],
      ),
    );
  }

  // --- PRESERVED LOGIC ---

  Future<void> _getCurrentLocation() async {
    if (!_locationEnabled) return;
    setState(() => _isLocationLoading = true);
    try {
      final status =
          await LocationService.instance.ensureForFunction(context);
      final granted = status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _isLocationLoading = false;
          _locationEnabled = false;
        });
        return;
      }
      _currentPosition = await LocationService.instance
          .getCurrentPosition(forceRefresh: true);
      if (_currentPosition == null) {
        if (!mounted) return;
        setState(() {
          _isLocationLoading = false;
          _locationEnabled = false;
        });
        return;
      }
      setState(() { _centerLat = _currentPosition!.latitude; _centerLng = _currentPosition!.longitude; });
      try {
        final placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final locationName = [place.locality, place.administrativeArea].where((e) => e != null && e.isNotEmpty).join(', ');
          setState(() { _locationController.text = locationName.isNotEmpty ? locationName : 'Current Location'; _isLocationLoading = false; });
        }
      } catch (_) {
        setState(() { _locationController.text = 'Current Location'; _isLocationLoading = false; });
      }
    } catch (e) {
      setState(() { _isLocationLoading = false; _locationEnabled = false; });
    }
  }

  void _nextStep() {
    if (_validateCurrentStep() && _currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) { AppToast.error(context, 'Please enter a name'); return false; }
        if (_descriptionController.text.trim().isEmpty) { AppToast.error(context, 'Please enter description'); return false; }
        if (_category == null) { AppToast.error(context, 'Select category'); return false; }
        if (_type == null) { AppToast.error(context, 'Select type'); return false; }
        break;
      case 1:
        if (_centerLat == null || _centerLng == null) { AppToast.error(context, 'Location required'); return false; }
        break;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      final tags = _tagsController.text.trim().isEmpty ? <String>[] : _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final created = await service.createCommunityViaApi(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        shortDescription: _shortDescController.text.trim().isEmpty ? null : _shortDescController.text.trim(),
        category: _category, type: _type,
        centerLatitude: _centerLat!, centerLongitude: _centerLng!,
        imageUrl: null,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        tags: tags.isEmpty ? null : tags,
        rules: _rulesController.text.trim().isEmpty ? null : _rulesController.text.trim(),
      );
      if (!mounted) return;
      AppToast.success(context, 'Community created!');
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}