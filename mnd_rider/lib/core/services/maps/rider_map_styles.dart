/// Google Maps JSON styles for MND Rider.
class RiderMapStyles {
  RiderMapStyles._();

  /// Soft night style — deep ink canvas, muted roads, quiet POIs.
  static const String dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0f131c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8b93a7"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f131c"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1c2433"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9aa3b8"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#b0b8c9"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757f93"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#151b28"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#132018"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b7f6e"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1c2433"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8b93a7"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#242c3d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2a3348"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#33405a"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#6f788c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#151b28"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#7a8499"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a1628"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a5a78"}]}
]
''';
}
