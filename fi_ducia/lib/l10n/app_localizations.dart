import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(instance != null, 'AppLocalizations not found in context.');
    return instance!;
  }

  static const Map<String, Map<String, String>> _localizedValues =
      <String, Map<String, String>>{
    'en': <String, String>{
      'appTitle': 'FI-DUCIA',
      'appSubtitle': 'Trust, everywhere.',
      'languageMenuTitle': 'Change language',
      'themeMenuTitle': 'Change theme',
      'languageFrench': 'French',
      'languageEnglish': 'English',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'androidOnlyMessage':
          'This feature is available on Android only',
      'androidOnlyDetails':
          'Web mode is kept safe for demos. GPS, background tracking, and geofencing validation are disabled here to avoid crashes.',
      'statusOverviewTitle': 'Status overview',
      'gpsStatusTitle': 'GPS',
      'geofenceStatusTitle': 'Client zone',
      'permissionsStatusTitle': 'Permissions',
      'platformLabel': 'Platform',
      'platformAndroid': 'Android',
      'permissionDetailsLabel': 'Runtime details',
      'servicesEnabledLabel': 'Services enabled',
      'servicesDisabledLabel': 'Services disabled',
      'permissionGrantedLabel': 'Always allowed',
      'permissionForegroundOnlyLabel': 'Foreground only',
      'permissionDeniedLabel': 'Permission denied',
      'permissionDeniedForeverLabel': 'Permission denied forever',
      'permissionUnsupportedLabel': 'Unsupported on this platform',
      'preciseLabel': 'Precise GPS',
      'approximateLabel': 'Approximate GPS',
      'statusOk': 'OK',
      'statusError': 'ERROR',
      'statusUnavailable': 'UNAVAILABLE',
      'statusUnknown': 'UNKNOWN',
      'statusReady': 'READY',
      'statusLearning': 'LEARNING',
      'statusInside': 'INSIDE',
      'statusOutside': 'OUTSIDE',
      'currentLocationTitle': 'Current GPS fix',
      'latitudeLabel': 'Latitude',
      'longitudeLabel': 'Longitude',
      'accuracyLabel': 'Accuracy',
      'gpsTimestampLabel': 'GPS time',
      'refreshGpsButton': 'Refresh GPS',
      'passiveCaptureButton': 'Run passive capture',
      'validationTitle': 'Client validation',
      'clientIdLabel': 'Client ID',
      'clientIdHint': 'Example: CLT-001',
      'validateButton': 'Validate location',
      'clientIdRequiredMessage': 'Enter a client ID before validation.',
      'validationSummaryLabel': 'Decision',
      'lastPassivePointTitle': 'Last stored passive point',
      'passiveCadenceLabel': 'Passive cadence',
      'passiveCadenceValue':
          'About every 10 minutes on Android (OS may merge wake-ups).',
      'requestPermissionsButton': 'Request permissions',
      'openAppSettingsButton': 'Open app settings',
      'openGpsSettingsButton': 'Open GPS settings',
      'backendConfigTitle': 'Environment',
      'envLoadedLabel': '.env loaded',
      'backendConfiguredLabel': 'Backend status',
      'backendConfigured': 'Configured',
      'backendNotConfigured': 'Not configured',
      'supabaseHostLabel': 'Supabase host',
      'yesLabel': 'Yes',
      'noLabel': 'No',
      'notAvailableValue': 'Not available',
      'gpsIssueNoAttempt': 'No GPS check yet.',
      'gpsIssueNone': 'Trusted GPS fix available.',
      'gpsIssueUnsupportedPlatform':
          'GPS services are disabled on web for demo safety.',
      'gpsIssueServicesDisabled':
          'Location services are disabled on the device.',
      'gpsIssuePermissionDenied': 'Location permission was denied.',
      'gpsIssuePermissionDeniedForever':
          'Location permission was denied forever.',
      'gpsIssueBackgroundRequired':
          'Background location is required for passive tracking.',
      'gpsIssueTimeout': 'GPS request timed out. Try again later.',
      'gpsIssueLowAccuracy':
          'GPS accuracy is above the 65 meter limit.',
      'gpsIssueMockLocation': 'Mock location detected.',
      'gpsIssueUnknown': 'GPS validation failed.',
      'geofenceNoDecision': 'No geofence decision yet.',
      'geofenceUnsupportedMessage': 'Geofencing is disabled on web.',
      'geofenceErrorMessage':
          'The geofence decision could not be computed.',
      'statusPrecisionWeak': 'LOW PRECISION',
      'geofenceBlockedLowGps':
          'Blocked: GPS accuracy is weaker than required (try outdoors or wait).',
      'prodPositionTitle': 'Your position',
      'mapOfflineTitle': 'Map (offline — LIS / Lome)',
      'prodSettingsButton': 'Settings',
      'prodSettingsSheetTitle': 'Open settings',
      'prodTileAppSettings': 'App permissions',
      'prodTileGpsSettings': 'GPS / location',
      'locationIntroTitle': 'Location access',
      'locationIntroBody':
          'FI-DUCIA needs your location while you use the app and in the background to record visits and check client zones. You can change this anytime in the phone settings (gear icon at the top of this screen).',
      'locationIntroAllow': 'Allow',
      'locationIntroLater': 'Not now',
      'outsideJustificationTitle': 'Outside client zone',
      'outsideJustificationHint':
          'Explain why you are collecting here (audit trail for supervisors).',
      'outsideJustificationSubmit': 'Submit explanation',
      'outsideJustificationCancel': 'Skip for now',
      'syncBatchTitle': 'Sync batches (local)',
      'pendingSyncBatchesLabel': 'Pending server upload',
    },
    'fr': <String, String>{
      'appTitle': 'FI-DUCIA',
      'appSubtitle': 'La confiance, partout.',
      'languageMenuTitle': 'Changer la langue',
      'themeMenuTitle': 'Changer le theme',
      'languageFrench': 'Francais',
      'languageEnglish': 'Anglais',
      'themeSystem': 'Systeme',
      'themeLight': 'Clair',
      'themeDark': 'Sombre',
      'androidOnlyMessage':
          'Cette fonctionnalite est disponible uniquement sur Android',
      'androidOnlyDetails':
          'Le mode web reste allume pour les demonstrations. Le GPS, le suivi en arriere-plan et la validation de geofence y sont desactives pour eviter les crashs.',
      'statusOverviewTitle': "Vue d'ensemble",
      'gpsStatusTitle': 'GPS',
      'geofenceStatusTitle': 'Zone client',
      'permissionsStatusTitle': 'Permissions',
      'platformLabel': 'Plateforme',
      'platformAndroid': 'Android',
      'permissionDetailsLabel': "Etat d'execution",
      'servicesEnabledLabel': 'Services actifs',
      'servicesDisabledLabel': 'Services desactives',
      'permissionGrantedLabel': 'Autorise en permanence',
      'permissionForegroundOnlyLabel': 'Premier plan uniquement',
      'permissionDeniedLabel': 'Permission refusee',
      'permissionDeniedForeverLabel':
          'Permission refusee definitivement',
      'permissionUnsupportedLabel':
          'Non pris en charge sur cette plateforme',
      'preciseLabel': 'GPS precis',
      'approximateLabel': 'GPS approximatif',
      'statusOk': 'OK',
      'statusError': 'ERREUR',
      'statusUnavailable': 'INDISPONIBLE',
      'statusUnknown': 'INCONNU',
      'statusReady': 'PRET',
      'statusLearning': 'APPRENTISSAGE',
      'statusInside': 'DANS LA ZONE',
      'statusOutside': 'HORS ZONE',
      'currentLocationTitle': 'Position GPS courante',
      'latitudeLabel': 'Latitude',
      'longitudeLabel': 'Longitude',
      'accuracyLabel': 'Precision',
      'gpsTimestampLabel': 'Heure GPS',
      'refreshGpsButton': 'Actualiser le GPS',
      'passiveCaptureButton': 'Lancer une capture passive',
      'validationTitle': 'Validation client',
      'clientIdLabel': 'ID client',
      'clientIdHint': 'Exemple : CLT-001',
      'validateButton': 'Valider la position',
      'clientIdRequiredMessage':
          'Saisissez un ID client avant la validation.',
      'validationSummaryLabel': 'Decision',
      'lastPassivePointTitle':
          'Dernier point passif enregistre',
      'passiveCadenceLabel': 'Frequence passive',
      'passiveCadenceValue':
          'Environ toutes les 10 minutes sur Android (le systeme peut regrouper les reveils).',
      'requestPermissionsButton': 'Demander les permissions',
      'openAppSettingsButton':
          "Ouvrir les reglages de l'application",
      'openGpsSettingsButton': 'Ouvrir les reglages GPS',
      'backendConfigTitle': 'Environnement',
      'envLoadedLabel': '.env charge',
      'backendConfiguredLabel': 'Etat backend',
      'backendConfigured': 'Configure',
      'backendNotConfigured': 'Non configure',
      'supabaseHostLabel': 'Hote Supabase',
      'yesLabel': 'Oui',
      'noLabel': 'Non',
      'notAvailableValue': 'Non disponible',
      'gpsIssueNoAttempt':
          "Aucune verification GPS pour le moment.",
      'gpsIssueNone': 'Position GPS fiable disponible.',
      'gpsIssueUnsupportedPlatform':
          'Les services GPS sont desactives sur le web pour la demo.',
      'gpsIssueServicesDisabled':
          "Les services de localisation sont desactives sur l'appareil.",
      'gpsIssuePermissionDenied':
          'La permission de localisation a ete refusee.',
      'gpsIssuePermissionDeniedForever':
          'La permission de localisation a ete refusee definitivement.',
      'gpsIssueBackgroundRequired':
          'La localisation en arriere-plan est requise pour le suivi passif.',
      'gpsIssueTimeout':
          'La demande GPS a expire. Reessayez plus tard.',
      'gpsIssueLowAccuracy':
          'La precision GPS depasse la limite de 65 metres.',
      'gpsIssueMockLocation':
          'Une fausse localisation a ete detectee.',
      'gpsIssueUnknown': 'La validation GPS a echoue.',
      'geofenceNoDecision':
          'Aucune decision de geofence pour le moment.',
      'geofenceUnsupportedMessage':
          'La geofence est desactivee sur le web.',
      'geofenceErrorMessage':
          "La decision de geofence n'a pas pu etre calculee.",
      'statusPrecisionWeak': 'PRECISION FAIBLE',
      'geofenceBlockedLowGps':
          'Bloque : precision GPS insuffisante (deplacez-vous vers l\'exterieur ou reessayez).',
      'prodPositionTitle': 'Votre position',
      'mapOfflineTitle': 'Carte (hors ligne — LIS / Lome)',
      'prodSettingsButton': 'Parametres',
      'prodSettingsSheetTitle': 'Ouvrir les reglages',
      'prodTileAppSettings': 'Permissions de l\'application',
      'prodTileGpsSettings': 'GPS / localisation',
      'locationIntroTitle': 'Accès à la localisation',
      'locationIntroBody':
          'FI-DUCIA a besoin de votre position pendant l’utilisation et en arrière-plan pour enregistrer les visites et vérifier les zones client. Vous pourrez modifier cela dans les réglages du téléphone (icône engrenage en haut de l’écran).',
      'locationIntroAllow': 'Autoriser',
      'locationIntroLater': 'Plus tard',
      'outsideJustificationTitle': 'Hors zone client',
      'outsideJustificationHint':
          'Expliquez pourquoi vous collectez ici (trace pour supervision).',
      'outsideJustificationSubmit': 'Envoyer la justification',
      'outsideJustificationCancel': 'Plus tard',
      'syncBatchTitle': 'Lots synchronisation (local)',
      'pendingSyncBatchesLabel': 'En attente envoi serveur',
    },
  };

  String _value(String key) {
    final languageCode = supportedLocales.any(
      (localeItem) => localeItem.languageCode == locale.languageCode,
    )
        ? locale.languageCode
        : 'fr';

    return _localizedValues[languageCode]![key]!;
  }

  String get appTitle => _value('appTitle');
  String get appSubtitle => _value('appSubtitle');
  String get languageMenuTitle => _value('languageMenuTitle');
  String get themeMenuTitle => _value('themeMenuTitle');
  String get languageFrench => _value('languageFrench');
  String get languageEnglish => _value('languageEnglish');
  String get themeSystem => _value('themeSystem');
  String get themeLight => _value('themeLight');
  String get themeDark => _value('themeDark');
  String get androidOnlyMessage => _value('androidOnlyMessage');
  String get androidOnlyDetails => _value('androidOnlyDetails');
  String get statusOverviewTitle => _value('statusOverviewTitle');
  String get gpsStatusTitle => _value('gpsStatusTitle');
  String get geofenceStatusTitle => _value('geofenceStatusTitle');
  String get permissionsStatusTitle => _value('permissionsStatusTitle');
  String get platformLabel => _value('platformLabel');
  String get platformAndroid => _value('platformAndroid');
  String get permissionDetailsLabel => _value('permissionDetailsLabel');
  String get servicesEnabledLabel => _value('servicesEnabledLabel');
  String get servicesDisabledLabel => _value('servicesDisabledLabel');
  String get permissionGrantedLabel => _value('permissionGrantedLabel');
  String get permissionForegroundOnlyLabel =>
      _value('permissionForegroundOnlyLabel');
  String get permissionDeniedLabel => _value('permissionDeniedLabel');
  String get permissionDeniedForeverLabel =>
      _value('permissionDeniedForeverLabel');
  String get permissionUnsupportedLabel =>
      _value('permissionUnsupportedLabel');
  String get preciseLabel => _value('preciseLabel');
  String get approximateLabel => _value('approximateLabel');
  String get statusOk => _value('statusOk');
  String get statusError => _value('statusError');
  String get statusUnavailable => _value('statusUnavailable');
  String get statusUnknown => _value('statusUnknown');
  String get statusReady => _value('statusReady');
  String get statusLearning => _value('statusLearning');
  String get statusInside => _value('statusInside');
  String get statusOutside => _value('statusOutside');
  String get currentLocationTitle => _value('currentLocationTitle');
  String get latitudeLabel => _value('latitudeLabel');
  String get longitudeLabel => _value('longitudeLabel');
  String get accuracyLabel => _value('accuracyLabel');
  String get gpsTimestampLabel => _value('gpsTimestampLabel');
  String get refreshGpsButton => _value('refreshGpsButton');
  String get passiveCaptureButton => _value('passiveCaptureButton');
  String get validationTitle => _value('validationTitle');
  String get clientIdLabel => _value('clientIdLabel');
  String get clientIdHint => _value('clientIdHint');
  String get validateButton => _value('validateButton');
  String get clientIdRequiredMessage => _value('clientIdRequiredMessage');
  String get validationSummaryLabel => _value('validationSummaryLabel');
  String get lastPassivePointTitle => _value('lastPassivePointTitle');
  String get passiveCadenceLabel => _value('passiveCadenceLabel');
  String get passiveCadenceValue => _value('passiveCadenceValue');
  String get requestPermissionsButton => _value('requestPermissionsButton');
  String get openAppSettingsButton => _value('openAppSettingsButton');
  String get openGpsSettingsButton => _value('openGpsSettingsButton');
  String get backendConfigTitle => _value('backendConfigTitle');
  String get envLoadedLabel => _value('envLoadedLabel');
  String get backendConfiguredLabel => _value('backendConfiguredLabel');
  String get backendConfigured => _value('backendConfigured');
  String get backendNotConfigured => _value('backendNotConfigured');
  String get supabaseHostLabel => _value('supabaseHostLabel');
  String get yesLabel => _value('yesLabel');
  String get noLabel => _value('noLabel');
  String get notAvailableValue => _value('notAvailableValue');
  String get gpsIssueNoAttempt => _value('gpsIssueNoAttempt');
  String get gpsIssueNone => _value('gpsIssueNone');
  String get gpsIssueUnsupportedPlatform =>
      _value('gpsIssueUnsupportedPlatform');
  String get gpsIssueServicesDisabled => _value('gpsIssueServicesDisabled');
  String get gpsIssuePermissionDenied => _value('gpsIssuePermissionDenied');
  String get gpsIssuePermissionDeniedForever =>
      _value('gpsIssuePermissionDeniedForever');
  String get gpsIssueBackgroundRequired =>
      _value('gpsIssueBackgroundRequired');
  String get gpsIssueTimeout => _value('gpsIssueTimeout');
  String get gpsIssueLowAccuracy => _value('gpsIssueLowAccuracy');
  String get gpsIssueMockLocation => _value('gpsIssueMockLocation');
  String get gpsIssueUnknown => _value('gpsIssueUnknown');
  String get geofenceNoDecision => _value('geofenceNoDecision');
  String get geofenceUnsupportedMessage =>
      _value('geofenceUnsupportedMessage');
  String get geofenceErrorMessage => _value('geofenceErrorMessage');
  String get outsideJustificationTitle => _value('outsideJustificationTitle');
  String get outsideJustificationHint => _value('outsideJustificationHint');
  String get outsideJustificationSubmit =>
      _value('outsideJustificationSubmit');
  String get outsideJustificationCancel =>
      _value('outsideJustificationCancel');
  String get syncBatchTitle => _value('syncBatchTitle');
  String get pendingSyncBatchesLabel => _value('pendingSyncBatchesLabel');
  String get statusPrecisionWeak => _value('statusPrecisionWeak');
  String get geofenceBlockedLowGps => _value('geofenceBlockedLowGps');
  String get prodPositionTitle => _value('prodPositionTitle');
  String get mapOfflineTitle => _value('mapOfflineTitle');
  String get prodSettingsButton => _value('prodSettingsButton');
  String get prodSettingsSheetTitle => _value('prodSettingsSheetTitle');
  String get prodTileAppSettings => _value('prodTileAppSettings');
  String get prodTileGpsSettings => _value('prodTileGpsSettings');
  String get locationIntroTitle => _value('locationIntroTitle');
  String get locationIntroBody => _value('locationIntroBody');
  String get locationIntroAllow => _value('locationIntroAllow');
  String get locationIntroLater => _value('locationIntroLater');

  String geofenceLearningProgress(int current, int required) {
    if (locale.languageCode == 'fr') {
      return 'Phase d\'apprentissage : scan $current sur $required.';
    }
    return 'Learning phase: scan $current of $required.';
  }

  String geofenceDistanceMessage(String distance, String radius) {
    if (locale.languageCode == 'fr') {
      return 'Distance de $distance m comparee a un rayon de $radius m.';
    }
    return 'Distance $distance m compared with a $radius m radius.';
  }

  String geofenceInvalidFixMessage(String reason) {
    if (locale.languageCode == 'fr') {
      return 'Validation bloquee : $reason';
    }
    return 'Validation blocked: $reason';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
