import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:calculateur_etranger/services/maps/local_map_service.dart';
import 'package:calculateur_etranger/services/maps/mission_zone_package_service.dart';

import 'package:calculateur_etranger/presentation/fire/pages/carte_position_picker_page.dart';
import 'package:calculateur_etranger/presentation/fire/pages/offline_map_download_page.dart';
import 'package:calculateur_etranger/services/position/utm_converter.dart';

abstract final class TirCompletMapNavigation {
  /// Compatibilité avec le contrôleur existant.
  ///
  /// La notion de "camp" disparaît : cette entrée ouvre désormais le
  /// gestionnaire des zones cartographiques MBTiles installées.
  static Future<String?> chooseCamp({
    required BuildContext context,
    required bool dark,
  }) =>
      chooseOfflineZone(context: context, dark: dark);

  static Future<String?> chooseOfflineZone({
    required BuildContext context,
    required bool dark,
  }) async {
    final service = LocalMapService.instance;
    final zones = await service.installedZones();
    final activeId = await service.activeZoneId();
    final onlineEnabled = await service.isOnlineEnabled();

    if (!context.mounted) return null;

    final textPrimary = dark ? Colors.white : Colors.black87;
    final textSecondary = dark ? Colors.white70 : Colors.black54;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: dark ? const Color(0xFF12141A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Offline zones',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The active map is being used without any network connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      enabled: onlineEnabled,
                      leading: Icon(
                        Icons.download_for_offline_outlined,
                        color: onlineEnabled ? const Color(0xFF5E9F7A) : null,
                      ),
                      title: Text(
                        'Download area',
                        style: TextStyle(
                          color: onlineEnabled ? textPrimary : textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        onlineEnabled
                            ? 'Select an extent and create local MBTiles'
                            : 'Switch to Online mode first',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      onTap: !onlineEnabled
                          ? null
                          : () async {
                              final zoneId =
                                  await Navigator.of(sheetContext).push<String>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OfflineMapDownloadPage(dark: dark),
                                ),
                              );

                              if (!sheetContext.mounted || zoneId == null) {
                                return;
                              }
                              Navigator.of(sheetContext).pop(zoneId);
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        'Import a zone package',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'MBTiles map + DEM elevation • import local / USB',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                          withData: false,
                        );

                        if (result == null || result.files.isEmpty) return;

                        final picked = result.files.single;
                        final lowerName = picked.name.toLowerCase();
                        if (!lowerName.endsWith('.ctzone') &&
                            !lowerName.endsWith('.zip')) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Choose a .ctzone or .zip package.',
                              ),
                            ),
                          );
                          return;
                        }

                        final path = picked.path?.trim() ?? '';
                        if (path.isEmpty) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'The selected file is not accessible locally.',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          final importResult = await MissionZonePackageService
                              .instance
                              .importPackage(sourcePath: path);

                          if (!sheetContext.mounted) return;

                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${importResult.zone.name} installed • '
                                '${importResult.demInstalled} tuile(s) DEM',
                              ),
                            ),
                          );

                          Navigator.of(sheetContext).pop(importResult.zone.id);
                        } catch (e) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text('Package import failed: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_to_drive_outlined),
                      title: Text(
                        'Import an MBTiles zone',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Map only, without DEM elevation data',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                          withData: false,
                        );

                        if (result == null || result.files.isEmpty) return;

                        final picked = result.files.single;
                        if (!picked.name.toLowerCase().endsWith('.mbtiles')) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Choose a .mbtiles file.'),
                            ),
                          );
                          return;
                        }

                        final path = picked.path?.trim() ?? '';
                        if (path.isEmpty) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'The selected MBTiles file is not accessible locally.',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          final zone = await service.importMbTiles(
                            sourcePath: path,
                            displayName: picked.name.replaceAll(
                              RegExp(r'\.mbtiles$', caseSensitive: false),
                              '',
                            ),
                          );

                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop(zone.id);
                        } catch (e) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text('MBTiles import failed: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    if (zones.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No offline zone installed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: zones.length,
                        itemBuilder: (context, index) {
                          final zone = zones[index];
                          final isActive = zone.id == activeId;

                          return ListTile(
                            leading: Icon(
                              isActive
                                  ? Icons.offline_pin_outlined
                                  : Icons.map_outlined,
                            ),
                            title: Text(
                              zone.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              isActive
                                  ? 'Active zone • available offline'
                                  : 'Available offline',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive)
                                  const Icon(Icons.check_circle_outline)
                                else
                                  const Icon(Icons.chevron_right),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Delete this map',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: sheetContext,
                                      builder: (dialogContext) {
                                        return AlertDialog(
                                          title: const Text('Delete the map?'),
                                          content: Text(
                                            'Delete « ${zone.name} » '
                                            'from the app?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirmed != true) return;

                                    try {
                                      await service.removeZone(zone.id);

                                      if (!sheetContext.mounted) return;

                                      final nextActiveId =
                                          await service.activeZoneId();

                                      if (!sheetContext.mounted) return;

                                      Navigator.of(
                                        sheetContext,
                                      ).pop(nextActiveId);
                                    } catch (e) {
                                      if (!sheetContext.mounted) return;

                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Deletion failed: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              await service.setActiveZone(zone.id);
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop(zone.id);
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<PickedMapPoint?> pickPieceDirectrice({
    required BuildContext context,
    required bool dark,
    required String utmZoneLabel,
    LatLonPosition? initial,
    double? initialAltitude,
    String? localMapZoneId,
  }) {
    return Navigator.of(context).push<PickedMapPoint>(
      MaterialPageRoute(
        builder: (_) => CartePositionPickerPage(
          mode: CartePickMode.pieceDirectrice,
          dark: dark,
          initialLatitude: initial?.latitude,
          initialLongitude: initial?.longitude,
          initialAltitude: initialAltitude,
          utmZoneLabel: utmZoneLabel,
          localMapZoneId: localMapZoneId,
        ),
      ),
    );
  }

  static Future<PickedMapPoint?> pickObjectif({
    required BuildContext context,
    required bool dark,
    required String utmZoneLabel,
    required LatLonPosition piece,
    required double pieceX,
    required double pieceY,
    double? pieceAltitude,
    LatLonPosition? initial,
    double? initialAltitude,
    CarteTirApercuBuilder? tirApercuBuilder,
  }) async {
    final localMapZoneId = await LocalMapService.instance.activeZoneId();
    if (!context.mounted) return null;

    return Navigator.of(context).push<PickedMapPoint>(
      MaterialPageRoute(
        builder: (_) => CartePositionPickerPage(
          mode: CartePickMode.objectif,
          dark: dark,
          initialLatitude: initial?.latitude,
          initialLongitude: initial?.longitude,
          initialAltitude: initialAltitude,
          pieceLatitude: piece.latitude,
          pieceLongitude: piece.longitude,
          pieceX: pieceX,
          pieceY: pieceY,
          pieceAltitude: pieceAltitude,
          utmZoneLabel: utmZoneLabel,
          localMapZoneId: localMapZoneId,
          tirApercuBuilder: tirApercuBuilder,
        ),
      ),
    );
  }

  static Future<PickedMapPoint?> pickObserver({
    required BuildContext context,
    required bool dark,
    required String utmZoneLabel,
    LatLonPosition? piece,
    LatLonPosition? observer,
    double? pieceAltitude,
    double? observerAltitude,
  }) async {
    final localMapZoneId = await LocalMapService.instance.activeZoneId();
    if (!context.mounted) return null;

    return Navigator.of(context).push<PickedMapPoint>(
      MaterialPageRoute(
        builder: (_) => CartePositionPickerPage(
          mode: CartePickMode.observateur,
          dark: dark,
          initialLatitude: observer?.latitude,
          initialLongitude: observer?.longitude,
          initialAltitude: observerAltitude,
          pieceLatitude: piece?.latitude,
          pieceLongitude: piece?.longitude,
          pieceAltitude: pieceAltitude,
          observerLatitude: observer?.latitude,
          observerLongitude: observer?.longitude,
          observerAltitude: observerAltitude,
          utmZoneLabel: utmZoneLabel,
          localMapZoneId: localMapZoneId,
        ),
      ),
    );
  }

  static Future<PickedMapPoint?> pickObserverObjectif({
    required BuildContext context,
    required bool dark,
    required String utmZoneLabel,
    required LatLonPosition observer,
    LatLonPosition? piece,
    LatLonPosition? initial,
    double? initialAltitude,
    double? pieceAltitude,
    double? observerAltitude,
  }) async {
    final localMapZoneId = await LocalMapService.instance.activeZoneId();
    if (!context.mounted) return null;

    return Navigator.of(context).push<PickedMapPoint>(
      MaterialPageRoute(
        builder: (_) => CartePositionPickerPage(
          mode: CartePickMode.objectifObservateur,
          dark: dark,
          initialLatitude: initial?.latitude,
          initialLongitude: initial?.longitude,
          initialAltitude: initialAltitude,
          pieceLatitude: piece?.latitude,
          pieceLongitude: piece?.longitude,
          pieceAltitude: pieceAltitude,
          observerLatitude: observer.latitude,
          observerLongitude: observer.longitude,
          observerAltitude: observerAltitude,
          utmZoneLabel: utmZoneLabel,
          localMapZoneId: localMapZoneId,
        ),
      ),
    );
  }
}
