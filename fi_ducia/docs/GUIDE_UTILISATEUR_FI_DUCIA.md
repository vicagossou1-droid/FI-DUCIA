# FI-DUCIA — Guide d’utilisation (terrain)

Ce guide s’adresse aux **collecteurs** et aux **responsables terrain**. Il décrit l’application telle qu’elle apparaît sur **Android** (écran principal « collecteur »).

---

## 1. À quoi sert l’application ?

FI-DUCIA permet de :

- Vérifier votre **position GPS** au moment d’une collecte.
- Associer cette position à un **identifiant client** (souvent issu d’un QR code métier).
- Déterminer si vous êtes dans la **zone client** attendue, une fois la zone apprise par l’application (premiers passages).

L’application peut aussi enregistrer des positions en **arrière-plan** pour la traçabilité, selon la configuration déployée.

---

## 2. Première ouverture : la localisation

Au **premier lancement**, une fenêtre explique pourquoi la localisation est nécessaire. Vous pouvez :

- **Autoriser** : l’application demandera les autorisations Android (y compris l’accès en arrière-plan si le produit l’exige).
- **Plus tard** : vous pourrez autoriser plus tard via les réglages du téléphone.

Une fois ce dialogue vu et validé (autorisation ou « Plus tard »), il **ne s’affiche plus** à chaque ouverture.

---

## 3. Barre de statut (heure, réseau, batterie)

En **thème clair**, la barre du haut utilise des **icônes sombres** pour rester lisible sur fond clair. En **thème sombre**, les icônes s’adaptent automatiquement.

Vous pouvez changer le thème via l’icône **palette** en haut à droite.

---

## 4. Vue d’ensemble (GPS et zone client)

La carte **Vue d’ensemble** résume :

- **GPS** : état du dernier contrôle (par exemple précision insuffisante si le signal est faible).
- **Zone client** : état de la validation par rapport à la zone enregistrée pour ce client (apprentissage, dans la zone, hors zone, etc.).

Ce bloc est **informatif** : il ne contient plus de boutons « permissions » permanents ; les réglages système sont accessibles via l’**engrenage** (voir §7).

---

## 5. Votre position

Cette section affiche la **dernière position** obtenue quand vous appuyez sur **Actualiser le GPS**. Si rien n’a été lu, les champs affichent « Non disponible ».

**Conseil terrain** : privilégiez l’**extérieur** ou une zone dégagée pour une meilleure précision (souvent meilleure que sous toit ou entre bâtiments).

---

## 6. Dernier point enregistré automatiquement

Cette section indique le **dernier point** enregistré par le mécanisme d’arrière-plan (s’il existe et si les conditions sont réunies : permissions, précision, batterie, politique Android).

Vous n’avez **rien à configurer** ici pour un usage normal : c’est une **lecture** pour vérifier qu’un enregistrement a bien eu lieu.

---

## 7. Icône engrenage (réglages)

En haut à droite, l’icône **engrenage** ouvre un menu pour :

- les **réglages de l’application** (permissions) ;
- les **réglages GPS / localisation** du téléphone.

À utiliser si vous aviez refusé une permission au départ ou si le système a réinitialisé les autorisations.

---

## 8. Validation client

1. Saisissez l’**ID client** (exemple : `CLT-001`).
2. Appuyez sur **Valider la position**.

L’application indique alors une **décision** (zone, GPS, résumé). Si la **précision GPS est trop faible** (au-delà de la limite définie par le projet, souvent 50 mètres), la validation peut être **refusée** : déplacez-vous ou réessayez quand le fix est meilleur.

Si vous êtes **hors zone** et qu’une justification est demandée par le flux métier, saisissez une courte explication lorsque la fenêtre apparaît.

---

## 9. Langue

L’icône **globe** permet de choisir le **français** ou l’**anglais**.

---

## 10. Foire aux questions

### Pourquoi « précision faible » ou validation bloquée ?

Le GPS sur téléphone dépend du ciel visible, des bâtiments et de l’appareil. En intérieur ou avec un mauvais signal, l’erreur peut dépasser la limite fixée par le projet : la validation est alors bloquée **volontairement** pour limiter les erreurs de position.

### Que signifiait l’ancien texte « en arrière-plan… environ toutes les 10 minutes » ?

C’était une **explication technique** pour les développeurs : l’application peut enregistrer un point de façon périodique quand l’OS le permet. Ce détail n’est **pas nécessaire** au collecteur pour son travail quotidien ; il a été retiré de l’interface grand public. La fréquence réelle peut varier selon le téléphone et l’économie d’énergie.

### Où sont mes données ?

Les positions et décisions sont stockées **sur l’appareil** (base locale) dans le cadre du module ; l’envoi vers un serveur dépend de l’intégration réseau prévue par votre équipe.

---

## 11. Pour l’équipe technique : clé `SYNC_ENCRYPTION_KEY`

Ce point ne concerne pas le collecteur au quotidien. Pour préparer des **lots chiffrés** avant envoi serveur, l’équipe doit définir une valeur secrète dans le fichier `.env` du build (non commité), par exemple en générant une chaîne aléatoire :

```bash
openssl rand -base64 32
```

La même logique de secret doit être connue **côté serveur** pour déchiffrer ou vérifier les lots. Ce n’est **pas** une clé fournie automatiquement par Supabase.

Voir aussi `docs/MODULE_GPS_GEOFENCING_FIDUCIA.md` et `.env.example` à la racine du projet.

---

*FI-DUCIA — document utilisateur. Pour l’architecture et l’API développeur, se référer au module technique.*
