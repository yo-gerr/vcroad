import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // ✅ added
import 'package:mime/mime.dart'; // ✅ added
import 'dart:ui' as ui; // ✅ added
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/create_advisory.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';

class DetailsPage extends StatefulWidget {
  final AdvisoryFormData formData;
  final dynamic responsive;

  const DetailsPage({
    super.key,
    required this.formData,
    required this.responsive,
  });

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final _reasonController = TextEditingController();
  final _contractorController = TextEditingController();
  final _contractorContactController = TextEditingController();
  final _imagePicker = ImagePicker();

  // store current image aspect ratio for preserving original aspect in preview
  double? _currentImageAspectRatio;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.formData.reason;
    _contractorController.text = widget.formData.contractor ?? '';
    _contractorContactController.text = widget.formData.contractorContact ?? '';

    // Debounced listeners
    _reasonController.addListener(_onReasonChanged);
    _contractorController.addListener(_onContractorChanged);
    _contractorContactController.addListener(_onContactChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reasonController.dispose();
    _contractorController.dispose();
    _contractorContactController.dispose();
    super.dispose();
  }

  void _onReasonChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.formData.reason = _reasonController.text;
      widget.formData.markChanged();
    });
  }

  void _onContractorChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.formData.contractor = _contractorController.text;
      widget.formData.markChanged();
    });
  }

  void _onContactChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.formData.contractorContact = _contractorContactController.text;
      widget.formData.markChanged();
    });
  }

  // Helper: compute aspect ratio (width/height) from bytes using codec
  Future<double?> _getAspectRatioFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      return h == 0 ? null : (w / h);
    } catch (_) {
      return null;
    }
  }

  // Helper: resize bytes using instantiateImageCodec with target dimensions (preserving aspect)
  Future<Uint8List> _resizeBytesIfNeeded(
    Uint8List bytes, {
    int maxWidth = 1280,
    int maxHeight = 1280,
  }) async {
    try {
      // get original dimensions
      final codec0 = await ui.instantiateImageCodec(bytes);
      final frame0 = await codec0.getNextFrame();
      final image0 = frame0.image;
      final origW = image0.width;
      final origH = image0.height;

      if (origW <= maxWidth && origH <= maxHeight) {
        return bytes; // already small enough
      }

      final widthRatio = maxWidth / origW;
      final heightRatio = maxHeight / origH;
      final scale = widthRatio < heightRatio ? widthRatio : heightRatio;
      final targetW = (origW * scale).round();
      final targetH = (origH * scale).round();

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      // If resizing fails, return original
      debugPrint('Image resize failed: $e');
      return bytes;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (picked == null) return;

      // Validate file type and size
      final valid = await _validatePickedImage(picked);
      if (!valid) return;

      // Do async work outside setState, then update state synchronously.
      if (kIsWeb) {
        // read bytes, resize for web to reduce memory and upload size, then compute aspect
        final rawBytes = await picked.readAsBytes();
        final resized = await _resizeBytesIfNeeded(
          rawBytes,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        final aspect = await _getAspectRatioFromBytes(resized);
        setState(() {
          widget.formData.imageBytes = resized;
          widget.formData.imageFile = null;
          widget.formData.imageUrl =
              null; // new local image replaces any existing uploaded url
          _currentImageAspectRatio = aspect;
          widget.formData.markChanged();
        });
      } else {
        final file = File(picked.path);
        // for non-web we've requested maxWidth/maxHeight via picker; still compute aspect for preview
        final bytes = await file.readAsBytes();
        final aspect = await _getAspectRatioFromBytes(bytes);
        setState(() {
          widget.formData.imageFile = file;
          widget.formData.imageBytes = null;
          widget.formData.imageUrl =
              null; // new local image replaces any existing uploaded url
          _currentImageAspectRatio = aspect;
          widget.formData.markChanged();
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  // Validate mime type (jpeg/png) and size (<= 5MB)
  Future<bool> _validatePickedImage(XFile picked) async {
    const maxBytes = 5 * 1024 * 1024; // 5 MB

    try {
      // Get mime type from path or from header bytes
      String? mimeType;
      int size = 0;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        size = bytes.length;
        mimeType = lookupMimeType('', headerBytes: bytes);
      } else {
        final path = picked.path;
        mimeType = lookupMimeType(path);
        final file = File(path);
        if (await file.exists()) {
          size = await file.length();
        } else {
          // fallback to reading bytes
          final bytes = await picked.readAsBytes();
          size = bytes.length;
          mimeType = lookupMimeType('', headerBytes: bytes);
        }
      }

      if (size > maxBytes) {
        if (mounted) {
          SnackbarUtils.showWarning(context, 'Image must be 5MB or smaller.');
        }
        return false;
      }

      if (mimeType == null) {
        // quick fallback: check extension
        final ext = picked.path.split('.').last.toLowerCase();
        if (!(ext == 'jpg' || ext == 'jpeg' || ext == 'png')) {
          if (mounted) {
            SnackbarUtils.showWarning(
              context,
              'Only JPG and PNG images are supported.',
            );
          }
          return false;
        }
        return true;
      }

      if (!(mimeType == 'image/jpeg' || mimeType == 'image/png')) {
        if (mounted) {
          SnackbarUtils.showWarning(
            context,
            'Only JPG and PNG images are supported.',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Unable to validate image: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;

    return ListenableBuilder(
      listenable: widget.formData,
      builder: (context, _) {
        final requiresContractor =
            widget.formData.selectedCategory?.requiresContractor ?? false;

        return SingleChildScrollView(
          padding: EdgeInsets.all(responsive.scale(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Advisory Details',
                style: TextStyle(
                  fontSize: responsive.scaleFont(24),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF001278),
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Provide details and schedule for the advisory',
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: responsive.scale(32)),

              // Reason
              _buildSectionTitle('Reason / Description', responsive, true),
              SizedBox(height: responsive.scale(8)),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Describe the traffic situation in detail...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '${_reasonController.text.length}/500',
                ),
              ),
              SizedBox(height: responsive.scale(24)),

              // Schedule Section
              _buildSectionTitle('Schedule', responsive, true),
              SizedBox(height: responsive.scale(16)),
              _buildScheduleTypeSelector(responsive),
              SizedBox(height: responsive.scale(16)),

              // If one-time: show start/end date+time.
              if (widget.formData.scheduleType ==
                  AdvisoryScheduleType.oneTime) ...[
                _buildDateTimeRangePicker(responsive),
              ] else ...[
                // recurring: show weekdays + time range only
                SizedBox(height: responsive.scale(8)),
                _buildWeekdaySelector(responsive),
                SizedBox(height: responsive.scale(16)),
                _buildTimeRangePicker(responsive),
              ],

              SizedBox(height: responsive.scale(24)),

              // Persisted status control (only visible when editing an existing advisory)
              // Allows persisting "inactive" state; otherwise creation/update logic
              // will persist scheduled/active based on startDate.
              if (widget.formData.advisoryId != null &&
                  widget.formData.advisoryId!.isNotEmpty) ...[
                SwitchListTile.adaptive(
                  value: widget.formData.status == AdvisoryStatus.inactive,
                  onChanged: (v) {
                    setState(() {
                      if (v) {
                        widget.formData.status = AdvisoryStatus.inactive;
                      } else {
                        // When unchecking, prefer active; scheduled will still be chosen
                        // on save if startDate > now (toAdvisory logic).
                        widget.formData.status = AdvisoryStatus.active;
                      }
                      widget.formData.markChanged();
                    });
                  },
                  title: Text(
                    'Persist as inactive',
                    style: TextStyle(
                      fontSize: responsive.scaleFont(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'When enabled this advisory will be saved as inactive. '
                    'Uncheck to restore active (or scheduled if start date is in the future).',
                    style: TextStyle(fontSize: responsive.scaleFont(12)),
                  ),
                ),
                SizedBox(height: responsive.scale(12)),
              ],

              // Contractor Section (conditional)
              if (requiresContractor) ...[
                _buildSectionTitle('Contractor Information', responsive, true),
                SizedBox(height: responsive.scale(16)),
                TextField(
                  controller: _contractorController,
                  decoration: InputDecoration(
                    labelText: 'Contractor Name',
                    hintText: 'Enter contractor company name',
                    prefixIcon: const Icon(Icons.business),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: responsive.scale(12)),
                TextField(
                  controller: _contractorContactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Contact Number',
                    hintText: '09XX XXX XXXX',
                    prefixIcon: const Icon(Icons.phone),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: responsive.scale(24)),
              ],

              // Image Upload Section
              _buildSectionTitle(
                'Advisory Image (Optional)',
                responsive,
                false,
              ),
              SizedBox(height: responsive.scale(12)),
              _buildImagePicker(responsive),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, dynamic responsive, bool required) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: responsive.scaleFont(16),
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        if (required) ...[
          SizedBox(width: responsive.scale(4)),
          Text(
            '*',
            style: TextStyle(
              fontSize: responsive.scaleFont(16),
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleTypeSelector(dynamic responsive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildScheduleOption(
              responsive,
              'One-Time',
              Icons.event,
              AdvisoryScheduleType.oneTime,
            ),
          ),
          Container(width: 1, height: 48, color: Colors.grey.shade300),
          Expanded(
            child: _buildScheduleOption(
              responsive,
              'Recurring',
              Icons.repeat,
              AdvisoryScheduleType.recurring,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleOption(
    dynamic responsive,
    String label,
    IconData icon,
    AdvisoryScheduleType type,
  ) {
    final isSelected = widget.formData.scheduleType == type;
    return InkWell(
      onTap: () {
        widget.formData.scheduleType = type;
        widget.formData.markChanged();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: responsive.scale(12)),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF001278).withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF001278)
                  : Colors.grey.shade600,
              size: responsive.scale(20),
            ),
            SizedBox(width: responsive.scale(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.scaleFont(14),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF001278)
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeRangePicker(dynamic responsive) {
    return Row(
      children: [
        Expanded(
          child: _buildDateTimeField('Start', widget.formData.startDate, (dt) {
            widget.formData.startDate = dt;
            widget.formData.markChanged();
          }, responsive),
        ),
        SizedBox(width: responsive.scale(12)),
        Expanded(
          child: _buildDateTimeField('End', widget.formData.endDate, (dt) {
            widget.formData.endDate = dt;
            widget.formData.markChanged();
          }, responsive),
        ),
      ],
    );
  }

  Widget _buildDateTimeField(
    String label,
    DateTime dateTime,
    Function(DateTime) onChanged,
    dynamic responsive,
  ) {
    final display = DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    return InkWell(
      onTap: () async {
        // pick date first
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: dateTime,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate == null) return;

        if (!mounted) return;

        // then pick time
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(dateTime),
        );
        if (pickedTime == null) return;

        final combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        onChanged(combined);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          display,
          style: TextStyle(fontSize: responsive.scaleFont(14)),
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector(dynamic responsive) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: responsive.scale(8),
      runSpacing: responsive.scale(8),
      children: List.generate(7, (index) {
        final dayNumber = index + 1;
        final isSelected = widget.formData.selectedWeekdays.contains(dayNumber);
        return FilterChip(
          label: Text(weekdays[index]),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                widget.formData.selectedWeekdays.add(dayNumber);
              } else {
                widget.formData.selectedWeekdays.remove(dayNumber);
              }
              widget.formData.markChanged();
            });
          },
          selectedColor: const Color(0xFF001278).withValues(alpha: 0.2),
          checkmarkColor: const Color(0xFF001278),
        );
      }),
    );
  }

  Widget _buildTimeRangePicker(dynamic responsive) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeField(
            'Start Time',
            widget.formData.recurringStartTime,
            (time) {
              widget.formData.recurringStartTime = time;
              widget.formData.markChanged();
            },
            responsive,
          ),
        ),
        SizedBox(width: responsive.scale(12)),
        Expanded(
          child: _buildTimeField('End Time', widget.formData.recurringEndTime, (
            time,
          ) {
            widget.formData.recurringEndTime = time;
            widget.formData.markChanged();
          }, responsive),
        ),
      ],
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay? time,
    Function(TimeOfDay) onChanged,
    dynamic responsive,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time?.format(context) ?? 'Select time',
          style: TextStyle(
            fontSize: responsive.scaleFont(14),
            color: time != null ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(dynamic responsive) {
    // Responsive preview container preserves aspect ratio and caps size on larger screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double maxPreviewWidth = responsive.isMobile
            ? availableWidth
            : (availableWidth > 900 ? 900 : availableWidth);
        final double maxPreviewHeight = responsive.isMobile ? 220 : 420;

        Widget buildPreview(Widget img) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxPreviewWidth,
                maxHeight: maxPreviewHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: img,
                ),
              ),
            ),
          );
        }

        Widget imageWidget;
        if (kIsWeb) {
          if (widget.formData.imageBytes != null) {
            imageWidget = Image.memory(
              widget.formData.imageBytes!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          } else if (widget.formData.imageUrl != null) {
            imageWidget = Image.network(
              widget.formData.imageUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      height: maxPreviewHeight * 0.5,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (ctx, e, st) => SizedBox(
                height: maxPreviewHeight * 0.5,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            );
          } else {
            imageWidget = const SizedBox.shrink();
          }
        } else {
          if (widget.formData.imageFile != null) {
            imageWidget = Image.file(
              widget.formData.imageFile!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          } else if (widget.formData.imageUrl != null) {
            imageWidget = Image.network(
              widget.formData.imageUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      height: maxPreviewHeight * 0.5,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (ctx, e, st) => SizedBox(
                height: maxPreviewHeight * 0.5,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            );
          } else {
            imageWidget = const SizedBox.shrink();
          }
        }

        final hasImage =
            widget.formData.imageBytes != null ||
            widget.formData.imageFile != null ||
            widget.formData.imageUrl != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage) ...[
              // Preserve aspect ratio when available, otherwise let BoxFit.contain manage it.
              if (_currentImageAspectRatio != null)
                AspectRatio(
                  aspectRatio: _currentImageAspectRatio!,
                  child: buildPreview(imageWidget),
                )
              else
                SizedBox(
                  height: maxPreviewHeight,
                  child: buildPreview(imageWidget),
                ),
              SizedBox(height: responsive.scale(8)),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImageFromGallery(),
                    icon: Icon(Icons.photo_library, size: responsive.scale(18)),
                    label: Text(
                      hasImage ? 'Change' : 'Select image (Gallery)',
                      style: TextStyle(fontSize: responsive.scaleFont(14)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.scale(12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (hasImage) ...[
                  SizedBox(width: responsive.scale(8)),
                  SizedBox(
                    width: responsive.scale(48),
                    height: responsive.scale(48),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          widget.formData.imageBytes = null;
                          widget.formData.imageFile = null;
                          widget.formData.imageUrl = null;
                          _currentImageAspectRatio = null;
                          widget.formData.markChanged();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(Icons.delete, size: responsive.scale(20)),
                    ),
                  ),
                ],
              ],
            ),

            if (!hasImage) ...[
              SizedBox(height: responsive.scale(8)),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: responsive.scale(16),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: responsive.scale(8)),
                  Expanded(
                    child: Text(
                      'Accepted: JPG, PNG — recommended max 5MB. Use gallery / file explorer to choose an image.',
                      style: TextStyle(
                        fontSize: responsive.scaleFont(13),
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
