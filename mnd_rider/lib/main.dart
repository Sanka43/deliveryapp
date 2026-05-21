import 'package:mnd_rider/app.dart';
import 'package:mnd_rider/app/bootstrap/rider_app_bootstrap.dart';

Future<void> main() async {
  await bootstrapRiderApp();
  runMndRiderApp();
}
