import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/data/models/advisory.dart';

void main() {
  group('AdvisoryStatus', () {
    test('labels are human readable', () {
      expect(AdvisoryStatus.active.label, 'Active');
      expect(AdvisoryStatus.inactive.label, 'Inactive');
      expect(AdvisoryStatus.expired.label, 'Expired');
      expect(AdvisoryStatus.scheduled.label, 'Scheduled');
    });

    test('colors come from the model (single source of truth)', () {
      expect(AdvisoryStatus.active.color, const Color(0xFF2E7D32));
      expect(AdvisoryStatus.inactive.color, const Color(0xFF757575));
      expect(AdvisoryStatus.expired.color, const Color(0xFF616161));
      expect(AdvisoryStatus.scheduled.color, const Color(0xFFF57C00));
    });
  });

  group('AdvisoryCategory', () {
    test('findById resolves known and unknown ids', () {
      expect(AdvisoryCategory.findById('road_closure')?.title, 'Road Closure');
      expect(AdvisoryCategory.findById('construction')?.requiresContractor, isTrue);
      expect(AdvisoryCategory.findById('does_not_exist'), isNull);
    });

    test('findByTitle resolves by exact title', () {
      expect(AdvisoryCategory.findByTitle('One-Way')?.id, 'one_way');
      expect(AdvisoryCategory.findByTitle('nope'), isNull);
    });

    test('iconFor maps known ids, emergency, and falls back safely', () {
      expect(AdvisoryCategory.iconFor('road_closure'), Icons.block);
      expect(AdvisoryCategory.iconFor('emergency'), Icons.warning);
      expect(AdvisoryCategory.iconFor('unknown_id'), Icons.info);
    });
  });

  group('Advisory.buildSearchKeywords', () {
    Advisory base({
      String barangay = 'Polo',
      String? placeName,
      String reason = 'Major road works in progress',
      String type = 'construction',
      String? contractor = 'ACME Corp',
    }) {
      final now = DateTime.utc(2026, 8, 3, 10);
      return Advisory(
        advisoryId: 'a1',
        advisoryType: type,
        reason: reason,
        startDate: now,
        endDate: now.add(const Duration(hours: 2)),
        barangay: barangay,
        scheduleType: AdvisoryScheduleType.oneTime,
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin@test',
        status: AdvisoryStatus.active,
        placeName: placeName,
        contractor: contractor,
      );
    }

    test('lowercases, trims, and drops empty values', () {
      final keywords = base(placeName: '  McArthur Highway  ').buildSearchKeywords();
      expect(keywords, contains('polo'));
      expect(keywords, contains('mcarthur highway'));
      expect(keywords, contains('major road works in progress'));
      expect(keywords, contains('road work / construction')); // category title
      expect(keywords, contains('acme corp'));
    });

    test('dedupes tokens', () {
      final keywords = base(
        reason: 'polo',
        placeName: 'Polo',
        barangay: 'Polo',
      ).buildSearchKeywords();
      expect(keywords.where((k) => k == 'polo').length, 1);
    });

    test('omits null contractor and unknown category titles', () {
      final keywords = base(contractor: null, type: 'unknown_type')
          .buildSearchKeywords();
      expect(keywords, isNot(contains('acme corp')));
    });
  });

  group('Advisory.computeCenter / computeBounds', () {
    test('computeCenter averages all points', () {
      final polylines = [
        [const LatLng(10.0, 120.0), const LatLng(12.0, 124.0)],
      ];
      final center = Advisory.computeCenter(polylines)!;
      expect(center.latitude, closeTo(11.0, 1e-9));
      expect(center.longitude, closeTo(122.0, 1e-9));
    });

    test('computeCenter returns null for empty input', () {
      expect(Advisory.computeCenter(null), isNull);
      expect(Advisory.computeCenter([]), isNull);
    });

    test('computeBounds finds northeast and southwest', () {
      final bounds = Advisory.computeBounds([
        [const LatLng(10.0, 120.0), const LatLng(12.0, 124.0)],
      ])!;
      expect(bounds.northeast.latitude, closeTo(12.0, 1e-9));
      expect(bounds.northeast.longitude, closeTo(124.0, 1e-9));
      expect(bounds.southwest.latitude, closeTo(10.0, 1e-9));
      expect(bounds.southwest.longitude, closeTo(120.0, 1e-9));
    });

    test('computeBounds returns null for empty input', () {
      expect(Advisory.computeBounds(null), isNull);
      expect(Advisory.computeBounds([]), isNull);
    });
  });

  group('Advisory.computeNextStatusAt', () {
    // The model computes boundaries with local-time `DateTime(...)` constructors,
    // so drive the tests with local wall-clock values for determinism.
    final now = DateTime(2026, 8, 3, 10); // Monday 10:00 local

    test('one-time scheduled with future start returns start', () {
      final start = DateTime(2026, 8, 4, 8);
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.scheduled,
        scheduleType: AdvisoryScheduleType.oneTime,
        startDate: start,
        endDate: DateTime(2026, 8, 4, 18),
        now: now,
      );
      expect(at, start);
    });

    test('one-time scheduled with past start returns null', () {
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.scheduled,
        scheduleType: AdvisoryScheduleType.oneTime,
        startDate: DateTime(2026, 8, 2, 8),
        endDate: DateTime(2026, 8, 2, 18),
        now: now,
      );
      expect(at, isNull);
    });

    test('one-time active returns future end date', () {
      final end = DateTime(2026, 8, 3, 18);
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.active,
        scheduleType: AdvisoryScheduleType.oneTime,
        startDate: DateTime(2026, 8, 3, 6),
        endDate: end,
        now: now,
      );
      expect(at, end);
    });

    test('inactive and expired never auto-transition', () {
      for (final status in [AdvisoryStatus.inactive, AdvisoryStatus.expired]) {
        expect(
          Advisory.computeNextStatusAt(
            status: status,
            scheduleType: AdvisoryScheduleType.oneTime,
            startDate: DateTime(2026, 8, 4),
            endDate: DateTime(2026, 8, 5),
            now: now,
          ),
          isNull,
        );
      }
    });

    test('recurring active uses today window end', () {
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.active,
        scheduleType: AdvisoryScheduleType.recurring,
        startDate: now,
        endDate: now,
        weekdays: const [DateTime.monday],
        recurringStartTime: const TimeOfDay(hour: 8, minute: 0),
        recurringEndTime: const TimeOfDay(hour: 17, minute: 0),
        now: now,
      );
      expect(at, DateTime(2026, 8, 3, 17));
    });

    test('recurring scheduled after today picks next matching weekday', () {
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.scheduled,
        scheduleType: AdvisoryScheduleType.recurring,
        startDate: now,
        endDate: now,
        weekdays: const [DateTime.monday],
        recurringStartTime: const TimeOfDay(hour: 9, minute: 0),
        recurringEndTime: const TimeOfDay(hour: 17, minute: 0),
        now: now,
      );
      // Today's 09:00 already passed; next Monday is 2026-08-10.
      expect(at, DateTime(2026, 8, 10, 9));
    });

    test('recurring window wraps past midnight', () {
      final at = Advisory.computeNextStatusAt(
        status: AdvisoryStatus.active,
        scheduleType: AdvisoryScheduleType.recurring,
        startDate: now,
        endDate: now,
        weekdays: const [DateTime.monday],
        recurringStartTime: const TimeOfDay(hour: 22, minute: 0),
        recurringEndTime: const TimeOfDay(hour: 2, minute: 0),
        now: now,
      );
      expect(at, DateTime(2026, 8, 4, 2));
    });
  });

  group('Advisory JSON round-trip', () {
    Advisory sampleAdvisory() {
      final now = DateTime.utc(2026, 8, 3, 10);
      return Advisory(
        advisoryId: 'a1',
        advisoryType: 'road_closure',
        reason: 'Bridge closed for repairs',
        startDate: now,
        endDate: now.add(const Duration(hours: 3)),
        barangay: 'Polo',
        barangayId: '12',
        scheduleType: AdvisoryScheduleType.oneTime,
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin@test',
        createdByUid: 'uid-1',
        status: AdvisoryStatus.scheduled,
        center: const LatLng(14.7, 120.98),
        boundsNE: const LatLng(14.71, 120.99),
        boundsSW: const LatLng(14.69, 120.97),
        affectedRoads: [
          [const LatLng(14.7, 120.98), const LatLng(14.71, 120.99)],
        ],
        searchKeywords: const ['polo', 'bridge'],
        version: 3,
        nextStatusAt: now.add(const Duration(days: 1)),
        versionHistory: [
          AdvisoryHistory(version: 1, updatedBy: 'a', updatedAt: now),
        ],
      );
    }

    test('toJson emits Firestore-friendly types', () {
      final json = sampleAdvisory().toJson();
      expect(json['startDate'], isA<Timestamp>());
      expect(json['center'], isA<GeoPoint>());
      expect(json['boundsNE'], isA<GeoPoint>());
      expect(json['scheduleType'], 'oneTime');
      expect(json['status'], 'scheduled');
      expect(json['version'], 3);
    });

    test('fromJson reconstructs a document', () {
      final json = sampleAdvisory().toJson();
      final parsed = Advisory.fromJson(json);
      expect(parsed.advisoryId, 'a1');
      expect(parsed.barangayId, '12');
      expect(parsed.status, AdvisoryStatus.scheduled);
      expect(parsed.version, 3);
      expect(parsed.center!.latitude, closeTo(14.7, 1e-9));
      expect(parsed.boundsNE!.longitude, closeTo(120.99, 1e-9));
      expect(parsed.searchKeywords, contains('polo'));
      expect(parsed.nextStatusAt, isNotNull);
      expect(parsed.versionHistory, hasLength(1));
    });

    test('fromJson is tolerant of missing and unknown fields', () {
      final parsed = Advisory.fromJson({
        'reason': 'Legacy doc',
        'scheduleType': 'oneTime',
        'status': 'bogus_status',
        'startDate': '2026-08-03T10:00:00Z',
        'endDate': '2026-08-03T13:00:00Z',
        'createdAt': '2026-08-03T10:00:00Z',
        'updatedAt': '2026-08-03T10:00:00Z',
        'center': {
          '_lat': 14.7,
          '_long': 120.98,
        },
      });
      expect(parsed.reason, 'Legacy doc');
      expect(parsed.status, AdvisoryStatus.active); // fallback
      expect(parsed.advisoryId, ''); // no id present
      expect(parsed.startDate, DateTime.utc(2026, 8, 3, 10));
      expect(parsed.version, 1);
      // Unrecognized center shape is ignored gracefully.
      expect(parsed.center, isNull);
    });
  });

  group('AdvisoryHistory', () {
    test('fromJson handles Timestamp and string timestamps', () {
      final viaString = AdvisoryHistory.fromJson({
        'version': 2,
        'updatedBy': 'b',
        'updatedAt': '2026-08-03T10:00:00Z',
        'changedFields': ['reason'],
      });
      expect(viaString.version, 2);
      expect(viaString.updatedAt, DateTime.utc(2026, 8, 3, 10));
      expect(viaString.changedFields, ['reason']);

      final viaTimestamp = AdvisoryHistory.fromJson({
        'version': 3,
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 4, 12)),
      });
      // Timestamp.toDate() preserves the instant; compare by moment to stay
      // timezone-agnostic.
      expect(
        viaTimestamp.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 8, 4, 12)),
        isTrue,
      );
    });
  });
}
