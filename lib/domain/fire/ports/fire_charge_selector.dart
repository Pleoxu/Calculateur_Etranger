import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';

abstract class FireChargeSelector {
  const FireChargeSelector();

  String selectCharge({
    required FireRequest request,
    required double distanceTopo,
  });
}
