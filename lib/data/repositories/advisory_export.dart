import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:latlong2/latlong.dart';

class AdvisoryExportService {
  AdvisoryExportService._();
  static final AdvisoryExportService instance = AdvisoryExportService._();

  // Cache decoded template to avoid repeated decode on each export.
  static ui.Image? _cachedTemplateImage;

  /// Generate an advisory image (1200x630 - facebook share / landscape).
  /// Returns a File reference (temp file) with PNG bytes.
  /// Returns a File for non-web. On web use [generateAdvisoryImageBytes].
  Future<File> generateAdvisoryImage(
    Advisory advisory, {
    int width = 1200,
    int height = 630,
  }) async {
    final bytes = await generateAdvisoryImageBytes(
      advisory,
      width: width,
      height: height,
    );

    // On web we cannot write to dart:io filesystem; callers should use generateAdvisoryImageBytes.
    if (kIsWeb) {
      throw UnsupportedError(
        'generateAdvisoryImage returns File only on non-web. Use generateAdvisoryImageBytes on web.',
      );
    }

    // write bytes to temp file (non-web)
    final tmp = Directory.systemTemp;
    final file = File(
      '${tmp.path}/advisory_${advisory.advisoryId}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Generate PNG bytes for an advisory image. Use this on web (kIsWeb).
  Future<Uint8List> generateAdvisoryImageBytes(
    Advisory advisory, {
    // Default to the template/native resolution (1920x1080).
    int width = 1920,
    int height = 1080,
  }) async {
    // Load & cache template background once (assets/images/advisory_template.webp).
    if (_cachedTemplateImage == null) {
      try {
        final bd = await rootBundle.load(
          'assets/images/advisory_template.webp',
        );
        _cachedTemplateImage = await _decodeImageFromList(
          bd.buffer.asUint8List(),
        );
      } catch (_) {
        // If asset missing or decode fails, leave cache null and fallback to color
        _cachedTemplateImage = null;
      }
    }

    // Respect template aspect ratio if available.
    // Treat provided width/height as maximum bounds; compute a size that fits the
    // template aspect ratio within those bounds (contain). This keeps composition
    // consistent with the design of the template while honoring requested resolution.
    const int maxDimension = 3840; // higher cap to support 2x/4k if needed
    int finalWidth = width.clamp(200, maxDimension);
    int finalHeight = height.clamp(120, maxDimension);

    if (_cachedTemplateImage != null) {
      // Use the template's native pixel size exactly to preserve fidelity.
      finalWidth = _cachedTemplateImage!.width.clamp(200, maxDimension);
      finalHeight = _cachedTemplateImage!.height.clamp(120, maxDimension);
      // Debug/log so it's visible during development
      if (kDebugMode) {
        debugPrint('Using template resolution: ${finalWidth}x$finalHeight');
      }
    }
    // If no template was found, we keep the requested bounds above.

    // Compute the map target size/position first so the static map matches it.
    // Ratios tuned to the provided layout (1920x1080 reference):
    // left ≈ 84px, top tuned to sit just below header with a small gap,
    // width ≈ 57–58% of canvas, height ≈ 62%.
    // Move the map a little right and lower it (still left-aligned overall).
    // Adjusted ratios: left moved from ~4.4% to 6% of canvas width,
    // and map lowered by an extra vertical offset (6% of canvas height).
    final double mapLeftPx = finalWidth * 0.06; // keep left position fixed
    // Decrease map width relative to canvas so the right column gains space.
    // Previously 0.58; reduce to 0.50 for a more compact map while preserving layout.
    // Adjust clamps to keep sensible minimum/maximum for various resolutions.
    final double desiredMapW = finalWidth * 0.50;
    final double mapW = desiredMapW.clamp(560.0, finalWidth * 0.64);
    final double mapH = (finalHeight * 0.62).clamp(360.0, finalHeight * 0.76);

    // Raise the map: use a smaller vertical offset and apply an upward nudge.
    // This places the map higher (closer to header) while clamping to canvas bounds.
    final double verticalOffset =
        finalHeight * 0.04; // smaller offset -> higher map
    final double desiredTop = (finalHeight - mapH) / 2.0 + verticalOffset;
    final double minTopGap = finalHeight * 0.06; // allow smaller top gap
    // Upward nudge in pixels (moves map up)
    final double upwardNudge = 24.0;
    final double baseTop = mathMax(desiredTop, minTopGap);
    final double maxTopAllowed = finalHeight - mapH - (finalHeight * 0.05);
    final double mapTopPx = mathMax(
      minTopGap,
      mathMin(baseTop - upwardNudge, maxTopAllowed),
    );

    // Request a static map that matches the target rect so we avoid resampling blur.
    final mapBytes = await _fetchStaticMap(
      advisory,
      width: mapW.round(),
      height: mapH.round(),
    );

    // Decode the returned map image
    final ui.Image mapImage = await _decodeImageFromList(mapBytes);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
    );

    // Draw template background (cover). Fallback to brand color fill if template not available.
    if (_cachedTemplateImage != null) {
      _drawImageCover(
        canvas,
        _cachedTemplateImage!,
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
      );
    } else {
      final bgPaint = Paint()..color = AppColors.primary;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        bgPaint,
      );
    }

    // Layout: left column map under the header, right side for text/details.
    final padding = 28.0;
    final mapRect = Rect.fromLTWH(mapLeftPx, mapTopPx, mapW, mapH);
    // Right column starts a fixed gap after the map to mirror the mock
    final rightGapPx = finalWidth * 0.028; // ~54px at 1920
    final rightX = mapRect.right + rightGapPx;
    final rightW = (finalWidth - rightX - padding).clamp(
      280.0,
      finalWidth.toDouble(),
    );

    // White border around the map: draw a filled white rounded rect as the border
    // then draw the map image inset so the white border shows. Keep border small
    // for a clean visual separation from brand background.
    const double mapBorderWidth = 6.0;
    // Larger corner radius to match the mock card
    final outerRadius = 22.0;
    final borderRRect = RRect.fromRectAndRadius(
      mapRect,
      Radius.circular(outerRadius),
    );
    // Brand-blue border to match template accents
    final borderPaint = Paint()..color = AppColors.primary;
    canvas.drawRRect(borderRRect, borderPaint);

    // Inner rect for the map image (inset by border width)
    final innerRect = mapRect.deflate(mapBorderWidth);
    final innerRadius = mathMax(0.0, outerRadius - mapBorderWidth);
    _drawImageCover(canvas, mapImage, innerRect, radius: innerRadius);

    // Subtle left column frame / shadow (drawn outside the border)
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      // subtle brand-blue stroke for extra definition
      ..color = AppColors.primaryLight
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(mapRect.inflate(2), Radius.circular(outerRadius)),
      framePaint,
    );

    // Legend text under the map
    {
      final legendText =
          '*RED marker is affected route, BLUE marker is alternate route';
      final legendBuilder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textDirection: ui.TextDirection.ltr,
                maxLines: 2,
                fontFamily: 'Poppins',
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                // increased size for better legibility under the map
                fontSize: 18,
                color: Colors.white,
                fontStyle: ui.FontStyle.italic,
                fontWeight: ui.FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            )
            ..addText(legendText);

      final legendP = legendBuilder.build();
      // allow the legend to use the inner map width (inset by border)
      final legendWidth = (mapRect.width - (mapBorderWidth * 2)).clamp(
        120.0,
        rightW,
      );
      legendP.layout(ui.ParagraphConstraints(width: legendWidth));

      // place a small gap below the map; ensure we don't draw beyond bottom padding
      final legendTopCandidate = mapRect.bottom + 8.0;
      final maxLegendTop = finalHeight - padding - legendP.height;
      final drawLegendTop = mathMin(legendTopCandidate, maxLegendTop);
      final legendLeft = mapRect.left + mapBorderWidth;

      // draw legend
      canvas.drawParagraph(legendP, Offset(legendLeft, drawLegendTop));
    }

    // Right column: vertically centered stacked messaging (center-aligned)
    final titleX = rightX;

    // Gather strings (defensive extraction)
    // Resolve advisory category to a friendly label (prefer id -> title).
    final AdvisoryCategory? catById = AdvisoryCategory.findById(
      advisory.advisoryType,
    );
    final AdvisoryCategory? catByTitle = AdvisoryCategory.findByTitle(
      advisory.advisoryType,
    );
    final AdvisoryCategory? resolvedCategory = catById ?? catByTitle;
    final String advType = resolvedCategory?.title ?? advisory.advisoryType;
    // Always render the category title in brand red for visual consistency.
    final ui.Color advTypeColor = AppColors.exportRed;
    final String address =
        advisory.placeName != null && advisory.placeName!.isNotEmpty
        ? advisory.placeName!
        : advisory.barangay;
    String desc = advisory.reason;
    try {
      final dyn = advisory as dynamic;
      final candidate =
          (dyn.description ?? dyn.details ?? dyn.body ?? dyn.note);
      desc = (candidate is String ? candidate : candidate?.toString() ?? '')
          .trim();
    } catch (_) {
      try {
        if (advisory is Map) {
          final map = advisory as Map;
          final candidate =
              map['description'] ??
              map['details'] ??
              map['body'] ??
              map['note'];
          desc = (candidate is String ? candidate : candidate?.toString() ?? '')
              .trim();
        }
      } catch (_) {}
    }

    final when = _formatAdvisorySchedule(advisory);

    // Build centered paragraphs (stacked)
    final lines = <ui.Paragraph>[];
    // small helper to create centered paragraph
    ui.Paragraph cp(
      String txt,
      double size, {
      ui.FontWeight weight = ui.FontWeight.w600,
      ui.Color? color,
    }) {
      return _buildParagraph(
        txt,
        size,
        weight: weight,
        color: color ?? AppColors.primary,
        width: rightW,
        align: TextAlign.center,
      );
    }

    // Uniform size for all right-column text (keeps legend unchanged)
    const double rightTextSize = 40.0;

    lines.add(
      cp(
        'Observe',
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    lines.add(
      cp(
        advType.toUpperCase(),
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: advTypeColor,
      ),
    );
    lines.add(
      cp(
        'at',
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    lines.add(
      cp(
        address,
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: AppColors.exportRed,
      ),
    );

    // Maintain label emphasis via weight/color but keep size uniform.
    lines.add(
      cp(
        'due to',
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    lines.add(
      cp(
        desc,
        rightTextSize,
        weight: ui.FontWeight.w600,
        color: AppColors.exportRed,
      ),
    );
    lines.add(
      cp(
        'from',
        rightTextSize,
        weight: ui.FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    lines.add(
      cp(
        when,
        rightTextSize,
        weight: ui.FontWeight.w600,
        color: AppColors.exportRed,
      ),
    );

    // Compute total stacked height
    double totalH = 0;
    for (final p in lines) {
      totalH += p.height;
    }
    // small gap between lines tuned for visual balance
    final gap = 12.0;
    totalH += gap * (lines.length - 1);

    // Start vertically centered
    double yStart = (finalHeight - totalH) / 2.0;
    double curY = yStart;
    for (int i = 0; i < lines.length; i++) {
      final p = lines[i];
      // center horizontally in right column
      final dx = titleX + (rightW - p.width) / 2.0;
      canvas.drawParagraph(p, Offset(dx, curY));
      curY += p.height + gap;
    }

    // Finish
    final picture = recorder.endRecording();
    final img = await picture.toImage(finalWidth, finalHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return bytes;
  }

  Future<Uint8List> _fetchStaticMap(
    Advisory advisory, {
    required int width,
    required int height,
  }) async {
    // Compute center and zoom from advisory polylines (same logic as before).
    final points = <LatLng>[];

    void addPolylinePoints(List<List<LatLng>>? list) {
      if (list == null) return;
      for (final poly in list) {
        points.addAll(poly);
      }
    }

    addPolylinePoints(advisory.affectedRoads);
    addPolylinePoints(advisory.alternateRoutes);

    double lat = 14.7083, lng = 120.9833;
    int zoom = 14;

    if (points.isNotEmpty) {
      double minLat = points.first.latitude;
      double maxLat = minLat;
      double minLng = points.first.longitude;
      double maxLng = minLng;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final latPad = (maxLat - minLat).abs() * 0.10;
      final lngPad = (maxLng - minLng).abs() * 0.10;
      minLat -= latPad;
      maxLat += latPad;
      minLng -= lngPad;
      maxLng += lngPad;

      lat = (minLat + maxLat) / 2.0;
      lng = (minLng + maxLng) / 2.0;

      final lonSpan = (maxLng - minLng).abs();
      final latSpan = (maxLat - minLat).abs();
      const int maxZoom = 18;
      const int minZoom = 3;
      final paddingPx = (width * 0.08).toInt();
      final availableWidth = (width - paddingPx).clamp(200, width);
      final availableHeight = (height - (paddingPx ~/ 2)).clamp(120, height);

      int chosenZoom = minZoom;
      for (int z = maxZoom; z >= minZoom; z--) {
        final worldPx = 256 * math.pow(2, z);
        final degPerPx = 360 / worldPx;
        final reqPxLon = (lonSpan / degPerPx).abs();
        final reqPxLat = (latSpan / degPerPx).abs();
        if (reqPxLon <= availableWidth && reqPxLat <= availableHeight) {
          chosenZoom = z;
          break;
        }
      }
      zoom = chosenZoom;
    } else {
      final dynamic c = advisory.center;
      if (c != null) {
        try {
          if (c is Map) {
            final Map map = c;
            final maybeLat =
                map['lat'] ?? map['latitude'] ?? map['latitudes'] ?? map['0'];
            final maybeLng =
                map['lng'] ??
                map['lon'] ??
                map['longitude'] ??
                map['long'] ??
                map['1'];
            if (maybeLat is num) lat = maybeLat.toDouble();
            if (maybeLng is num) lng = maybeLng.toDouble();
          } else if (c is LatLng) {
            lat = c.latitude;
            lng = c.longitude;
          } else {
            try {
              final maybeLat = (c as dynamic).latitude ?? (c as dynamic).lat;
              final maybeLng =
                  (c as dynamic).longitude ??
                  (c as dynamic).lng ??
                  (c as dynamic).lon;
              if (maybeLat is num) lat = maybeLat.toDouble();
              if (maybeLng is num) lng = maybeLng.toDouble();
            } catch (_) {}
          }
        } catch (_) {}
      }
    }

    // Render OSM tiles + polylines client-side (replaces Cloud Functions /staticmap).
    return _renderTilesWithPolylines(
      centerLat: lat,
      centerLng: lng,
      zoom: zoom,
      imageWidth: width,
      imageHeight: height,
      affectedRoads: advisory.affectedRoads,
      alternateRoutes: advisory.alternateRoutes,
    );
  }

  /// Render OSM tile map with polylines using Canvas (no server needed).
  Future<Uint8List> _renderTilesWithPolylines({
    required double centerLat,
    required double centerLng,
    required int zoom,
    required int imageWidth,
    required int imageHeight,
    required List<List<LatLng>>? affectedRoads,
    required List<List<LatLng>>? alternateRoutes,
  }) async {
    const tileSize = 256;

    double lonToWorldX(double lon) {
      return (lon + 180) / 360 * tileSize * math.pow(2, zoom);
    }

    double latToWorldY(double lat) {
      final sinLat = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
      return (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) *
          tileSize *
          math.pow(2, zoom);
    }

    final centerX = lonToWorldX(centerLng);
    final centerY = latToWorldY(centerLat);

    final leftPx = centerX - imageWidth / 2.0;
    final topPx = centerY - imageHeight / 2.0;

    final minTileX = (leftPx / tileSize).floor();
    final minTileY = (topPx / tileSize).floor();
    final maxTileX = ((leftPx + imageWidth) / tileSize).ceil() - 1;
    final maxTileY = ((topPx + imageHeight) / tileSize).ceil() - 1;

    // Download all visible tiles in parallel.
    final tileTasks = <Future<Map<int, Uint8List>>>[];
    for (int tx = minTileX; tx <= maxTileX; tx++) {
      tileTasks.add(_downloadTilesColumn(tx, minTileY, maxTileY, zoom));
    }
    final columnResults = await Future.wait(tileTasks);

    // Decode images.
    final tileImages = <int, Map<int, ui.Image>>{};
    int colIdx = 0;
    for (int tx = minTileX; tx <= maxTileX; tx++) {
      tileImages[tx] = {};
      final col = columnResults[colIdx];
      for (final entry in col.entries) {
        final ty = entry.key;
        final bytes = entry.value;
        try {
          tileImages[tx]![ty] = await _decodeImageFromList(bytes);
        } catch (_) {
          // Skip failed tile decode.
        }
      }
      colIdx++;
    }

    // Render tiles + polylines to canvas.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
    );

    for (int tx = minTileX; tx <= maxTileX; tx++) {
      for (int ty = minTileY; ty <= maxTileY; ty++) {
        final img = tileImages[tx]?[ty];
        if (img == null) continue;
        final dx = tx * tileSize - leftPx;
        final dy = ty * tileSize - topPx;
        canvas.drawImage(img, Offset(dx.toDouble(), dy.toDouble()), Paint());
      }
    }

    // Helper: draw a single polyline.
    void drawPolyline(List<LatLng> poly, Color color, double strokeWidth) {
      if (poly.length < 2) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = ui.Path();
      final first = poly.first;
      path.moveTo(
        lonToWorldX(first.longitude) - leftPx,
        latToWorldY(first.latitude) - topPx,
      );
      for (int i = 1; i < poly.length; i++) {
        path.lineTo(
          lonToWorldX(poly[i].longitude) - leftPx,
          latToWorldY(poly[i].latitude) - topPx,
        );
      }
      canvas.drawPath(path, paint);
    }

    // Affected roads: thicker red.
    if (affectedRoads != null) {
      for (final poly in affectedRoads) {
        drawPolyline(poly, AppColors.exportRedLine, 4.0);
      }
    }
    // Alternate routes: blue, slightly thinner.
    if (alternateRoutes != null) {
      for (final poly in alternateRoutes) {
        drawPolyline(poly, AppColors.exportBlue, 3.0);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(imageWidth, imageHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Download a range of tiles in one column in parallel.
  Future<Map<int, Uint8List>> _downloadTilesColumn(
    int tx,
    int minTy,
    int maxTy,
    int zoom,
  ) async {
    final results = <int, Uint8List>{};
    final futures = <Future<void>>[];
    for (int ty = minTy; ty <= maxTy; ty++) {
      futures.add(_downloadSingleTile(tx, ty, zoom, results));
    }
    await Future.wait(futures);
    return results;
  }

  Future<void> _downloadSingleTile(
    int tx,
    int ty,
    int zoom,
    Map<int, Uint8List> results,
  ) async {
    try {
      final url = 'https://tile.openstreetmap.org/$zoom/$tx/$ty.png';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'VCRoad/1.0 (advisory export)'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        results[ty] = response.bodyBytes;
      }
    } catch (_) {
      // Tile download failed — leave missing (background color shows through).
    }
  }

  Future<ui.Image> _decodeImageFromList(Uint8List imgBytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(imgBytes, (result) {
      completer.complete(result);
    });
    return completer.future;
  }

  void _drawImageCover(
    Canvas canvas,
    ui.Image img,
    Rect target, {
    double radius = 0,
  }) {
    final paint = Paint();
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    // compute cover transform
    final scale = mathMax(target.width / src.width, target.height / src.height);
    final w = src.width * scale;
    final h = src.height * scale;
    final dx = target.left - (w - target.width) / 2;
    final dy = target.top - (h - target.height) / 2;
    final dst = Rect.fromLTWH(dx, dy, w, h);
    if (radius > 0) {
      final rrect = RRect.fromRectAndRadius(target, Radius.circular(radius));
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(img, src, dst, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, paint);
    }
  }

  ui.Paragraph _buildParagraph(
    String text,
    double fontSize, {
    ui.FontWeight weight = ui.FontWeight.w400,
    ui.Color color = AppColors.exportNearBlack,
    double width = 400,
    TextAlign align = TextAlign.left,
  }) {
    // Use Poppins for all exported advisory text. Make sure Poppins is added
    // to pubspec.yaml fonts so the engine can resolve it at runtime.
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textDirection: ui.TextDirection.ltr,
              textAlign: align,
              maxLines: 10,
              fontFamily: 'Poppins',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: color,
              fontFamily: 'Poppins',
            ),
          )
          ..addText(text);
    final p = pb.build();
    p.layout(ui.ParagraphConstraints(width: width));
    return p;
  }

  String _formatAdvisorySchedule(Advisory advisory) {
    // One-time: include dates + times. Recurring: weekday(s) + time range.
    if (advisory.scheduleType == AdvisoryScheduleType.oneTime) {
      final start = advisory.startDate.toLocal();
      final end = advisory.endDate.toLocal();
      final dfWithTime = DateFormat('MMM d, yyyy h:mm a');
      // If same calendar day show "MMM d, yyyy h:mm a to h:mm a"
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        final startStr = dfWithTime.format(start);
        final endTimeOnly = DateFormat('h:mm a').format(end);
        return '$startStr to $endTimeOnly';
      }
      // Different days: show full ranges with dates and times
      return '${dfWithTime.format(start)} — ${dfWithTime.format(end)}';
    }

    // Recurring schedules
    if (advisory.scheduleType == AdvisoryScheduleType.recurring &&
        advisory.weekdays != null &&
        advisory.weekdays!.isNotEmpty) {
      const weekdayNames = {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
      };
      final sortedDays = advisory.weekdays!.toSet().toList()..sort();
      final dayLabels = sortedDays
          .map((d) => weekdayNames[d] ?? d.toString())
          .toList();
      final daysStr = dayLabels.join(', ');

      String formatTimeOfDay(TimeOfDay t) {
        final dt = DateTime(2000, 1, 1, t.hour, t.minute);
        return DateFormat('h:mm a').format(dt);
      }

      final hasStart = advisory.recurringStartTime != null;
      final hasEnd = advisory.recurringEndTime != null;
      if (hasStart && hasEnd) {
        final startStr = formatTimeOfDay(advisory.recurringStartTime!);
        final endStr = formatTimeOfDay(advisory.recurringEndTime!);
        return '$daysStr at $startStr to $endStr';
      }
      return daysStr;
    }
    return '';
  }
}

// small helper: use math without importing whole dart:math publicly
double mathMax(double a, double b) => a > b ? a : b;
double mathMin(double a, double b) => a < b ? a : b;
