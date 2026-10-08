import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/ports/fire_charge_selector.dart';
import 'package:calculateur_etranger/utils/charge_utils.dart';

class DefaultFireChargeSelector implements FireChargeSelector {
  const DefaultFireChargeSelector();

  @override
  String selectCharge({
    required FireRequest request,
    required double distanceTopo,
  }) {
    if (request.forcerCharge && request.chargeForcee != null) {
      return 'CH${request.chargeForcee}';
    }

    return choisirChargeEnum(distanceTopo, typeTir: request.typeTir);
  }
}
