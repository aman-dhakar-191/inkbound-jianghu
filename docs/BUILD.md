# Building and releasing

The game ships through the private app store
([aman-dhakar-191/private-app-store](https://github.com/aman-dhakar-191/private-app-store)),
not Google Play. The store reads this repo's latest GitHub release and
installs its APK. Its rules are in
[publishing-an-app.md](https://github.com/aman-dhakar-191/private-app-store/blob/main/docs/publishing-an-app.md);
the workflows here follow them.

| Store rule | How this repo meets it |
|---|---|
| Public repo | This repo is public. |
| Each version is a GitHub release with one `.apk` | `Release` workflow attaches one universal APK (arm64 + armv7). |
| Tag matches `versionName` | Tag `v1.2.3`, `version/name="1.2.3"`, set by the workflow. |
| `versionCode` always goes up | `major × 1000000 + minor × 1000 + patch` (`scripts/next-version.sh`). |
| Same signing key every release | Key comes from repo secrets; the workflow fails if the APK has a debug signature. |
| Package matches `catalog.json` | `io.github.amandhakar.jianghuchain` in `export_presets.cfg`. Never change it. |

## One-time setup: signing key

You can reuse the store's key (same alias and passwords) or make a new one.
Android only installs an update signed with the same key as the installed
copy, so keep it forever.

```sh
keytool -genkeypair -v -keystore release.jks -alias appstore \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 release.jks   # copy the output
```

Godot signs with a single password, so the keystore password and the key
password must be the same. keytool's default (PKCS12) keystore does this
for you.

In this repo on GitHub: **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | the base64 output above |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `appstore` (or your alias) |

Never commit `release.jks`.

## Each release

1. Merge to `main`.
2. **Actions → Release → Run workflow**, pick `patch`, `minor` or `major`.
   The first release starts from `0.0.0`, so pick **minor** for `0.1.0`.
3. A few minutes later the store shows it on the next refresh.

## Test builds

The `CI` workflow runs on every pull request and on `main`:

1. checks the story data and the version script;
2. runs the core unit tests and a scripted Chapter 1 playthrough in headless Godot;
3. fails on any Godot script error;
4. exports a debug-signed APK, kept as the `jianghu-chain-dev-apk` artifact.

The test APK can be installed on a phone for a quick look, but it uses a
throwaway key, so uninstall it before installing from the store.

## Godot version

CI uses the Godot version set in `.github/actions/setup-godot/action.yml`
(`version` input). Use the same version in the editor on your computer.
