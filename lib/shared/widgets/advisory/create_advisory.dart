import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';
import 'package:vcroad_v2/shared/providers/advisory.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/advisory.dart';
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/widgets/advisory/steps/category_step.dart';
import 'package:vcroad_v2/shared/widgets/advisory/steps/details_step.dart';
import 'package:vcroad_v2/shared/widgets/advisory/steps/map_step.dart';
import 'package:vcroad_v2/shared/widgets/advisory/steps/review_step.dart';

/// Redesigned Create Advisory with optimal performance and UX
class CreateAdvisory extends StatefulWidget {
  final Advisory? existingAdvisory;

  const CreateAdvisory({super.key, this.existingAdvisory});

  @override
  State<CreateAdvisory> createState() => _CreateAdvisoryState();
}

class _CreateAdvisoryState extends State<CreateAdvisory> {
  final _pageController = PageController();
  final _advisoryService = AdvisoryService();
  final _formData = AdvisoryFormData();

  int _currentPage = 0;
  bool _isSubmitting = false;

  // Validation states per page
  final List<bool> _pageValidated = List.filled(4, false);

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _formData.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.existingAdvisory != null) {
      _formData.loadFromAdvisory(widget.existingAdvisory!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AdvisoryProvider>().loadAdvisoryForEditing(
          widget.existingAdvisory!,
        );
      });
      _pageValidated.fillRange(0, _pageValidated.length, true);
    }
  }

  bool get _isEditing => widget.existingAdvisory != null;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    // PopScope API varies across SDK versions. Keep WillPopScope for compatibility
    // and suppress the deprecation warning until you migrate to PopScope.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5FA),
        appBar: _buildAppBar(responsive),
        // Center content and constrain max width on wide screens (web/desktop),
        // following the Lesson page pattern for comfortable reading width.
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Use a generous max width on desktop/web; allow full width on smaller devices.
              maxWidth: responsive.isDesktop ? 1100 : responsive.maxFormWidth,
            ),
            child: SafeArea(child: _buildMobileLayout(responsive)),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic responsive) {
    return AppBar(
      backgroundColor: const Color(0xFF001278),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () async {
          // prevent closing while submitting
          if (_isSubmitting) return;
          final shouldClose = await _onWillPop();
          if (!mounted) return;
          if (shouldClose) Navigator.of(context).pop();
        },
      ),
      title: Column(
        children: [
          Text(
            _isEditing ? 'Edit Advisory' : 'Create Advisory',
            style: TextStyle(
              color: Colors.white,
              fontSize: responsive.scaleFont(18),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!responsive.isDesktop) ...[
            const SizedBox(height: 4),
            Text(
              'Step ${_currentPage + 1} of ${_pages.length}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: responsive.scaleFont(12),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isSubmitting)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Mobile: Full-screen page view with bottom nav
  Widget _buildMobileLayout(dynamic responsive) {
    return Column(
      children: [
        // Progress indicator
        _buildProgressIndicator(responsive),

        // Page content
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: _pages
                .map((p) => p.builder(context, responsive, _formData))
                .toList(),
          ),
        ),

        // Navigation
        _buildNavigation(responsive),
      ],
    );
  }

  Widget _buildProgressIndicator(dynamic responsive) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(24),
        vertical: responsive.scale(16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_pages.length, (i) {
          final isCompleted = i < _currentPage || _pageValidated[i];
          final isCurrent = i == _currentPage;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Circle indicator
                      Container(
                        width: responsive.scale(isCurrent ? 36 : 32),
                        height: responsive.scale(isCurrent ? 36 : 32),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : (isCurrent
                                    ? const Color(0xFF001278)
                                    : Colors.grey.shade300),
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF001278,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: responsive.scale(18),
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: responsive.scaleFont(14),
                                  ),
                                ),
                        ),
                      ),

                      // Label (desktop only)
                      if (responsive.isDesktop) ...[
                        const SizedBox(height: 8),
                        Text(
                          _pages[i].title,
                          style: TextStyle(
                            fontSize: responsive.scaleFont(11),
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent
                                ? const Color(0xFF001278)
                                : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Connector line
                if (i < _pages.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.symmetric(
                        horizontal: responsive.scale(4),
                      ),
                      decoration: BoxDecoration(
                        color: i < _currentPage
                            ? Colors.green
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigation(dynamic responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _previousPage,
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  'Back',
                  style: TextStyle(fontSize: responsive.scaleFont(14)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(14)),
                ),
              ),
            ),
          if (_currentPage > 0) SizedBox(width: responsive.scale(12)),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _nextOrSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentPage == _pages.length - 1
                    ? Colors.green
                    : const Color(0xFF001278),
                padding: EdgeInsets.symmetric(vertical: responsive.scale(14)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _currentPage == _pages.length - 1
                          ? Icons.check_circle
                          : Icons.arrow_forward,
                      color: Colors.white,
                    ),
              label: Text(
                _currentPage == _pages.length - 1
                    ? (_isEditing ? 'Update Advisory' : 'Create Advisory')
                    : 'Continue',
                style: TextStyle(
                  fontSize: responsive.scaleFont(15),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Map preview helper removed. Routes step renders the map inline.

  Future<void> _nextOrSubmit() async {
    // Validate current page
    if (!await _validatePage(_currentPage)) {
      return;
    }

    if (_currentPage < _pages.length - 1) {
      _pageValidated[_currentPage] = true;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _submitAdvisory();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<bool> _validatePage(int page) async {
    switch (page) {
      case 0: // Category
        if (_formData.selectedCategory == null) {
          _showError('Please select an advisory type');
          return false;
        }
        return true;

      case 1: // Details
        if (_formData.reason.trim().length < 10) {
          _showError('Reason must be at least 10 characters');
          return false;
        }
        if (_formData.selectedCategory?.requiresContractor == true) {
          if (_formData.contractor?.trim().isEmpty ?? true) {
            _showError('Contractor name is required');
            return false;
          }
        }
        // Schedule consistency checks (faster UX than waiting for service validation)
        if (_formData.scheduleType == AdvisoryScheduleType.oneTime) {
          if (_formData.startDate.isAfter(_formData.endDate)) {
            _showError('Start date must be before or equal to end date');
            return false;
          }
        } else {
          // recurring
          if (_formData.selectedWeekdays.isEmpty) {
            _showError(
              'Please select at least one weekday for recurring advisories',
            );
            return false;
          }
          if (_formData.recurringStartTime == null ||
              _formData.recurringEndTime == null) {
            _showError(
              'Please select start and end times for recurring advisories',
            );
            return false;
          }
          final int s =
              _formData.recurringStartTime!.hour * 60 +
              _formData.recurringStartTime!.minute;
          final int e =
              _formData.recurringEndTime!.hour * 60 +
              _formData.recurringEndTime!.minute;
          if (s == e) {
            _showError('Recurring end time must be different from start time');
            return false;
          }
          // note: e < s is allowed (wrap-around overnight)
        }
        return true;

      case 2: // Map
        final provider = context.read<AdvisoryProvider>();
        if (provider.affectedRoads.isEmpty) {
          _showError('Please plot at least one affected road');
          return false;
        }
        if (provider.detectedBarangay == null) {
          _showError(
            'Barangay not detected. Ensure routes are within Valenzuela',
          );
          return false;
        }

        // Admin check
        final userProvider = context.read<UserProvider>();
        if (userProvider.isAdmin) {
          final adminBarangay = userProvider.user?.barangay.name;
          if (adminBarangay != null &&
              provider.detectedBarangay != adminBarangay) {
            _showError(
              'You can only create advisories for your barangay: $adminBarangay',
            );
            return false;
          }
        }
        return true;

      case 3: // Review
        return true;

      default:
        return false;
    }
  }

  Future<void> _submitAdvisory() async {
    setState(() => _isSubmitting = true);

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LoadingDialog(
          message: _isEditing ? 'Updating advisory...' : 'Creating advisory...',
        ),
      );

      final provider = context.read<AdvisoryProvider>();
      final userProvider = context.read<UserProvider>();

      // Upload image if user selected a new one, otherwise keep formData.imageUrl (may be existing or null)
      String? imageUrl;
      if (_formData.imageFile != null || _formData.imageBytes != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await _advisoryService.uploadImage(
          file: _formData.imageFile,
          bytes: _formData.imageBytes,
          advisoryId: tempId,
        );
      } else {
        // either existing URL (loaded) or user cleared it -> keep formData.imageUrl (could be null)
        imageUrl = _formData.imageUrl ?? widget.existingAdvisory?.imageUrl;
      }

      final advisory = _formData.toAdvisory(
        advisoryId: widget.existingAdvisory?.advisoryId ?? '',
        provider: provider,
        userProvider: userProvider,
        imageUrl: imageUrl,
      );

      if (_isEditing) {
        await provider.updateAdvisory(advisory);
      } else {
        await provider.createAdvisory(advisory);
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        provider.clearAllPlotting();
        Navigator.of(context).pop(true);

        SnackbarUtils.showSuccess(
          context,
          _isEditing
              ? 'Advisory updated successfully'
              : 'Advisory created successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError('Failed to save: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;

    if (!_formData.hasChanges && _currentPage == 0) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => const ConfirmationDialog(
        title: 'Discard Changes?',
        message: 'All unsaved changes will be lost. Are you sure?',
        confirmText: 'Discard',
        cancelText: 'Cancel',
      ),
    );

    if (confirm == true && mounted) {
      context.read<AdvisoryProvider>().clearAllPlotting();
      return true;
    }

    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarUtils.showError(context, message);
  }

  List<_AdvisoryPage> get _pages => [
    _AdvisoryPage(
      title: 'Type',
      builder: (ctx, resp, data) =>
          CategoryPage(formData: data, responsive: resp),
    ),
    _AdvisoryPage(
      title: 'Details',
      builder: (ctx, resp, data) =>
          DetailsPage(formData: data, responsive: resp),
    ),
    _AdvisoryPage(
      title: 'Routes',
      builder: (ctx, resp, data) => MapPage(formData: data, responsive: resp),
    ),
    _AdvisoryPage(
      title: 'Review',
      builder: (ctx, resp, data) =>
          ReviewPage(formData: data, responsive: resp),
    ),
  ];
}

class _AdvisoryPage {
  final String title;
  final Widget Function(
    BuildContext context,
    dynamic responsive,
    AdvisoryFormData formData,
  )
  builder;

  _AdvisoryPage({required this.title, required this.builder});
}

/// Optimized form data with proper change tracking
class AdvisoryFormData extends ChangeNotifier {
  AdvisoryCategory? selectedCategory;
  String reason = '';
  String? contractor;
  String? contractorContact;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  AdvisoryScheduleType scheduleType = AdvisoryScheduleType.oneTime;
  List<int> selectedWeekdays = [];
  TimeOfDay? recurringStartTime;
  TimeOfDay? recurringEndTime;
  File? imageFile;
  Uint8List? imageBytes; // for web
  String? imageUrl; // existing uploaded image (when editing)
  String? placeName;

  // Preserve original advisory metadata when editing so optimistic-lock works
  String? advisoryId;
  DateTime? createdAt;
  String? createdBy;
  int version = 1;
  AdvisoryStatus? status; // persisted status from existing advisory

  bool hasChanges = false;

  void loadFromAdvisory(Advisory advisory) {
    selectedCategory = AdvisoryCategory.findById(advisory.advisoryType);
    reason = advisory.reason;
    contractor = advisory.contractor;
    contractorContact = advisory.contractorContact;
    startDate = advisory.startDate;
    endDate = advisory.endDate;
    scheduleType = advisory.scheduleType;
    selectedWeekdays = List.from(advisory.weekdays ?? []);
    recurringStartTime = advisory.recurringStartTime;
    recurringEndTime = advisory.recurringEndTime;
    // populate existing imageUrl so UI can preview existing image when editing
    imageUrl = advisory.imageUrl;
    placeName = advisory.placeName;
    // store metadata for updates
    advisoryId = advisory.advisoryId;
    createdAt = advisory.createdAt;
    createdBy = advisory.createdBy;
    version = advisory.version;
    status = advisory.status;
    hasChanges = false;
  }

  Advisory toAdvisory({
    required String advisoryId,
    required AdvisoryProvider provider,
    required UserProvider userProvider,
    String? imageUrl,
  }) {
    final now = DateTime.now();
    // Persisted status logic (improved):
    // 1) If editing and user explicitly kept the advisory as inactive -> preserve it.
    // 2) If startDate is in the future -> scheduled.
    // 3) Else (start <= now):
    //    - oneTime: if endDate < now -> expired, else active.
    //    - recurring: if currently in the recurring window -> active, else scheduled.
    //
    // Note: device local time is used here. The server-side sync job still
    // runs periodic authoritative transitions (scheduled->active, active->expired).
    final AdvisoryStatus finalStatus;

    bool recurringIsActiveNow(DateTime nowLocal) {
      // If no weekdays specified assume always-active recurring
      if (scheduleType != AdvisoryScheduleType.recurring) return false;
      if (selectedWeekdays.isEmpty) return true;

      // DateTime.weekday -> 1 (Mon) .. 7 (Sun)
      final int today = nowLocal.weekday;
      if (!selectedWeekdays.contains(today)) return false;

      if (recurringStartTime == null || recurringEndTime == null) {
        // whole-day recurring on matching weekday
        return true;
      }

      final int nowMinutes = nowLocal.hour * 60 + nowLocal.minute;
      final int startMinutes =
          recurringStartTime!.hour * 60 + recurringStartTime!.minute;
      final int endMinutes =
          recurringEndTime!.hour * 60 + recurringEndTime!.minute;

      if (endMinutes >= startMinutes) {
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
      }
      // wrap-around (e.g., 22:00 -> 02:00)
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }

    // 1) preserve explicit inactive when editing
    if (advisoryId.isNotEmpty && status == AdvisoryStatus.inactive) {
      finalStatus = AdvisoryStatus.inactive;
    }
    // 2) future start -> scheduled
    else if (startDate.isAfter(now)) {
      finalStatus = AdvisoryStatus.scheduled;
    }
    // 3) start <= now -> evaluate schedule type
    else {
      if (scheduleType == AdvisoryScheduleType.oneTime) {
        // expired if end already passed
        finalStatus = endDate.isBefore(now)
            ? AdvisoryStatus.expired
            : AdvisoryStatus.active;
      } else {
        // recurring: active only if currently in the recurring window
        finalStatus = recurringIsActiveNow(now)
            ? AdvisoryStatus.active
            : AdvisoryStatus.scheduled;
      }
    }

    return Advisory(
      advisoryId: advisoryId,
      advisoryType: selectedCategory!.id,
      reason: reason.trim(),
      startDate: startDate,
      endDate: endDate,
      barangay: provider.detectedBarangay!,
      scheduleType: scheduleType,
      weekdays: scheduleType == AdvisoryScheduleType.recurring
          ? selectedWeekdays
          : null,
      recurringStartTime: scheduleType == AdvisoryScheduleType.recurring
          ? recurringStartTime
          : null,
      recurringEndTime: scheduleType == AdvisoryScheduleType.recurring
          ? recurringEndTime
          : null,
      affectedRoads: provider.affectedRoads,
      alternateRoutes: provider.alternateRoutes.isNotEmpty
          ? provider.alternateRoutes
          : null,
      center: provider.currentCenter,
      contractor: selectedCategory?.requiresContractor == true
          ? contractor
          : null,
      contractorContact: selectedCategory?.requiresContractor == true
          ? contractorContact
          : null,
      // Preserve original createdAt/createdBy when editing; otherwise set now/current user
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy ?? userProvider.user?.email ?? 'unknown',
      status: finalStatus,
      imageUrl: imageUrl,
      placeName: placeName ?? provider.detectedPlaceName,
      // Use stored version for update (service will increment). For new advisories default to 1.
      version: version,
    );
  }

  void markChanged() {
    hasChanges = true;
    notifyListeners();
  }
}
