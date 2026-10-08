import os
import re

def fix_file(filepath, transforms):
    if not os.path.exists(filepath):
        print(f"❌ Introuvable : {filepath}")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    for pattern, replacement in transforms:
        content = re.sub(pattern, replacement, content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Corrigé : {filepath}")
    else:
        print(f"⚠️ Motif non trouvé dans : {filepath}")

# 1. Correction dans tir_complet_controller.dart
# Annule l'appel _usecase(...) si la méthode execute était attendue sous un autre nom
fix_file(
    "lib/presentation/fire/controllers/tir_complet_controller.dart",
    [(r'_usecase\(', '_usecase.call(')]
)

# 2. Masquer le doublon dans balistique_eclairant_service.dart
fix_file(
    "lib/services/balistique_eclairant_service.dart",
    [(
        r"import\s+['\"]package:calculateur_etranger/services/balistique_core_result\.dart['\"]\s*;",
        "import 'package:calculateur_etranger/services/balistique_core_result.dart' hide BalistiqueCoreService;"
    )]
)

print("\nPatches ciblés appliqués.")