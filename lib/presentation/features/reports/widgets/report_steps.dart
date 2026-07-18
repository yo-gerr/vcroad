import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/presentation/providers/location.dart';
import 'package:vcroad/presentation/providers/report.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/permission.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/data/repositories/media_picker.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';
import 'package:vcroad/presentation/shared/dialogs/permission.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/reports/widgets/steps/category.dart';
import 'package:vcroad/presentation/features/reports/widgets/steps/media.dart';
import 'package:vcroad/presentation/features/reports/widgets/steps/location.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportStepsScreen extends StatefulWidget {
  const ReportStepsScreen({super.key});

  @override
  State<ReportStepsScreen> createState() => _ReportStepsScreenState();
}

class _ReportStepsScreenState extends State<ReportStepsScreen> {
  int _step = 0;
  ReportCategory? _selectedCategory;
  MediaType? _selectedMediaType;
  dynamic _mediaData; // String (mobile path) or Map {bytes, name} (web)
  // Location is handled by LocationProvider; no local fields needed.

  bool _requestingPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canReport = context.read<UserProvider>().canReport;
      if (canReport) _bootstrapLocation();
    });
  }

  Future<bool> _ensureLocationFlow() async {
    if (_requestingPermissions) return false;
    _requestingPermissions = true;

    final canProceed = await PermissionService.showLocationRationale(context);
    if (!canProceed) {
      _requestingPermissions = false;
      return false;
    }

    final statuses = await PermissionService.instance.requestLocation();
    _requestingPermissions = false;

    final allGranted = PermissionService.instance.allGranted(statuses);

    if (!allGranted && mounted) {
      await showDialog(
        context: context,
        builder: (_) => PermissionRationaleDialog(
          statuses: statuses,
          onRetry: () {
            // Close dialog and restart the location bootstrap flow (uses LocationProvider).
            Navigator.of(context).pop();
            _bootstrapLocation();
          },
          onOpenSettings: () {
            Navigator.of(context).pop();
            openAppSettings();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      );
    }
    return allGranted;
  }

  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationFlow();
    if (!ok) return;
    // Use LocationProvider to start/location flow (keeps single source of truth)
    try {
      if (!mounted) return;
      context.read<LocationProvider>().start();
    } catch (_) {
      // ignore - provider may not implement start(), but other code will trigger it on next step
    }
  }

  Future<void> _pickMedia(MediaType type) async {
    if (kIsWeb) {
      if (type == MediaType.video) {
        SnackbarUtils.showError(
          context,
          'Video capture is only available in the mobile app.',
        );
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const LoadingDialog(message: 'Selecting and validating photo...'),
      );
      try {
        final result = await MediaPickerService.pickImageFromGalleryWeb(
          context,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        if (result != null) {
          setState(() {
            _selectedMediaType = MediaType.photo;
            _mediaData = result;
          });
        } else {
          // Don't show error - user may have cancelled or validation failed
          // (validation shows its own dialog)
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          SnackbarUtils.showError(context, 'Failed: $e');
        }
      }
      return;
    }

    final isVideo = type == MediaType.video;
    final statuses = await PermissionService.instance.requestForCamera(
      video: isVideo,
    );

    if (!PermissionService.instance.allGranted(statuses)) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => PermissionRationaleDialog(
          statuses: statuses,
          onRetry: () {
            Navigator.of(context).pop();
            _pickMedia(type);
          },
          onOpenSettings: () {
            Navigator.of(context).pop();
            openAppSettings();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingDialog(
        message: isVideo
            ? 'Recording and validating video...'
            : 'Capturing and validating photo...',
      ),
    );

    try {
      final path = isVideo
          ? await MediaPickerService.pickVideoFromCamera(context)
          : await MediaPickerService.pickImageFromCamera(context);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (path != null) {
        setState(() {
          _selectedMediaType = type;
          _mediaData = path;
        });
      } else {
        // Don't show error - validation or user cancellation handled in picker
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtils.showError(context, 'Capture failed: $e');
      }
    }
  }

  Future<void> _submitReport() async {
    // Use LocationProvider values (the UI shows provider values) to avoid mismatch
    final locProv = context.read<LocationProvider>();
    final location = locProv.location;
    final address = locProv.address;

    if (_selectedCategory == null ||
        _selectedMediaType == null ||
        _mediaData == null ||
        location == null ||
        address == null) {
      SnackbarUtils.showError(context, 'Please complete all steps.');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final details = userProvider.user;
    if (details == null) {
      SnackbarUtils.showError(context, 'User not logged in.');
      return;
    }

    final brgy = BarangayService().matchFromLatLng(location);
    if (brgy == null) {
      SnackbarUtils.showError(
        context,
        'Unable to determine barangay. Ensure you are in Valenzuela City.',
      );
      return;
    }

    dynamic uploadData = _mediaData;
    if (kIsWeb && _mediaData is Map && _mediaData.containsKey('bytes')) {
      uploadData = _mediaData['bytes'];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Submitting report...'),
    );

    // Let the dialog render before heavy work (avoid UI freeze).
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (!mounted) return;
      final reportProvider = context.read<ReportProvider>();

      await reportProvider.submitReport(
        userId: details.userId,
        firstName: details.firstName,
        middleName: details.middleName,
        lastName: details.lastName,
        suffix: details.suffix,
        email: details.email,
        phoneNumber: details.phoneNumber,
        userIsVerified: userProvider.canReport,
        userIsBanned: false,
        category: _selectedCategory!,
        mediaType: _selectedMediaType!,
        mediaData: uploadData,
        location: location,
        address: address,
        barangay: brgy.name,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      SnackbarUtils.showSuccess(context, 'Report submitted successfully.');

      // reset and close
      if (!mounted) return;
      setState(() {
        _step = 0;
        _selectedCategory = null;
        _selectedMediaType = null;
        _mediaData = null;
      });

      Navigator.of(context).pop(); // close the steps screen
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackbarUtils.showError(context, 'Failed to submit report: $e');
    }
  }

  Widget _buildStepper(ResponsiveInfo info) {
    return Row(
      children: [
        _stepIndicator(0, 'Category', info),
        Expanded(child: Divider(color: _step > 0 ? Colors.green : Colors.grey)),
        _stepIndicator(1, 'Media', info),
        Expanded(child: Divider(color: _step > 1 ? Colors.green : Colors.grey)),
        _stepIndicator(2, 'Location', info),
      ],
    );
  }

  Widget _stepIndicator(int index, String label, ResponsiveInfo info) {
    final isActive = _step == index;
    final isCompleted = _step > index;
    return Column(
      children: [
        CircleAvatar(
          radius: info.scale(20, mobileFactor: 0.8),
          backgroundColor: isCompleted
              ? Colors.green
              : (isActive ? AppColors.primary : Colors.grey),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: info.scaleFont(14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: info.scaleFont(12),
            color: isActive ? AppColors.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(ResponsiveInfo info) {
    switch (_step) {
      case 0:
        return CategoryStep(
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
          onNext: () => setState(() => _step = 1),
        );
      case 1:
        return MediaStep(
          selectedMediaType: _selectedMediaType,
          mediaPath: _mediaData,
          onPickMedia: (type) => _pickMedia(type),
          onRetake: () => setState(() {
            _mediaData = null;
            _selectedMediaType = null;
          }),
          onBack: () => setState(() => _step = 0),
          onNext: () {
            setState(() => _step = 2);
            // start location acquisition
            context.read<LocationProvider>().start();
          },
        );
      case 2:
        final locProv = context.watch<LocationProvider>();
        return LocationStep(
          userLocation: locProv.location,
          address: locProv.address,
          isLocating: locProv.isLocating,
          onRetryLocation: () => locProv.refresh(),
          onBack: () => setState(() => _step = 1),
          onSubmit: _submitReport,
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Report Traffic Issue',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        // semantic back button similar to Register screen for consistent UX
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(info.scale(8)),
            iconSize: info.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: info.scale(24),
              height: info.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: info.scale(24),
              ),
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: info.isDesktop ? 800 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
                vertical: context.verticalPadding * 0.5,
              ),
              child: Column(
                children: [
                  _buildStepper(info),
                  const SizedBox(height: 24),
                  Expanded(child: _buildStepContent(info)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
