import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/presentation/providers/report.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/dialogs/report.dart';

class ReportHistorySheet extends StatelessWidget {
  const ReportHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final myReports = context.select<ReportProvider, List<ReportData>>(
      (p) => p.myReports,
    );

    return Scaffold(
      appBar: AppBar(
        // Styled back / return button matching Register screen
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
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
        title: Text(
          'My Reports',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(16)),
        ),
        backgroundColor: const Color(0xFF001278),
      ),
      body: myReports.isEmpty
          ? Center(
              child: Text(
                'No reports submitted yet.',
                style: TextStyle(fontSize: info.scaleFont(14)),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(info.scale(16)),
              itemCount: myReports.length,
              separatorBuilder: (_, _) => SizedBox(height: info.scale(12)),
              itemBuilder: (context, i) {
                final r = myReports[i];
                final hasAddress = (r.address).toString().trim().isNotEmpty;

                // Status color mapping (cheap, local, used only for this card)
                Color statusColorFor(String label) {
                  switch ((label).toLowerCase()) {
                    case 'verified':
                      return Colors.green;
                    case 'resolved':
                      return Colors.blue;
                    case 'flagged':
                      return Colors.red;
                    case 'pending':
                    default:
                      return Colors.grey;
                  }
                }

                final statusColor = statusColorFor(r.statusLabel);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ReportDetailsDialog.show(context, r.reportId),
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: info.scale(44),
                            height: info.scale(44),
                            decoration: BoxDecoration(
                              // use a subtle tint based on status for immediate signal
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(info.scale(6)),
                              child: Image.asset(
                                r.category.asset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.report, color: Colors.red),
                              ),
                            ),
                          ),
                          SizedBox(width: info.scale(12)),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.category.label,
                                        style: TextStyle(
                                          fontSize: info.scaleFont(14),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // Status badge
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: info.scale(8),
                                        vertical: info.scale(4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        r.statusLabel,
                                        style: TextStyle(
                                          fontSize: info.scaleFont(11),
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: info.scale(6)),
                                Text(
                                  '${r.barangay} • ${r.timeAgo}',
                                  style: TextStyle(
                                    fontSize: info.scaleFont(12),
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (hasAddress) ...[
                                  SizedBox(height: info.scale(8)),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: info.scale(8),
                                      vertical: info.scale(6),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.place,
                                          size: info.scale(12),
                                          color: Colors.blue.shade700,
                                        ),
                                        SizedBox(width: info.scale(6)),
                                        Expanded(
                                          child: Text(
                                            r.address,
                                            style: TextStyle(
                                              fontSize: info.scaleFont(12),
                                              color: Colors.blue.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                SizedBox(height: info.scale(8)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.thumb_up,
                                      size: info.scale(16),
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: info.scale(6)),
                                    Text(
                                      '${r.confirmCount}',
                                      style: TextStyle(
                                        fontSize: info.scaleFont(12),
                                      ),
                                    ),
                                    SizedBox(width: info.scale(12)),
                                    Icon(
                                      Icons.thumb_down,
                                      size: info.scale(16),
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: info.scale(6)),
                                    Text(
                                      '${r.refuteCount}',
                                      style: TextStyle(
                                        fontSize: info.scaleFont(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
