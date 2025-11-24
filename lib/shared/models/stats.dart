class BarangayUserStat {
  final String barangay;
  final int total;
  final int verified;
  final int unverified;

  const BarangayUserStat({
    required this.barangay,
    required this.total,
    required this.verified,
    required this.unverified,
  });

  BarangayUserStat copyWith({
    String? barangay,
    int? total,
    int? verified,
    int? unverified,
  }) {
    return BarangayUserStat(
      barangay: barangay ?? this.barangay,
      total: total ?? this.total,
      verified: verified ?? this.verified,
      unverified: unverified ?? this.unverified,
    );
  }
}

class BarangayReportStat {
  final String barangay;
  final int total;
  final int verified;
  final int resolved;
  final int flagged;

  const BarangayReportStat({
    required this.barangay,
    required this.total,
    required this.verified,
    required this.resolved,
    required this.flagged,
  });

  int get pending {
    final v = total - (verified + resolved + flagged);
    return v < 0 ? 0 : v;
  }
}
