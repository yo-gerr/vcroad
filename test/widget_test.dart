// Widget tests for the shared advisory UI (no Firebase required).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/shared/widgets/advisory_status_badge.dart';
import 'package:vcroad/presentation/features/advisories/widgets/advisory_card.dart';
import 'package:vcroad/presentation/features/advisories/widgets/advisory_list_view.dart';

const _mobileResponsive = ResponsiveInfo(
  deviceType: DeviceType.mobile,
  screenWidth: 390,
  screenHeight: 844,
  textScaler: TextScaler.noScaling,
  viewPadding: EdgeInsets.zero,
  viewInsets: EdgeInsets.zero,
  orientation: Orientation.portrait,
);

const _desktopResponsive = ResponsiveInfo(
  deviceType: DeviceType.desktop,
  screenWidth: 1400,
  screenHeight: 900,
  textScaler: TextScaler.noScaling,
  viewPadding: EdgeInsets.zero,
  viewInsets: EdgeInsets.zero,
  orientation: Orientation.landscape,
);

Advisory _sampleAdvisory({
  AdvisoryStatus status = AdvisoryStatus.active,
  bool recurring = false,
  String advisoryId = 'a1',
}) {
  final now = DateTime(2026, 8, 3, 10);
  return Advisory(
    advisoryId: advisoryId,
    advisoryType: 'road_closure',
    reason: 'Bridge closed for repairs until further notice',
    startDate: now,
    endDate: now.add(const Duration(hours: 3)),
    barangay: 'Polo',
    scheduleType: recurring
        ? AdvisoryScheduleType.recurring
        : AdvisoryScheduleType.oneTime,
    weekdays: recurring ? const [DateTime.monday] : null,
    recurringStartTime: recurring ? const TimeOfDay(hour: 8, minute: 0) : null,
    recurringEndTime: recurring ? const TimeOfDay(hour: 17, minute: 0) : null,
    createdAt: now,
    updatedAt: now,
    createdBy: 'admin@test',
    status: status,
    placeName: 'McArthur Highway',
    contractor: 'ACME Corp',
  );
}

void main() {
  group('AdvisoryStatusBadge', () {
    testWidgets('renders the persisted status label and color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvisoryStatusBadge(
              status: AdvisoryStatus.active,
              responsive: _mobileResponsive,
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Active'));
      expect(
        label.style?.color,
        AdvisoryStatusBadge.foreground(AdvisoryStatus.active),
      );
    });

    testWidgets('scheduled badge renders its own label and color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvisoryStatusBadge(
              status: AdvisoryStatus.scheduled,
              responsive: _mobileResponsive,
            ),
          ),
        ),
      );

      expect(find.text('Scheduled'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Scheduled'));
      expect(
        label.style?.color,
        AdvisoryStatusBadge.foreground(AdvisoryStatus.scheduled),
      );
    });
  });

  group('AdvisoryCard', () {
    testWidgets('shows reason, barangay, and status badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdvisoryCard(
                advisory: _sampleAdvisory(),
                responsive: _mobileResponsive,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Bridge closed for repairs'), findsOneWidget);
      expect(find.text('Polo'), findsOneWidget);
      expect(find.text('McArthur Highway'), findsOneWidget);
      expect(find.text('ACME Corp'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('hides admin actions for regular users', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdvisoryCard(
                advisory: _sampleAdvisory(),
                responsive: _mobileResponsive,
                canEdit: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Deactivate'), findsNothing);
    });

    testWidgets('shows admin actions and fires callbacks when editable', (
      WidgetTester tester,
    ) async {
      var deleted = false;
      var edited = false;
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdvisoryCard(
                advisory: _sampleAdvisory(),
                responsive: _mobileResponsive,
                canEdit: true,
                onDelete: () => deleted = true,
                onEdit: () => edited = true,
                onToggleStatus: () => toggled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      expect(deleted, isTrue);

      await tester.tap(find.text('Edit'));
      expect(edited, isTrue);

      await tester.tap(find.text('Deactivate'));
      expect(toggled, isTrue);
    });

    testWidgets('inactive advisories offer an Activate action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdvisoryCard(
                advisory: _sampleAdvisory(status: AdvisoryStatus.inactive),
                responsive: _mobileResponsive,
                canEdit: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
    });

    testWidgets('renders recurring schedule text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdvisoryCard(
                advisory: _sampleAdvisory(recurring: true),
                responsive: _mobileResponsive,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Mon'), findsOneWidget);
    });
  });

  group('AdvisoryListView', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(height: 800, child: child)),
    );

    testWidgets('desktop renders the lazy masonry grid without errors', (
      WidgetTester tester,
    ) async {
      final advisories = List.generate(
        5,
        (i) => _sampleAdvisory(advisoryId: 'a$i'),
      );
      await tester.pumpWidget(
        wrap(
          AdvisoryListView(
            responsive: _desktopResponsive,
            isLoading: false,
            error: null,
            advisories: advisories,
            onShowDetails: (_) {},
            onDelete: (_) {},
            onDownload: (_) {},
            onEdit: (_) {},
            onToggleStatus: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Bridge closed for repairs'), findsWidgets);

      // The masonry grid builds lazily: scroll to the end and confirm the last
      // card still builds on demand without layout errors.
      await tester.scrollUntilVisible(
        find.textContaining('Bridge closed for repairs').last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtered-empty state offers a clear-filters action', (
      WidgetTester tester,
    ) async {
      var cleared = false;
      await tester.pumpWidget(
        wrap(
          AdvisoryListView(
            responsive: _mobileResponsive,
            isLoading: false,
            error: null,
            advisories: const [],
            hasAnyData: true,
            hasActiveFilters: true,
            searchQuery: 'xyz',
            onClearFilters: () => cleared = true,
            onShowDetails: (_) {},
            onDelete: (_) {},
            onDownload: (_) {},
            onEdit: (_) {},
            onToggleStatus: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.textContaining('"xyz"'), findsOneWidget);

      await tester.tap(find.text('Clear search & filters'));
      expect(cleared, isTrue);
    });
  });
}
