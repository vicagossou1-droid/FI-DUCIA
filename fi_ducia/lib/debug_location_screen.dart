import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/app_controller.dart';
import 'core/app_env.dart';
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

class DebugLocationScreen extends StatefulWidget {
  const DebugLocationScreen({
    super.key,
    required this.controller,
  });

  final FiduciaAppController controller;

  @override
  State<DebugLocationScreen> createState() => _DebugLocationScreenState();
}

class _DebugLocationScreenState extends State<DebugLocationScreen> {
  final TextEditingController _clientIdController = TextEditingController();

  bool _isBusy = false;
  PermissionSnapshot? _permissionSnapshot;
  GpsFix? _currentFix;
  GeofenceDecision? _lastDecision;
  LocationModel? _latestStoredLocation;
  GpsIssue? _lastGpsIssue;
  int _pendingSyncBatches = 0;

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
        _permissionSnapshot = const PermissionSnapshot.unsupported();
        _lastGpsIssue = GpsIssue.unsupportedPlatform;
      });
      return;
    }

    await _refreshPermissionSummary();
    await _loadLatestStoredLocation();
    await _loadPendingBatchCount();
  }

  Future<void> _loadPendingBatchCount() async {
    if (!PlatformSupport.supportsGpsModule) {
      return;
    }

    final count = await DatabaseService.instance.countPendingUploadBatches();
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingSyncBatches = count;
    });
  }

  Future<void> _refreshPermissionSummary() async {
    final snapshot = await LocationService.instance.getPermissionSnapshot();
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = snapshot;
    });
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
          context: 'debug_refresh',
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
        SnackBar(
          content: Text(l10n.clientIdRequiredMessage),
        ),
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

      await _maybeShowOutsideJustification(context, decision);
      await _loadPendingBatchCount();
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
            decoration: InputDecoration(
              hintText: l10n.outsideJustificationHint,
            ),
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

  Future<void> _runPassiveCaptureNow() async {
    await _runBusy(() async {
      final success = await LocationService.instance.capturePassiveLocation();
      await _loadLatestStoredLocation();

      if (!mounted) {
        return;
      }

      if (!success && _lastGpsIssue == null) {
        setState(() {
          _lastGpsIssue = GpsIssue.timeout;
        });
      } else {
        setState(() {});
      }
      await _loadPendingBatchCount();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
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
              _buildWebFallbackCard(context, l10n)
            else ...<Widget>[
              _buildStatusOverviewCard(context, l10n),
              const SizedBox(height: 16),
              _buildCurrentFixCard(context, l10n),
              const SizedBox(height: 16),
              _buildValidationCard(context, l10n),
              const SizedBox(height: 16),
              _buildLatestPassivePointCard(context, l10n),
              const SizedBox(height: 16),
              _buildSyncBatchCard(context, l10n),
            ],
            const SizedBox(height: 16),
            _buildEnvironmentCard(context, l10n),
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

  Widget _buildWebFallbackCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StatusBadge(
              label: l10n.statusUnavailable,
              backgroundColor: const Color(0xFFFFE6CC),
              foregroundColor: FiduciaColors.navy,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.androidOnlyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.androidOnlyDetails,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverviewCard(BuildContext context, AppLocalizations l10n) {
    final permissionSnapshot =
        _permissionSnapshot ?? const PermissionSnapshot.unsupported();

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
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _buildBadgeLine(
                  label: l10n.gpsStatusTitle,
                  badge: _statusBadgeForGpsIssue(l10n, _lastGpsIssue),
                ),
                _buildBadgeLine(
                  label: l10n.geofenceStatusTitle,
                  badge: _statusBadgeForGeofence(l10n, _lastDecision),
                ),
                _buildBadgeLine(
                  label: l10n.permissionsStatusTitle,
                  badge: _statusBadgeForPermission(l10n, permissionSnapshot),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.platformLabel,
              value: l10n.platformAndroid,
            ),
            _InfoRow(
              label: l10n.permissionDetailsLabel,
              value: _permissionSummaryText(l10n, permissionSnapshot),
            ),
            const SizedBox(height: 16),
            Text(
              'Permissions are handled by the OS/packages (no manual UI action).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentFixCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.currentLocationTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.latitudeLabel,
              value: _formatCoordinate(_currentFix?.latitude),
            ),
            _InfoRow(
              label: l10n.longitudeLabel,
              value: _formatCoordinate(_currentFix?.longitude),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _isBusy ? null : _refreshGps,
                  child: Text(l10n.refreshGpsButton),
                ),
                OutlinedButton(
                  onPressed: _isBusy ? null : _runPassiveCaptureNow,
                  child: Text(l10n.passiveCaptureButton),
                ),
              ],
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

  Widget _buildLatestPassivePointCard(
    BuildContext context,
    AppLocalizations l10n,
  ) {
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
              value: _formatCoordinate(_latestStoredLocation?.latitude),
            ),
            _InfoRow(
              label: l10n.longitudeLabel,
              value: _formatCoordinate(_latestStoredLocation?.longitude),
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
            _InfoRow(
              label: l10n.passiveCadenceLabel,
              value: l10n.passiveCadenceValue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.backendConfigTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.envLoadedLabel,
              value: AppEnv.isLoaded ? l10n.yesLabel : l10n.noLabel,
            ),
            _InfoRow(
              label: l10n.backendConfiguredLabel,
              value: AppEnv.hasSupabaseConfig
                  ? l10n.backendConfigured
                  : l10n.backendNotConfigured,
            ),
            _InfoRow(
              label: l10n.supabaseHostLabel,
              value: AppEnv.supabaseHost.isEmpty
                  ? l10n.notAvailableValue
                  : AppEnv.supabaseHost,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBatchCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.syncBatchTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.pendingSyncBatchesLabel,
              value: '$_pendingSyncBatches',
            ),
            const SizedBox(height: 8),
            Text(
              AppEnv.hasSyncEncryptionKey
                  ? (l10n.locale.languageCode == 'fr'
                      ? 'Lots de 10 points : charge utile chiffree (AES-256-CBC) avec SYNC_ENCRYPTION_KEY.'
                      : 'Batches of 10 points: payload encrypted (AES-256-CBC) using SYNC_ENCRYPTION_KEY.')
                  : (l10n.locale.languageCode == 'fr'
                      ? 'Lots de 10 points : charge en clair tant que SYNC_ENCRYPTION_KEY est absent du .env.'
                      : 'Batches of 10 points: plaintext until SYNC_ENCRYPTION_KEY is set in .env.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeLine({
    required String label,
    required _StatusBadge badge,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }

  _StatusBadge _statusBadgeForGpsIssue(
    AppLocalizations l10n,
    GpsIssue? issue,
  ) {
    if (issue == null) {
      return _StatusBadge(
        label: l10n.statusUnknown,
        backgroundColor: const Color(0xFFE7ECF4),
        foregroundColor: FiduciaColors.navy,
      );
    }

    if (issue == GpsIssue.none) {
      return _StatusBadge(
        label: l10n.statusOk,
        backgroundColor: const Color(0xFFD9F4DE),
        foregroundColor: FiduciaColors.success,
      );
    }

    if (issue == GpsIssue.unsupportedPlatform) {
      return _StatusBadge(
        label: l10n.statusUnavailable,
        backgroundColor: const Color(0xFFFFE6CC),
        foregroundColor: FiduciaColors.navy,
      );
    }

    if (issue == GpsIssue.lowAccuracy) {
      return _StatusBadge(
        label: l10n.statusPrecisionWeak,
        backgroundColor: const Color(0xFFFFF0C8),
        foregroundColor: FiduciaColors.warning,
      );
    }

    return _StatusBadge(
      label: l10n.statusError,
      backgroundColor: const Color(0xFFFBD8D7),
      foregroundColor: FiduciaColors.danger,
    );
  }

  _StatusBadge _statusBadgeForGeofence(
    AppLocalizations l10n,
    GeofenceDecision? decision,
  ) {
    if (decision != null &&
        decision.status == GeofenceStatus.invalidFix &&
        decision.gpsIssue == GpsIssue.lowAccuracy) {
      return _StatusBadge(
        label: l10n.statusPrecisionWeak,
        backgroundColor: const Color(0xFFFFF0C8),
        foregroundColor: FiduciaColors.warning,
      );
    }

    final status = decision?.status;
    switch (status) {
      case GeofenceStatus.learning:
        return _StatusBadge(
          label: l10n.statusLearning,
          backgroundColor: const Color(0xFFFFF0C8),
          foregroundColor: FiduciaColors.warning,
        );
      case GeofenceStatus.inside:
        return _StatusBadge(
          label: l10n.statusInside,
          backgroundColor: const Color(0xFFD9F4DE),
          foregroundColor: FiduciaColors.success,
        );
      case GeofenceStatus.outside:
        return _StatusBadge(
          label: l10n.statusOutside,
          backgroundColor: const Color(0xFFFBD8D7),
          foregroundColor: FiduciaColors.danger,
        );
      case GeofenceStatus.invalidFix:
      case GeofenceStatus.error:
        return _StatusBadge(
          label: l10n.statusError,
          backgroundColor: const Color(0xFFFBD8D7),
          foregroundColor: FiduciaColors.danger,
        );
      case GeofenceStatus.unsupportedPlatform:
        return _StatusBadge(
          label: l10n.statusUnavailable,
          backgroundColor: const Color(0xFFFFE6CC),
          foregroundColor: FiduciaColors.navy,
        );
      case null:
        return _StatusBadge(
          label: l10n.statusUnknown,
          backgroundColor: const Color(0xFFE7ECF4),
          foregroundColor: FiduciaColors.navy,
        );
    }
  }

  _StatusBadge _statusBadgeForPermission(
    AppLocalizations l10n,
    PermissionSnapshot snapshot,
  ) {
    if (snapshot.permissionState == PermissionState.unsupported) {
      return _StatusBadge(
        label: l10n.statusUnavailable,
        backgroundColor: const Color(0xFFFFE6CC),
        foregroundColor: FiduciaColors.navy,
      );
    }

    if (snapshot.isReady) {
      return _StatusBadge(
        label: l10n.statusReady,
        backgroundColor: const Color(0xFFD9F4DE),
        foregroundColor: FiduciaColors.success,
      );
    }

    return _StatusBadge(
      label: l10n.statusError,
      backgroundColor: const Color(0xFFFBD8D7),
      foregroundColor: FiduciaColors.danger,
    );
  }

  String _formatCoordinate(double? value) {
    if (value == null) {
      return AppLocalizations.of(context).notAvailableValue;
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

  String _permissionSummaryText(
    AppLocalizations l10n,
    PermissionSnapshot snapshot,
  ) {
    final serviceLabel = snapshot.servicesEnabled
        ? l10n.servicesEnabledLabel
        : l10n.servicesDisabledLabel;

    final permissionLabel = switch (snapshot.permissionState) {
      PermissionState.granted => l10n.permissionGrantedLabel,
      PermissionState.foregroundOnly => l10n.permissionForegroundOnlyLabel,
      PermissionState.denied => l10n.permissionDeniedLabel,
      PermissionState.deniedForever => l10n.permissionDeniedForeverLabel,
      PermissionState.unsupported => l10n.permissionUnsupportedLabel,
    };

    final precisionLabel = snapshot.preciseAccuracy
        ? l10n.preciseLabel
        : l10n.approximateLabel;

    return '$serviceLabel | $permissionLabel | $precisionLabel';
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

  String _geofenceStatusText(
    AppLocalizations l10n,
    GeofenceDecision? decision,
  ) {
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
        return l10n.geofenceInvalidFixMessage(
          _gpsIssueText(l10n, decision.gpsIssue),
        );
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

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
