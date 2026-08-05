import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/providers/advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/create_advisory.dart';

class ReviewPage extends StatelessWidget {
  final AdvisoryFormData formData;
  final dynamic responsive;

  const ReviewPage({
    super.key,
    required this.formData,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.scale(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Review Advisory',
            style: TextStyle(
              fontSize: responsive.scaleFont(24),
              fontWeight: FontWeight.bold,
              color: AppColors.primaryAdaptive(context),
            ),
          ),
          SizedBox(height: responsive.scale(8)),
          Text(
            'Review all details before submitting',
            style: TextStyle(
              fontSize: responsive.scaleFont(14),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: responsive.scale(24)),

          // Category Section
          _buildReviewSection(context, 'Advisory Type', Icons.category, Colors.purple, [
            _buildInfoRow(
              context,
              'Type',
              formData.selectedCategory?.title ?? 'Not selected',
            ),
          ]),
          SizedBox(height: responsive.scale(16)),

          // Details Section
          _buildReviewSection(context, 'Details', Icons.description, Colors.blue, [
            _buildInfoRow(context, 'Reason', formData.reason),
            if (formData.contractor != null)
              _buildInfoRow(context, 'Contractor', formData.contractor!),
            if (formData.contractorContact != null)
              _buildInfoRow(context, 'Contact', formData.contractorContact!),
          ]),
          SizedBox(height: responsive.scale(16)),

          // Schedule Section
          _buildReviewSection(context, 'Schedule', Icons.calendar_today, Colors.orange, [
            _buildInfoRow(
              context,
              'Type',
              formData.scheduleType == AdvisoryScheduleType.oneTime
                  ? 'One-Time'
                  : 'Recurring',
            ),
            _buildInfoRow(
              context,
              'Duration',
              '${DateFormat('MMM dd, yyyy').format(formData.startDate)} - '
                  '${DateFormat('MMM dd, yyyy').format(formData.endDate)}',
            ),
            if (formData.scheduleType == AdvisoryScheduleType.recurring) ...[
              _buildInfoRow(context, 'Days', _formatWeekdays(formData.selectedWeekdays)),
              if (formData.recurringStartTime != null &&
                  formData.recurringEndTime != null)
                _buildInfoRow(
                  context,
                  'Time',
                  '${formData.recurringStartTime!.format(context)} - '
                      '${formData.recurringEndTime!.format(context)}',
                ),
            ],
          ]),
          SizedBox(height: responsive.scale(16)),

          // Routes Section
          Consumer<AdvisoryProvider>(
            builder: (context, provider, _) {
              return _buildReviewSection(context, 'Routes', Icons.map, Colors.red, [
                _buildInfoRow(
                  context,
                  'Affected Roads',
                  '${provider.affectedRoads.length} route(s)',
                ),
                _buildInfoRow(
                  context,
                  'Alternate Routes',
                  '${provider.alternateRoutes.length} route(s)',
                ),
                if (provider.detectedBarangay != null)
                  _buildInfoRow(context, 'Barangay', provider.detectedBarangay!),
                if (provider.detectedPlaceName != null)
                  _buildInfoRow(context, 'Place', provider.detectedPlaceName!),
              ]);
            },
          ),
          SizedBox(height: responsive.scale(16)),

          // Image Preview
          // show preview from local file/bytes or existing uploaded URL
          if (formData.imageFile != null ||
              formData.imageBytes != null ||
              formData.imageUrl != null) ...[
            _buildReviewSection(context, 'Image', Icons.image, Colors.green, [
              SizedBox(height: responsive.scale(8)),
              // Responsive image preview that preserves original aspect ratio.
              // On mobile it is compact; on web/large screens it is wider but
              // constrained so it doesn't become excessively tall.
              LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = constraints.maxWidth;
                  final double maxPreviewWidth = responsive.isMobile
                      ? availableWidth
                      : (availableWidth > 900 ? 900 : availableWidth);
                  final double maxPreviewHeight = responsive.isMobile
                      ? 220
                      : 420;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxPreviewWidth,
                        maxHeight: maxPreviewHeight,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Builder(
                            builder: (context) {
                              // Choose source and use BoxFit.contain to preserve aspect ratio.
                              if (formData.imageFile != null) {
                                return Image.file(
                                  formData.imageFile!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              } else if (formData.imageBytes != null) {
                                return Image.memory(
                                  formData.imageBytes!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              } else {
                                return Image.network(
                                  formData.imageUrl!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return SizedBox(
                                      height: maxPreviewHeight * 0.5,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (ctx, err, st) => SizedBox(
                                    height: maxPreviewHeight * 0.5,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ]),
            SizedBox(height: responsive.scale(16)),
          ],

          // Warning banner
          Container(
            padding: EdgeInsets.all(responsive.scale(12)),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: responsive.scale(24),
                ),
                SizedBox(width: responsive.scale(12)),
                Expanded(
                  child: Text(
                    'Once submitted, the advisory will be visible to all users. '
                    'Make sure all information is accurate.',
                    style: TextStyle(
                      fontSize: responsive.scaleFont(13),
                      color: Colors.orange.shade900,
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

  Widget _buildReviewSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(8)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: responsive.scale(20)),
              ),
              SizedBox(width: responsive.scale(12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.scaleFont(16),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scale(12)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: responsive.scale(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: responsive.scale(120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: responsive.scaleFont(13),
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: responsive.scaleFont(13),
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekdays(List<int> days) {
    if (days.isEmpty) return 'None';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => weekdays[d - 1]).join(', ');
  }
}
