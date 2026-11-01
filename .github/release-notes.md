## Descargas

| Sistema | Archivo | Cómo usarlo |
|---|---|---|
| **Android 10+** | `cuota-android.apk` | Instálalo y autoriza la VPN al iniciar el proxy |
| **Linux x64** | `cuota-linux-x64.tar.gz` | Descomprime y ejecuta `bundle/cuota` |
| **Windows x64** | `cuota-windows-x64.zip` | Descomprime todo y ejecuta `cuota.exe` |

`SHA256SUMS.txt` permite comprobar que las descargas están íntegras.

**Requisitos en Linux:** el programa `cntlm` en el `PATH`, `libayatana-appindicator3`, `libsecret` y un servicio de llavero, como `gnome-keyring`. En Windows y Android, `cntlm` ya va incluido.

## Qué probar

Esta versión es para pruebas, sobre todo en **Windows**, que no se había probado.

1. Crea un perfil con tu cuenta en **Cuenta** y revisa el servidor.
2. Inicia el proxy y comprueba que navegas y que aparece tu cuota.
3. En Android, comprueba que el tráfico del teléfono pasa por el túnel.
4. Detén el proxy y vuelve a iniciarlo.

## Si algo falla

Abre **⋯ → Ver registro**, pulsa **Exportar .txt** antes de cerrar la app y adjunta el archivo en un [issue](https://github.com/kurokykun/cuota/issues). Revísalo antes de compartirlo: oculta tu usuario, contraseña y hashes, pero en Android puede incluir sitios rechazados por el proxy.

## Avisos

- El APK está firmado con una clave de pruebas: al instalar una versión futura quizá tengas que desinstalar la anterior.
- Windows puede avisar de que el programa no está firmado.
- `cntlm` se distribuye bajo GPLv2; su código está en [versat/cntlm](https://github.com/versat/cntlm).
