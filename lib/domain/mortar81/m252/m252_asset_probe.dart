import 'package:calculateur_etranger/models/calcul_data.dart';

String m252AssetProbe(M252MunitionFamily family) {
  switch (family) {
    case M252MunitionFamily.m821:
    case M252MunitionFamily.m821a1:
    case M252MunitionFamily.m821a2:
      return 'MO81_M252_HE';
    case M252MunitionFamily.m889:
    case M252MunitionFamily.m889a1:
      return 'MO81_M252_HE_M889';
    case M252MunitionFamily.rpM819:
      return 'MO81_M252_RSMK';
    case M252MunitionFamily.tpM879:
      return 'MO81_M252_TP';
    case M252MunitionFamily.illM853a1:
      return 'MO81_M252_ILLUM';
    case M252MunitionFamily.irIllM816:
      return 'MO81_M252_IR_ILLUM';
  }
}
