import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:latlong2/latlong.dart';

import 'core/app_controller.dart';
import 'core/app_theme.dart';
import 'core/mock_location_exception.dart';
import 'core/platform_support.dart';
import 'core/validate_location.dart';
import 'l10n/app_localizations.dart';
import 'models/gps_fix.dart';
import 'models/location_model.dart';
import 'services/database_service.dart';
import 'services/geofence_service.dart';
import 'services/location_service.dart';
import 'package:fi_ducia/fiducia_engine/widgets/fiducia_offline_map.dart';

/// Écran « collecteur » : pas de blocs debug (.env, lots chiffrés), libellés simplifiés.
/// Utilisé en `release` / profil ; l’écran technique reste en `debug`.
class CollectHomeScreen extends StatefulWidget {
  const CollectHomeScreen({
    super.key,
    required this.controller,
  });

  final FiduciaAppController controller;

  @override
  State<CollectHomeScreen> createState() => _CollectHomeScreenState();
}

class _CollectHomeScreenState extends State<CollectHomeScreen> {
  final TextEditingController _clientIdController = TextEditingController();

  bool _isBusy = false;
  GpsFix? _currentFix;
  GeofenceDecision? _lastDecision;
  LocationModel? _latestStoredLocation;
  GpsIssue? _lastGpsIssue;
  List<LearningMapPoint> _learningMapPoints = <LearningMapPoint>[];
  LatLng? _mapClientCenter;
  String? _storefrontPhotoPath;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!PlatformSupport.supportsGpsModule) {
      setState(() {
        _lastGpsIssue = GpsIssue.unsupportedPlatform;
      });
      return;
    }

    await _loadLatestStoredLocation();
  }

  Future<void> _loadLatestStoredLocation() async {
    final latest = await DatabaseService.instance.getLatestLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _latestStoredLocation = latest;
    });
  }

  Future<void> _refreshGps() async {
    await _runBusy(() async {
      try {
        final result = await LocationService.instance.getTrustedCurrentPosition(
          requireBackgroundPermission: false,
          context: 'prod_refresh',
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _currentFix = result.fix;
          _lastGpsIssue = result.issue;
        });
      } on MockLocationException catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    });
  }

  Future<void> _validateClient() async {
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clientIdRequiredMessage)),
      );
      return;
    }

    await _runBusy(() async {
      final decision = await validateLocationDetailed(clientId);
      await _loadLatestStoredLocation();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastDecision = decision;
        _currentFix = decision.fix;
        _lastGpsIssue = decision.gpsIssue ?? GpsIssue.none;
      });
      await _loadMapLearning(clientId);
      if (!mounted) {
        return;
      }
      await _maybeShowOutsideJustification(context, decision);
    });
  }

  Future<void> _loadMapLearning(String clientId) async {
    if (!PlatformSupport.supportsGpsModule) {
      return;
    }
    final List<Map<String, Object?>> scans =
        await DatabaseService.instance.getEarliestClientScans(
      clientId,
      limit: GeofenceService.learningScanCount,
    );
    final client = await DatabaseService.instance.getClient(clientId);
    if (!mounted) {
      return;
    }
    final List<LearningMapPoint> points = <LearningMapPoint>[];
    for (int i = 0; i < scans.length; i++) {
      points.add(
        LearningMapPoint(
          position: LatLng(
            (scans[i]['latitude'] as num).toDouble(),
            (scans[i]['longitude'] as num).toDouble(),
          ),
          scanIndex: i + 1,
        ),
      );
    }
    setState(() {
      _learningMapPoints = points;
      _mapClientCenter = client?.centerLat != null && client?.centerLng != null
          ? LatLng(client!.centerLat!, client.centerLng!)
          : null;
      _storefrontPhotoPath = client?.storefrontPhotoPath;
    });
  }

  Future<void> _maybeShowOutsideJustification(
    BuildContext context,
    GeofenceDecision decision,
  ) async {
    if (!context.mounted) {
      return;
    }
    if (decision.status != GeofenceStatus.outside ||
        decision.geofenceAlertLocalId == null) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.outsideJustificationTitle),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(hintText: l10n.outsideJustificationHint),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.outsideJustificationCancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(l10n.outsideJustificationSubmit),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      controller.dispose();
      return;
    }

    if (submitted == true && controller.text.trim().isNotEmpty) {
      await submitOutsideZoneJustification(
        alertLocalId: decision.geofenceAlertLocalId!,
        justification: controller.text,
      );
    }
    controller.dispose();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          PopupMenuButton<Locale>(
            tooltip: l10n.languageMenuTitle,
            icon: const Icon(Icons.language_rounded),
            onSelected: widget.controller.setLocale,
            itemBuilder: (context) => <PopupMenuEntry<Locale>>[
              PopupMenuItem<Locale>(
                value: const Locale('fr'),
                child: Text(l10n.languageFrench),
              ),
              PopupMenuItem<Locale>(
                value: const Locale('en'),
                child: Text(l10n.languageEnglish),
              ),
            ],
          ),
          PopupMenuButton<ThemeMode>(
            tooltip: l10n.themeMenuTitle,
            icon: const Icon(Icons.palette_outlined),
            onSelected: widget.controller.setThemeMode,
            itemBuilder: (context) => <PopupMenuEntry<ThemeMode>>[
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Text(l10n.themeSystem),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Text(l10n.themeLight),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Text(l10n.themeDark),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _buildHeroCard(context, l10n),
            const SizedBox(height: 16),
            if (!PlatformSupport.supportsGpsModule)
              _buildWebFallback(context, l10n)
            else ...<Widget>[
              _buildAccessCard(context, l10n),
              const SizedBox(height: 16),
              _buildOfflineMapCard(context, l10n),
              const SizedBox(height: 16),
              _buildPositionCard(context, l10n),
              const SizedBox(height: 16),
              _buildPassiveCard(context, l10n),
              const SizedBox(height: 16),
              _buildValidationCard(context, l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? const <Color>[Color(0xFF11203A), Color(0xFF0A1322)]
                : const <Color>[Color(0xFFF9FCFF), Color(0xFFE7F5E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/branding/fiducia_logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.appSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFallback(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          l10n.androidOnlyMessage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildOfflineMapCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.mapOfflineTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            FiduciaOfflineMap(
              height: 300,
              // Optional params passed defensively to avoid null-driven map issues.
              currentFix: _currentFix,
              learningMarkers:
                  _learningMapPoints.isNotEmpty ? _learningMapPoints : const <LearningMapPoint>[],
              clientCenter: _mapClientCenter,
              decision: _lastDecision,
              storefrontPhotoPath: _storefrontPhotoPath,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.statusOverviewTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _badgeLine(l10n.gpsStatusTitle, _gpsBadge(l10n, _lastGpsIssue)),
                _badgeLine(l10n.geofenceStatusTitle, _zoneBadge(l10n, _lastDecision)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeLine(
    String label,
    _PillBadge badge,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }

  _PillBadge _gpsBadge(AppLocalizations l10n, GpsIssue? issue) {
    if (issue == null) {
      return _PillBadge(l10n.statusUnknown, const Color(0xFFE7ECF4), FiduciaColors.navy);
    }
    if (issue == GpsIssue.none) {
      return _PillBadge(l10n.statusOk, const Color(0xFFD9F4DE), FiduciaColors.success);
    }
    if (issue == GpsIssue.unsupportedPlatform) {
      return _PillBadge(l10n.statusUnavailable, const Color(0xFFFFE6CC), FiduciaColors.navy);
    }
    if (issue == GpsIssue.lowAccuracy) {
      return _PillBadge(l10n.statusPrecisionWeak, const Color(0xFFFFF0C8), FiduciaColors.warning);
    }
    return _PillBadge(l10n.statusError, const Color(0xFFFBD8D7), FiduciaColors.danger);
  }

  _PillBadge _zoneBadge(AppLocalizations l10n, GeofenceDecision? decision) {
    if (decision != null &&
        decision.status == GeofenceStatus.invalidFix &&
        decision.gpsIssue == GpsIssue.lowAccuracy) {
      return _PillBadge(l10n.statusPrecisionWeak, const Color(0xFFFFF0C8), FiduciaColors.warning);
    }
    final s = decision?.status;
    switch (s) {
      case GeofenceStatus.learning:
        return _PillBadge(l10n.statusLearning, const Color(0xFFFFF0C8), FiduciaColors.warning);
      case GeofenceStatus.inside:
        return _PillBadge(l10n.statusInside, const Color(0xFFD9F4DE), FiduciaColors.success);
      case GeofenceStatus.outside:
        return _PillBadge(l10n.statusOutside, const Color(0xFFFBD8D7), FiduciaColors.danger);
      case GeofenceStatus.invalidFix:
      case GeofenceStatus.error:
        return _PillBadge(l10n.statusError, const Color(0xFFFBD8D7), FiduciaColors.danger);
      case GeofenceStatus.unsupportedPlatform:
        return _PillBadge(l10n.statusUnavailable, const Color(0xFFFFE6CC), FiduciaColors.navy);
      case null:
        return _PillBadge(l10n.statusUnknown, const Color(0xFFE7ECF4), FiduciaColors.navy);
    }
  }

  Widget _buildPositionCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.prodPositionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.latitudeLabel,
              value: _formatCoordinate(context, _currentFix?.latitude),
            ),
            _InfoRow(
              label: l10n.longitudeLabel,
              value: _formatCoordinate(context, _currentFix?.longitude),
            ),
            _InfoRow(
              label: l10n.accuracyLabel,
              value: _currentFix == null
                  ? l10n.notAvailableValue
                  : '${_currentFix!.accuracy.toStringAsFixed(1)} m',
            ),
            _InfoRow(
              label: l10n.gpsTimestampLabel,
              value: _formatTimestamp(context, _currentFix?.timestamp),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isBusy ? null : _refreshGps,
              child: Text(l10n.refreshGpsButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassiveCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.lastPassivePointTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.latitudeLabel,
              value: _formatCoordinate(context, _latestStoredLocation?.latitude),
            ),
            _InfoRow(
              label: l10n.longitudeLabel,
              value: _formatCoordinate(context, _latestStoredLocation?.longitude),
            ),
            _InfoRow(
              label: l10n.accuracyLabel,
              value: _latestStoredLocation == null
                  ? l10n.notAvailableValue
                  : '${_latestStoredLocation!.accuracy.toStringAsFixed(1)} m',
            ),
            _InfoRow(
              label: l10n.gpsTimestampLabel,
              value: _formatTimestamp(context, _latestStoredLocation?.timestamp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.validationTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientIdController,
              decoration: InputDecoration(
                labelText: l10n.clientIdLabel,
                hintText: l10n.clientIdHint,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isBusy ? null : _validateClient,
              child: Text(l10n.validateButton),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.geofenceStatusTitle,
              value: _geofenceStatusText(l10n, _lastDecision),
            ),
            _InfoRow(
              label: l10n.gpsStatusTitle,
              value: _gpsIssueText(l10n, _lastGpsIssue),
            ),
            _InfoRow(
              label: l10n.validationSummaryLabel,
              value: _validationSummaryText(l10n, _lastDecision),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoordinate(BuildContext context, double? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null) {
      return l10n.notAvailableValue;
    }
    return value.toStringAsFixed(6);
  }

  String _formatTimestamp(BuildContext context, DateTime? timestamp) {
    final l10n = AppLocalizations.of(context);
    if (timestamp == null) {
      return l10n.notAvailableValue;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMd(locale).add_Hms().format(timestamp.toLocal());
  }

  String _gpsIssueText(AppLocalizations l10n, GpsIssue? issue) {
    switch (issue) {
      case null:
        return l10n.gpsIssueNoAttempt;
      case GpsIssue.none:
        return l10n.gpsIssueNone;
      case GpsIssue.unsupportedPlatform:
        return l10n.gpsIssueUnsupportedPlatform;
      case GpsIssue.servicesDisabled:
        return l10n.gpsIssueServicesDisabled;
      case GpsIssue.permissionDenied:
        return l10n.gpsIssuePermissionDenied;
      case GpsIssue.permissionDeniedForever:
        return l10n.gpsIssuePermissionDeniedForever;
      case GpsIssue.backgroundPermissionRequired:
        return l10n.gpsIssueBackgroundRequired;
      case GpsIssue.timeout:
        return l10n.gpsIssueTimeout;
      case GpsIssue.lowAccuracy:
        return l10n.gpsIssueLowAccuracy;
      case GpsIssue.mockLocation:
        return l10n.gpsIssueMockLocation;
      case GpsIssue.unknown:
        return l10n.gpsIssueUnknown;
    }
  }

  String _geofenceStatusText(AppLocalizations l10n, GeofenceDecision? decision) {
    if (decision != null &&
        decision.status == GeofenceStatus.invalidFix &&
        decision.gpsIssue == GpsIssue.lowAccuracy) {
      return l10n.geofenceBlockedLowGps;
    }
    switch (decision?.status) {
      case GeofenceStatus.learning:
        return l10n.statusLearning;
      case GeofenceStatus.inside:
        return l10n.statusInside;
      case GeofenceStatus.outside:
        return l10n.statusOutside;
      case GeofenceStatus.invalidFix:
      case GeofenceStatus.error:
        return l10n.statusError;
      case GeofenceStatus.unsupportedPlatform:
        return l10n.statusUnavailable;
      case null:
        return l10n.statusUnknown;
    }
  }

  String _validationSummaryText(
    AppLocalizations l10n,
    GeofenceDecision? decision,
  ) {
    if (decision == null) {
      return l10n.geofenceNoDecision;
    }
    switch (decision.status) {
      case GeofenceStatus.learning:
        return l10n.geofenceLearningProgress(
          decision.scanCount ?? 0,
          GeofenceService.learningScanCount,
        );
      case GeofenceStatus.inside:
      case GeofenceStatus.outside:
        return l10n.geofenceDistanceMessage(
          (decision.distanceMeters ?? 0).toStringAsFixed(1),
          (decision.radiusMeters ?? 0).toStringAsFixed(1),
        );
      case GeofenceStatus.invalidFix:
        return l10n.geofenceInvalidFixMessage(_gpsIssueText(l10n, decision.gpsIssue));
      case GeofenceStatus.unsupportedPlatform:
        return l10n.geofenceUnsupportedMessage;
      case GeofenceStatus.error:
        return l10n.geofenceErrorMessage;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge(this.label, this.backgroundColor, this.foregroundColor);

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
