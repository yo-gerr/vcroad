import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/lesson.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class ReorderLessonsDialog extends StatefulWidget {
  final List<QuizMaterial> lessons;

  const ReorderLessonsDialog({super.key, required this.lessons});

  @override
  State<ReorderLessonsDialog> createState() => _ReorderLessonsDialogState();
}

class _ReorderLessonsDialogState extends State<ReorderLessonsDialog> {
  late List<QuizMaterial> _lessons;

  @override
  void initState() {
    super.initState();
    _lessons = List.from(widget.lessons);
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: info.isDesktop ? 600 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(info.scale(20)),
              child: Row(
                children: [
                  Icon(
                    Icons.reorder,
                    size: info.scale(28),
                    color: const Color(0xFF001278),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: Text(
                      'Reorder Lessons',
                      style: TextStyle(
                        fontSize: info.scaleFont(20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Instructions
            Padding(
              padding: EdgeInsets.all(info.scale(16)),
              child: Text(
                'Drag and drop to reorder lessons. Changes will be saved when you click Save.',
                style: TextStyle(
                  fontSize: info.scaleFont(13),
                  color: Colors.grey[600],
                ),
              ),
            ),

            // Reorderable List
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.symmetric(horizontal: info.scale(16)),
                itemCount: _lessons.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _lessons.removeAt(oldIndex);
                    _lessons.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final lesson = _lessons[index];
                  return Card(
                    key: ValueKey(lesson.id),
                    margin: EdgeInsets.only(bottom: info.scale(8)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF001278),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        lesson.title,
                        style: TextStyle(
                          fontSize: info.scaleFont(14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${lesson.questionCount} questions',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: Icon(
                        Icons.drag_handle,
                        size: info.scale(24),
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: EdgeInsets.all(info.scale(20)),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: info.scaleFont(14)),
                      ),
                    ),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_lessons),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: Text(
                        'Save Order',
                        style: TextStyle(fontSize: info.scaleFont(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
