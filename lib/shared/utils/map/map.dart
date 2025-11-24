class MapUtils {
  /// Static map style to remove POI.
  static const String style = '''
    [
      {
        "featureType": "poi",
        "stylers": [
          { "visibility": "off" }
        ]
      }
    ]
    ''';
}
