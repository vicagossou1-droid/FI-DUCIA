# FI-DUCIA — Module GPS, tracking passif et géofencing (documentation complète)

Ce document décrit **uniquement la partie « Victor »** : suivi GPS passif, géofencing (apprentissage + contrôle), horodatage basé sur le fix GPS, stockage local, lots prêts à synchroniser, et intégration avec **Juliette** via `validateLocation(clientId)`.

**Nommage**

- **FIDUCIA** : logique interne, logs, identifiants techniques.
- **FI-DUCIA** : libellés UI / branding.

---

## 1. Objectifs métier

1. **Chaque franc collecté doit être associé à une position vérifiable** (dans la limite de la précision GPS réelle à Lomé).
2. **Tracking passif** : enregistrer régulièrement un point (lat, long, précision, horodatage GPS) en **SQLite**, même sans réseau.
3. **Géofencing** :
   - **3 premiers scans** (validations) par client : phase d’**apprentissage** (enregistrement des positions).
   - **À partir du 4e scan** : **contrôle** — le point est comparé à une zone circulaire (rayon par défaut **50 m**, ajustable côté modèle `clients.radius`).
4. **Hors zone** : la validation reste **refusée** (`validateLocation` → `false`), une **alerte locale** est créée, le collecteur peut saisir une **justification** (trace d’audit). La levée métier (validation admin) se fera côté **serveur / dashboard (Ayao)** une fois l’API définie.
5. **Horodatage** : l’heure stockée pour un scan ou un point passif provient du **timestamp du fix GPS** (`Position.timestamp` via Geolocator), en **UTC**, pas de l’horloge « affichage » téléphone.
6. **Sync** : lorsque **10 points passifs** ne sont pas encore exportés, ils sont **groupés** dans la table `sync_batches` (charge chiffrée si `SYNC_ENCRYPTION_KEY` est configurée).

---

## 2. Architecture logicielle (Flutter)

| Composant | Rôle |
|-----------|------|
| `lib/services/location_service.dart` | Import conditionnel : implémentation **Android** vs **Web**. |
| `lib/services/location_service_mobile.dart` | GPS Geolocator, permissions, capture passif, alarme périodique **10 min**. |
| `lib/services/location_service_web.dart` | Stubs sûrs (pas de crash web). |
| `lib/services/geofence_service.dart` | Règles apprentissage + contrôle + insertion alerte hors zone. |
| `lib/services/database_service.dart` | SQLite (mobile) / mémoire (web). |
| `lib/services/sync_batch_service.dart` | Scellement des lots de 10 lignes `locations` → `sync_batches`. |
| `lib/core/validate_location.dart` | API publique pour Juliette : `validateLocation`, `validateLocationDetailed`, `submitOutsideZoneJustification`. |
| `lib/core/app_env.dart` | Chargement `.env` (Supabase + clé de chiffrement des lots). |
| `lib/debug_location_screen.dart` | Écran technique de démo (permissions, GPS, validation, lots). |
| `lib/services/database_write_isolate.dart` | Insertions `locations` par lot dans un **Isolate** (2e connexion SQLite, `singleInstance: false`). |
| `lib/services/location_batch_buffer.dart` | Tampon RAM : flush **5** points ou à la pause app (`AppLifecycleState.paused`). |
| `lib/services/activity_stationary_gate.dart` | Gate « immobile » via **accéléromètre utilisateur** (~10 min) + persistance `SharedPreferences` (lue par l’alarme). |
| `lib/services/centroid_compute.dart` | Centroïde d’apprentissage en **Isolate** + dispersion max (m). |
| `lib/widgets/fiducia_offline_map.dart` | **flutter_map** hors-ligne : tuiles fichier `Documents/.../fiducia_map_tiles/{z}/{x}/{y}.png` ou fond neutre. |
| `lib/core/result.dart` | Type `Result<T,E>` pour flux d’erreur explicites (ex. flush batch). |

**Précision & mock** : rejet silencieux si `accuracy > 65 m` ; **MockLocationException** si `isMocked`. **Seuil « fiable »** aligné sur **65 m** (spec réunion). Rayon géofence métier reste **50 m** par défaut (`clients.radius`).

**SQLite** : `PRAGMA journal_mode=WAL` (+ `synchronous=NORMAL`) à l’ouverture principale et dans l’isolate d’écriture. Version schéma **3** : `clients.photo_path` (photo devanture locale pour marqueurs).

---

## 3. Schéma SQLite (Android)

### 3.1 `locations` (tracking passif)

| Colonne | Description |
|---------|-------------|
| `id` | Clé auto. |
| `latitude`, `longitude`, `accuracy` | Fix GPS filtré (précision ≤ 50 m, pas de mock). |
| `timestamp` | Heure du fix (**ms depuis epoch**, UTC). |
| `pending_export` | `1` = pas encore inclus dans un lot ; `0` = scellé dans `sync_batches`. |

### 3.2 `client_scans` (historique par client)

Chaque appel de validation insère une ligne avec la position utilisée pour cette décision (apprentissage ou contrôle).

### 3.3 `clients`

Centre appris = **centroïde** des 3 premiers scans (`centerLat`, `centerLng`), `radius` (mètres), `photo_path` (optionnel, fichier local pour marqueur carte).

### 3.4 `geofence_alerts` (hors zone)

| Colonne | Description |
|---------|-------------|
| `client_id` | Identifiant client (QR). |
| `latitude`, `longitude`, `gps_timestamp` | Fix refusé. |
| `distance_m`, `radius_m` | Contexte de la décision. |
| `justification` | Texte saisi par le collecteur (via `submitOutsideZoneJustification`). |
| `created_ms` | Aligné sur **`gps_timestamp`** (pas d’horloge système pour l’audit position). |
| `pending_export` | Réservé pour futur lot « alertes » (MVP : non utilisé pour batching). |

### 3.5 `sync_batches` (prêt pour envoi réseau)

| Colonne | Description |
|---------|-------------|
| `payload` | BLOB : JSON UTF-8 **ou** **IV (16 octets) + AES-256-CBC** si clé présente. |
| `is_encrypted` | `0` / `1`. |
| `item_count` | Toujours **10** lors de la création. |
| `created_ms` | **Max** des `gps_timestamp_ms` des 10 points du lot (pas `DateTime.now`). |
| `uploaded` | `0` en attente ; passage à `1` sera fait par la couche sync (à brancher avec Ayao). |

**Version DB** : `_databaseVersion = 3` (`photo_path`, WAL documenté).

---

## 4. Fréquence du tracking passif (10 minutes)

- **WorkManager** impose un minimum d’environ **15 minutes** pour une tâche périodique stable ; pour viser **5–10 minutes**, le projet utilise **`android_alarm_manager_plus`** avec `Duration(minutes: 10)`.
- Le **système Android** peut toutefois regrouper ou retarder les réveils (Doze, économie d’énergie, fabricant). La fréquence réelle doit être **mesurée sur le terrain** (TECNO, Samsung, etc.).

**Initialisation** (`lib/main.dart`, Android uniquement) :

1. `AndroidAlarmManager.initialize()`
2. `DatabaseService.initialize()`
3. `LocationService.initializeBackgroundTracking()` → enregistre l’alarme périodique.

**Callback** : fonction top-level `fiduciaPassiveLocationAlarmCallback` dans `location_service_mobile.dart` (`@pragma('vm:entry-point')`) — charge `.env`, ouvre la DB, exécute la même logique que la capture passif.

---

## 5. Règles GPS « fiables »

Un fix est **accepté** pour scan ou stockage passif si :

- Services de localisation activés ;
- Permission adaptée (**« Toujours »** exigée pour la capture en tâche de fond) ;
- Précision **`accuracy` ≤ 50 m** ;
- **`isMocked == false`** (rejets des faux GPS).

Sinon : code d’erreur (`GpsIssue`) et pas d’insertion « trusted ».

---

## 6. Géofencing — détail du flux

### 6.1 Entrée : `validateLocation(clientId)` / `validateLocationDetailed(clientId)`

1. Normalisation de `clientId` (trim).
2. Lecture GPS **sans** exiger la permission arrière-plan pour ce flux (scan QR au premier plan) : `requireBackgroundPermission: false`.
3. Si fix non fiable → `isAllowed: false`, statut `invalidFix` ou `unsupportedPlatform` (web).
4. Insertion du **scan** dans `client_scans`.
5. `scanCount = nombre total de scans` pour ce client :
   - Si `scanCount <= 3` : phase **learning** → `isAllowed: true`, statut `learning`. Au **3e** scan, recalcul du centre (moyenne des 3 positions) et mise à jour `clients`.
   - Si `scanCount >= 4` : lecture du client appris ; distance **Haversine** ; si `distance <= radius` → **inside** (`isAllowed: true`) ; sinon **outside** (`isAllowed: false`), **insertion** d’une ligne dans `geofence_alerts`, retour avec `geofenceAlertLocalId`.

### 6.2 Justification hors zone

- Après un refus **outside**, l’UI démo ouvre une boîte de dialogue.
- `submitOutsideZoneJustification(alertLocalId:, justification:)` met à jour la colonne `justification`.
- **Important** : cela ne change **pas** automatiquement `validateLocation` en `true` — la décision métier « accepter quand même » reste **côté admin / API** (prochaine étape avec Ayao).

---

## 7. Lots synchronisation (10 points)

1. Après chaque insertion réussie en `locations`, `SyncBatchService.maybeCreateLocationBatches()` boucle tant qu’il existe au moins **10** lignes avec `pending_export = 1`.
2. Construction d’un JSON listant `id`, coordonnées, précision, `gps_timestamp_ms`.
3. Si `AppEnv.hasSyncEncryptionKey` : chiffrement **AES-256-CBC** ; préfixe des **16 octets** = IV, le reste = ciphertext.
4. Insertion dans `sync_batches`, puis `pending_export = 0` sur les 10 lignes (transaction SQLite).

### Variables `.env`

| Clé | Rôle |
|-----|------|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Statut « backend configuré » (démo). |
| `SYNC_ENCRYPTION_KEY` | Si longueur **≥ 8** après trim : lots chiffrés. Sinon : lots en **clair** (développement uniquement). |

**`SYNC_ENCRYPTION_KEY` (vue équipe)**  
Ce n’est pas une valeur fournie par Supabase : c’est un **secret partagé** entre l’app et le service qui déchiffrera les lots (même chaîne, ou dérivation identique côté serveur). Génération typique (à refaire pour chaque environnement si besoin) :

```bash
openssl rand -base64 32
```

Coller le résultat dans `.env` (fichier **non versionné** ; ne pas committer la clé réelle). En production, la clé **sur l’appareil** reste exposée si le téléphone est compromis — le chiffrement des lots protège surtout la **confidentialité en transit / au repos côté file** ; un modèle plus fort = clés côté serveur, TLS, rotation, etc.

---

## 7 bis. UI « collecteur » (écran principal)

- **Barre de statut (heure, réseau, batterie)** : style système synchronisé avec le thème clair / sombre (`AnnotatedRegion<SystemUiOverlayStyle>` dans `lib/main.dart` + `FiduciaTheme.systemUiOverlayForBrightness`) pour éviter des icônes blanches illisibles sur fond clair.
- **Permissions** : plus de bloc permanent « Demander les permissions » sur la page d’accueil. Au **premier lancement**, dialogue expliquant l’usage de la localisation ; ensuite accès aux réglages via l’**icône engrenage** dans la barre d’en-tête. Préférence persistée avec `shared_preferences` (`lib/core/fiducia_prefs.dart`).
- **Texte « en arrière-plan… 10 minutes »** : retiré de l’UI grand public (détail d’implémentation). La doc technique ci-dessous conserve la fréquence cible.

---

## 7 ter. Fichier « bd Fiducia.odt » (schéma base)

Si le livrable attendu est un **fichier** `.odt` (archive LibreOffice), il doit être un **fichier** et non un dossier vide. À la date de mise à jour, un dossier nommé `bd Fiducia.odt` sans contenu exploitable **n’a pas permis** d’extraire des tables SQL. Dès réception d’un vrai `.odt` ou d’un export **SQL / PDF / diagramme**, aligner `database_service_mobile.dart` et le **format JSON** des lots avec le schéma réel (colonnes, types, noms d’API).

---

## 8. Intégration Juliette (flux recommandé)

```dart
final ok = await validateLocation(clientId);
if (!ok) {
  final details = await validateLocationDetailed(clientId);
  if (details.status == GeofenceStatus.outside &&
      details.geofenceAlertLocalId != null) {
    // Afficher popup justification, puis :
    await submitOutsideZoneJustification(
      alertLocalId: details.geofenceAlertLocalId!,
      justification: texteSaisi,
    );
  }
  // Bloquer la collecte ou demander validation admin selon règles produit.
  return;
}
// Continuer : photo, montant, etc.
```

**Note** : `validateLocationDetailed` refait un scan GPS et **ré-insère** un `client_scan` — pour la prod, prévoir une API unique qui retourne décision + `alertId` sans double scan (refactor léger à planifier avec Juliette).

---

## 9. Écran debug (interne)

- Lancer avec : `flutter run --dart-define=DEBUG_DASHBOARD=true`.
- Vue d’ensemble permissions / GPS / géofence.
- Boutons « Actualiser GPS » vs « Capture passive » : même pipeline que l’alarme, mais déclenché à la demande.
- Carte **Lots synchronisation** : nombre de lignes `sync_batches` avec `uploaded = 0`.
- Carte **Environnement** : `.env` + Supabase (non requis au runtime GPS).

---

## 10. Web vs Android

- **Web** : pas de SQLite plugin réel, pas d’alarme, pas de GPS natif — messages de repli, pas de crash.
- **Android** : seule plateforme supportée pour le module complet.

---

## 11. Sécurité et limites (honnêteté technique)

- **Antidate / root** : aucun smartphone ne peut garantir une preuve cryptographique absolue sans **matériel sécurisé** ou **validation serveur** (signatures, nonce, TOTP, etc.). Ici : **meilleure pratique mobile** (timestamp du fix, filtre mock, précision).
- **Chiffrement des lots** : protège la **confidentialité en transit** une fois la couche réseau branchée ; la clé dans `.env` sur le téléphone reste **exposable** si l’appareil est compromis — en production, prévoir **enveloppe de clé** ou **échange TLS + certificat pinning** selon le modèle d’Ayao.

---

## 12. Check-list terrain (Lomé)

1. Mesurer la **fréquence réelle** des points passifs (journal `adb` / fichier export).
2. Mesurer **précision** et taux de rejet (> 50 m) sur 5–10 adresses réelles.
3. Mesurer **autonomie** batterie sur une journée type (8 h).
4. Valider avec Juliette le **contrat unique** « un scan → une décision » pour éviter les doubles `client_scans`.

---

## 13. Fichiers clés modifiés ou ajoutés (référence)

- `lib/services/location_service_mobile.dart` — alarme 10 min + callback.
- `lib/services/sync_batch_service.dart` — export conditionnel.
- `lib/services/sync_batch_service_mobile.dart` / `sync_batch_service_web.dart`
- `lib/services/database_service_mobile.dart` — schéma v2.
- `lib/services/geofence_service.dart` — alerte hors zone + `geofenceAlertLocalId`.
- `lib/core/validate_location.dart` — `submitOutsideZoneJustification`.
- `lib/core/app_env.dart` — `SYNC_ENCRYPTION_KEY`.
- `lib/main.dart` — `AndroidAlarmManager.initialize()`.
- `android/app/src/main/AndroidManifest.xml` — `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `RebootBroadcastReceiver` (plugin alarme).
- `lib/core/fiducia_prefs.dart` — premier lancement (intro localisation).
- `docs/MODULE_GPS_GEOFENCING_FIDUCIA.md` — ce document.
- `docs/GUIDE_UTILISATEUR_FI_DUCIA.md` — guide utilisateur (terrain).

---

*Document généré pour l’équipe projet FI-DUCIA / FIDUCIA — module GPS & géofencing.*
