import 'package:flutter_map/flutter_map.dart';

class MapUtils {
  static const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static TileLayer get tileLayer => TileLayer(
    urlTemplate: _tileUrl,
    userAgentPackageName: 'com.vcroad.app',
  );

}
