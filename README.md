# Intervalos para iPhone

Proyecto SwiftUI preparado para generar con XcodeGen y compilar en macOS.

## Generar el proyecto

1. Instala Xcode y XcodeGen en un Mac: `brew install xcodegen`.
2. Desde esta carpeta ejecuta `xcodegen generate`.
3. Abre `IntervalosCasa.xcodeproj` con Xcode.
4. En **Signing & Capabilities**, selecciona tu equipo de Apple Developer.
5. Conecta el iPhone y pulsa **Run**, o usa **Product > Archive** para exportar un `.ipa`.

La aplicación usa `AVAudioSession.Category.ambient`. Así, los pitidos se mezclan con Spotify, Apple Music u otra aplicación que esté reproduciendo audio, sin detenerla.

El `.ipa` no se incluye porque Apple exige compilar y firmar en macOS con el certificado y el perfil de aprovisionamiento de la cuenta que instalará o distribuirá la aplicación.

## Compilar automáticamente con GitHub

El repositorio incluye `.github/workflows/build-ipa.yml`. Cada subida a `main` inicia un servidor macOS de GitHub, genera el proyecto con XcodeGen, compila la aplicación y publica `Intervalos.ipa` como artefacto descargable.

En GitHub abre **Actions → Compilar IPA → última ejecución → Artifacts → Intervalos-IPA**. El IPA resultante no está firmado y está preparado para firmarlo e instalarlo con Sideloadly.
