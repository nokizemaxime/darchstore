# Darch Store

Application Android qui distribue vos applications Flutter. Une fois le store installé sur le téléphone, les nouvelles versions se téléchargent et s’installent depuis le catalogue, sans renvoyer l’APK à la main.

La consultation du catalogue ne demande pas de compte. Un identifiant Firebase anonyme, invisible, sert uniquement à enregistrer les statistiques de l’appareil.

## Parcours

- **Catalogue** : applications publiées, recherche et catégories.
- **Fiche** : téléchargement, vérification SHA-256, contrôle du certificat, puis confirmation Android.
- **Mises à jour** : détectées en comparant le `versionCode` installé. Une notification locale est proposée, au plus une fois toutes les 12 heures pour le même lot.
- **Bibliothèque** : applications du catalogue déjà présentes sur le téléphone.

La mise à jour conserve les données de l’application lorsque le certificat de signature est le même. Si le certificat diffère, le store refuse l’installation avant même l’écran système. Le retour vers une version plus ancienne est aussi refusé.

Le message push, s’il est utilisé, ne fait que réveiller l’application. L’APK n’est jamais pris dans la notification : il est relu depuis Firestore et Storage.

## Préparer Firebase

La liste complète, store et back-office, est dans `CONFIGURATION_FIREBASE.md` à la racine du dépôt.

1. Créez un projet Firebase.
2. Activez Firestore, Storage, Cloud Messaging et l’authentification **anonyme**.
3. À la racine du projet :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Placez `google-services.json` dans `android/app/` (généré par la commande). Le plugin Gradle n’est appliqué que si ce fichier est présent.
5. Déployez les règles et les index :

```bash
firebase deploy --only firestore,storage
```

6. En production, activez App Check seulement après avoir enregistré le fournisseur Play Integrity, ou le jeton de debug en développement. Tant que l’application d’App Check n’est pas exigée dans la console, le catalogue reste lisible.

Installez ensuite cette application sur le téléphone. Android demandera une fois l’autorisation d’installer depuis cette source.

## Publier une application

Le back-office est le projet `darchstorebac`, à côté de cette application. Il écrit `apps`, `versions` et Storage avec un compte dont le jeton porte `admin: true`. Le téléphone ne peut pas publier.

1. Activez l’authentification e-mail/mot de passe, en plus de l’anonyme déjà utilisée par le store.
2. Créez le compte administrateur dans Authentication.
3. Depuis `darchstore/functions` : `npm install`, puis `node scripts/set-admin.js admin@example.com`. Le script utilise les identifiants Google Application Default et le projet de `.firebaserc`.
4. Copiez `darchstorebac/.env.example` vers `.env.development.local` et vers `.env.production`.
5. Déployez : `firebase deploy --only firestore,storage,functions`.

Les functions demandent le plan Blaze. Sans elles, la publication du catalogue fonctionne. Les totaux, l’effacement d’un appareil et le signal push attendent le déploiement.

`versionCode` ne diminue pas, `packageName` reste fixe, et `signatureSha256` est épinglée dès qu’elle est renseignée. L’APK va dans `releases/{appId}/{versionCode}.apk`. Le back-office calcule le SHA-256. `published: false` reste invisible dans le store.

La publication manuelle, si besoin, suit le même contrat.

1. Calculez l’empreinte du fichier :

```bash
certutil -hashfile app-release.apk SHA256
```

2. Relevez le certificat signer (la même valeur que le store calcule sur l’APK) :

```bash
apksigner verify --print-certs app-release.apk
```

Utilisez la ligne `Signer #1 certificate SHA-256 digest`, en minuscules, sans deux-points.

3. Uploadez l’APK dans Storage à `releases/{appId}/{versionCode}.apk`.
4. Créez le document `apps/{appId}` :

| Champ | Rôle |
| --- | --- |
| `name`, `nameLower`, `summary`, `description` | Textes affichés |
| `packageName` | Identifiant Android, identique à celui du `build.gradle` |
| `category`, `developerName` | Classement |
| `iconUrl`, `websiteUrl` | URL `https` uniquement |
| `published` | `true` pour apparaître dans le store |
| `featured`, `mandatory` | Mise en avant et mise à jour importante |
| `latestVersionCode`, `latestVersionName` | Dernière version. `versionCode` doit augmenter |
| `releaseNotes` | Notes de la dernière version |
| `apkStoragePath` | `releases/{appId}/{versionCode}.apk` |
| `sha256` | Empreinte hexadécimale du fichier, 64 caractères |
| `signatureSha256` | Empreinte du certificat. Obligatoire pour épingler les mises à jour |
| `sizeBytes`, `minSdk` | Contrôles avant téléchargement |
| `downloadCount` | Compteur maintenu par l’administration, pas par le téléphone |
| `createdAt`, `updatedAt` | Timestamps Firestore |

L’historique optionnel vit dans `apps/{appId}/versions/{versionId}` avec `published`, `versionCode`, `versionName`, `releaseNotes`, `sizeBytes`, `mandatory` et `createdAt`. Seule la dernière version du document parent est installable.

Signez toutes les versions d’une application avec la même clé. Changer de clé empêcherait Android de conserver les données, et le store bloquerait la mise à jour.

## Statistiques

Les événements `view`, `download`, `install` et `update` sont ajoutés dans `stats_events`. Une Cloud Function les agrège dans `stats_rollups` et `stats_daily`, une fois par événement. Le document `devices/{uid}` contient les versions vues sur cet appareil. Ces écritures sont limitées à l’identifiant anonyme. Elles restent déclaratives : un client peut mentir sur son propre document. Le compteur affiché dans le store est `downloadCount`, tenu par l’administration.

## Back-office

L’administration est `darchstorebac`. Les règles autorisent `request.auth.token.admin == true` pour écrire `apps`, `versions` et Storage, et pour lire les mesures. Le claim ne peut pas être posé par un client.

Le bouton « Signaler aux téléphones » appelle `notifyCatalogUpdate`, qui envoie un message de données au topic `darchstore-updates`. L’APK n’est pas dans le message. Le texte affiché à l’utilisateur est calculé par le téléphone après lecture de Firestore.

`firebase deploy --only hosting` publie le build. Les variables `REACT_APP_*` sont figées au moment de `npm run build`.

## Limites

Le store cible Android. L’installation silencieuse n’est pas possible, et elle n’est pas souhaitable : l’utilisateur confirme dans l’écran du système. La taille maximale d’un APK est de 512 Mo. Le catalogue est paginé par 40 applications.
