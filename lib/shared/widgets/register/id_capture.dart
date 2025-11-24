import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/services/permission.dart';
import 'package:vcroad_v2/shared/utils/dialog/image_validation.dart';
import 'package:vcroad_v2/shared/utils/dialog/permission.dart';
import 'package:vcroad_v2/shared/utils/image/preview.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:permission_handler/permission_handler.dart';

class IdCapture extends StatefulWidget {
  final Map<String, dynamic> images; // keys: 'id', 'selfie'
  final ValueChanged<Map<String, dynamic>> onChanged;

  const IdCapture({super.key, required this.images, required this.onChanged});

  @override
  State<IdCapture> createState() => _IdCaptureState();
}

class _IdCaptureState extends State<IdCapture>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickImage(String key) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      // Only request camera (and microphone if video). No need to request storage/photos
      // for a camera capture flow. Skip permission requests on web.
      Map<AppPermission, PermissionStatus> statuses = {};
      if (!kIsWeb) {
        final needed = <AppPermission>{AppPermission.camera};
        // If you ever capture video set: if (video) needed.add(AppPermission.microphone);
        statuses = await PermissionService.instance.guardedRequest(needed);
      } else {
        // On web treat as granted (PermissionService.request would also return granted,
        // but avoid the extra async call).
        statuses = {AppPermission.camera: PermissionStatus.granted};
      }

      if (!PermissionService.instance.allGranted(statuses)) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => PermissionRationaleDialog(
            statuses: statuses,
            onRetry: () {
              Navigator.of(context).pop();
              _pickImage(key);
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

      dynamic imageData;
      XFile? file;
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        imageData = result.files.first.bytes;
        if (imageData == null) return;
      } else {
        file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (file == null) return;
        // Use XFile's API directly (avoids creating a File wrapper).
        imageData = await file.readAsBytes();
      }

      final validation = await ImageService.validateImage(imageData);
      if (validation['valid'] != true) {
        if (!mounted) return;
        final slotLabel = key == 'id' ? 'Front of ID' : 'Selfie with ID';
        showDialog(
          context: context,
          builder: (_) => ImageValidationDialog(
            slotLabel: slotLabel,
            message:
                'Image did not pass validation. Please retake with better lighting.',
            onRetake: () => _pickImage(key),
          ),
        );
        return;
      }

      final updated = Map<String, dynamic>.from(widget.images);
      updated[key] = kIsWeb ? imageData : file?.path;
      if (mounted) widget.onChanged(updated);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => ImageValidationDialog(
            slotLabel: 'Image',
            message: 'Unexpected error. Please retry.',
            onRetake: () => _pickImage(key),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildSlot(
    BuildContext context,
    String label,
    String key,
    dynamic pathOrBytes,
    double maxHeight,
  ) {
    final hasImage = pathOrBytes != null;
    final heroTag = 'id_capture_${key}_${identityHashCode(pathOrBytes)}';

    return GestureDetector(
      onTap: _isProcessing
          ? null
          : () => hasImage
                ? showImagePreviewDialog(context, pathOrBytes)
                : _pickImage(key),
      onLongPress: _isProcessing ? null : () => _pickImage(key),
      child: Semantics(
        label: label,
        hint: hasImage
            ? 'Tap to preview, long press to retake'
            : 'Tap to capture $label',
        button: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 140),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!hasImage)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: context.scale(36),
                            color: Colors.grey,
                          ),
                          SizedBox(height: context.scale(8)),
                          Text(
                            'Capture $label',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: context.scaleFont(13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _ImageWithShimmer(
                      pathOrBytes: pathOrBytes,
                      heroTag: heroTag,
                    ),
                  if (hasImage)
                    Positioned(
                      top: context.scale(8),
                      left: context.scale(8),
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.all(context.scale(6)),
                          iconSize: context.scale(18),
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () => _pickImage(key),
                          tooltip: 'Retake',
                        ),
                      ),
                    ),
                  if (hasImage)
                    Positioned(
                      bottom: context.scale(8),
                      right: context.scale(8),
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.all(context.scale(6)),
                          iconSize: context.scale(20),
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () => showImagePreviewDialog(
                                  context,
                                  pathOrBytes,
                                ),
                          tooltip: 'Preview full screen',
                        ),
                      ),
                    ),
                  if (hasImage)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 36,
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black45, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final idPath = widget.images['id'];
    final selfiePath = widget.images['selfie'];
    final responsive = context.responsive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final availableHeight = constraints.maxHeight;
        final maxSlotHeight = isNarrow
            ? (availableHeight * 0.35).clamp(160.0, 280.0)
            : (availableHeight * 0.5).clamp(180.0, 320.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.horizontalPadding,
            vertical: responsive.verticalPadding * 0.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ID Capture',
                style: TextStyle(
                  fontSize: responsive.scaleFont(16),
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).textTheme.titleLarge?.color ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Please capture your government ID and a selfie holding the ID. Make sure text is readable.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: responsive.scaleFont(13),
                ),
              ),
              SizedBox(height: responsive.scale(12)),
              if (isNarrow) ...[
                _buildSlot(context, 'ID (front)', 'id', idPath, maxSlotHeight),
                SizedBox(height: responsive.scale(12)),
                _buildSlot(
                  context,
                  'Selfie with ID',
                  'selfie',
                  selfiePath,
                  maxSlotHeight,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildSlot(
                        context,
                        'Front of ID',
                        'id',
                        idPath,
                        maxSlotHeight,
                      ),
                    ),
                    SizedBox(width: responsive.scale(12)),
                    Expanded(
                      child: _buildSlot(
                        context,
                        'Selfie with ID',
                        'selfie',
                        selfiePath,
                        maxSlotHeight,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: responsive.scale(12)),
              if (_isProcessing) const LinearProgressIndicator(),
              SizedBox(height: responsive.scale(8)),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        if (_isProcessing) return;
                        final updated = Map<String, dynamic>.from(
                          widget.images,
                        );
                        updated['id'] = null;
                        updated['selfie'] = null;
                        widget.onChanged(updated);
                      },
                      child: Text(
                        'Retake all',
                        style: TextStyle(fontSize: responsive.scaleFont(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Image widget with shimmer loading effect during decode
class _ImageWithShimmer extends StatefulWidget {
  final dynamic pathOrBytes;
  final String heroTag;

  const _ImageWithShimmer({required this.pathOrBytes, required this.heroTag});

  @override
  State<_ImageWithShimmer> createState() => _ImageWithShimmerState();
}

class _ImageWithShimmerState extends State<_ImageWithShimmer> {
  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (400 * dpr).toInt();

    Widget imageWidget;
    if (widget.pathOrBytes is Uint8List) {
      imageWidget = Image.memory(
        widget.pathOrBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          if (frame != null) {
            // No need to setState _isLoading
            return child;
          }
          return _shimmerPlaceholder();
        },
      );
    } else if (widget.pathOrBytes is String) {
      imageWidget = Image.file(
        File(widget.pathOrBytes),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheSize,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          if (frame != null) {
            // No need to setState _isLoading
            return child;
          }
          return _shimmerPlaceholder();
        },
      );
    } else {
      imageWidget = const SizedBox.shrink();
    }

    return Hero(
      tag: widget.heroTag,
      child: RepaintBoundary(child: imageWidget),
    );
  }

  Widget _shimmerPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
