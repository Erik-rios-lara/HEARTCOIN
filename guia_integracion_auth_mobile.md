# Guia de integracion de OriginalAuth en aplicaciones mobile

Esta guia explica como conectar una aplicacion Android o iOS nueva con OriginalAuth.
El flujo implementado es OAuth 2.0 Authorization Code con PKCE `S256`. Mobile es
un **public client**: utiliza `client_id`, pero nunca lleva un `client_secret`, API
key ni `token_app` secreto dentro de la aplicacion.

> Los endpoints `/api/*` legacy no forman parte de esta integracion. Las apps
> nuevas deben usar exclusivamente `/api/v1/*`.

## 1. Que debe preparar el integrador

Necesita:

- URL base de OriginalAuth para el ambiente correspondiente.
- Una aplicacion de tipo `mobile` creada desde el panel.
- El `client_id` que muestra el detalle de la aplicacion.
- Un `redirect_uri` registrado exactamente como lo enviara la app.
- Las funciones permitidas seleccionadas en la configuracion de la app.
- La politica MFA de la app, configurada en la seccion MFA del panel.

Las funciones se muestran con nombres como **Iniciar sesion**, **Registro**,
**Recuperar contrasena**, **Consultar perfil** y **Cerrar sesion**. Internamente,
OriginalAuth limita los scopes del token a esas funciones. MFA no es un scope:
es una regla aplicada al login de esa aplicacion.

## 2. Crear y configurar la aplicacion

1. Entrar al panel de OriginalAuth.
2. Abrir **Aplicaciones** y seleccionar **Crear aplicacion**.
3. Elegir el tipo **Mobile - public client + PKCE**.
4. Capturar el nombre, ambiente y `redirect_uri`.
5. Seleccionar las funciones que utilizara la aplicacion.
6. Crear la aplicacion y copiar su `client_id`.
7. Si se requiere MFA, abrir la configuracion de la app, entrar a **MFA** y
   habilitar correo, SMS, TOTP o biometria segun el plan disponible.

No se debe copiar `token_app`, secretos web ni credenciales administrativas al
codigo mobile.

## 3. De donde se obtiene el redirect o link

El redirect **no lo entrega OriginalAuth**. Lo define el desarrollador mobile y
luego lo registra en el panel. Hay dos opciones.

### Opcion recomendada: App Link o Universal Link HTTPS

Ejemplo:

```text
https://login.cliente.com/oauth/callback
```

El cliente necesita un dominio que controle y acceso para publicar dos archivos.

#### Android App Links

Datos necesarios:

- `package_name`, por ejemplo `com.empresa.app`, definido en Gradle/Manifest.
- Huella SHA-256 del certificado que firma la app.

La huella de produccion se obtiene en Google Play Console, en **Integridad de la
aplicacion / Firma de aplicaciones**, o localmente con:

```bash
keytool -list -v -keystore mi-release-key.jks -alias mi_alias
```

El dominio debe servir sin redireccion este archivo:

```text
https://login.cliente.com/.well-known/assetlinks.json
```

Ejemplo:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.empresa.app",
      "sha256_cert_fingerprints": ["AA:BB:CC:...:FF"]
    }
  }
]
```

En `AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="login.cliente.com"
        android:pathPrefix="/oauth/callback" />
</intent-filter>
```

#### iOS Universal Links

Datos necesarios:

- Bundle Identifier, por ejemplo `com.empresa.app`, disponible en Xcode.
- Team ID de Apple, disponible en la cuenta Apple Developer, seccion Membership.

El dominio debe servir este archivo, sin extension y sin redireccion:

```text
https://login.cliente.com/.well-known/apple-app-site-association
```

Ejemplo:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID1234.com.empresa.app"],
        "components": [{ "/": "/oauth/callback" }]
      }
    ]
  }
}
```

En Xcode se agrega la capability **Associated Domains**:

```text
applinks:login.cliente.com
```

### Alternativa cuando el cliente no tiene dominio: esquema privado

Se construye normalmente a partir del Bundle ID o package name en dominio inverso:

```text
com.empresa.app:/oauth/callback
```

No hay que comprar ni solicitar ese link a OriginalAuth. El desarrollador elige
un esquema suficientemente unico, lo declara en Android/iOS y registra la misma
URL exacta en el panel. Esta opcion es menos resistente a que otra app reclame el
mismo esquema; para produccion se prefieren enlaces HTTPS verificados.

## 4. Flujo completo

```text
App genera state + code_verifier
  -> calcula code_challenge SHA-256
  -> abre /api/v1/auth/oauth/authorize en navegador del sistema
  -> OriginalAuth muestra login/registro/recuperacion
  -> aplica verificacion de correo y MFA configurado para la app
  -> redirige al redirect_uri con code + state
  -> app valida state
  -> app canjea code + code_verifier en /oauth/token
  -> recibe access_token + refresh_token
```

La app cliente no llama directamente a `register`, `login` o `verify-mfa` ni
captura la contrasena. Esos pasos ocurren en el navegador de OriginalAuth. La app
solo inicia la autorizacion, recibe el callback y canjea el codigo.

## 5. PKCE y solicitud de autorizacion

Por cada intento se deben generar valores nuevos:

- `code_verifier`: aleatorio criptografico, entre 43 y 128 caracteres Base64URL.
- `code_challenge`: `BASE64URL(SHA256(code_verifier))`, sin `=`.
- `state`: aleatorio criptografico de al menos 16 caracteres.

Ejemplo de URL (todos los parametros deben codificarse):

```text
GET {AUTH_BASE_URL}/api/v1/auth/oauth/authorize
  ?response_type=code
  &client_id=cli_xxx
  &redirect_uri=com.empresa.app%3A%2Foauth%2Fcallback
  &code_challenge=CHALLENGE
  &code_challenge_method=S256
  &state=STATE
  &scope=profile%3Aread%20sessions%3Aself%3Arefresh%20sessions%3Aself%3Alogout
```

Solo se deben solicitar scopes correspondientes a funciones habilitadas en el
panel. Si se solicita uno no permitido, OriginalAuth responde `invalid_scope`.

## 6. Ejemplo Android con Kotlin

```kotlin
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

private fun randomBase64Url(bytes: Int): String {
    val value = ByteArray(bytes)
    SecureRandom().nextBytes(value)
    return Base64.getUrlEncoder().withoutPadding().encodeToString(value)
}

private fun sha256Base64Url(value: String): String {
    val digest = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.US_ASCII))
    return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
}

val verifier = randomBase64Url(64)
val challenge = sha256Base64Url(verifier)
val state = randomBase64Url(32)

// Guardar temporalmente verifier y state para validar el callback.
val authorizeUrl = Uri.parse("$authBaseUrl/api/v1/auth/oauth/authorize")
    .buildUpon()
    .appendQueryParameter("response_type", "code")
    .appendQueryParameter("client_id", clientId)
    .appendQueryParameter("redirect_uri", redirectUri)
    .appendQueryParameter("code_challenge", challenge)
    .appendQueryParameter("code_challenge_method", "S256")
    .appendQueryParameter("state", state)
    .appendQueryParameter("scope", "profile:read sessions:self:refresh sessions:self:logout")
    .build()

CustomTabsIntent.Builder().build().launchUrl(context, authorizeUrl)
```

Al recibir el App Link/deep link:

```kotlin
val code = intent.data?.getQueryParameter("code")
val returnedState = intent.data?.getQueryParameter("state")
require(code != null && returnedState == savedState) { "Callback OAuth invalido" }
// Canjear inmediatamente code usando savedVerifier.
```

## 7. Ejemplo iOS con Swift

```swift
import AuthenticationServices
import CryptoKit

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let verifier = base64URL(Data((0..<64).map { _ in UInt8.random(in: 0...255) }))
let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
let state = base64URL(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))

var components = URLComponents(string: "\(authBaseURL)/api/v1/auth/oauth/authorize")!
components.queryItems = [
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "client_id", value: clientID),
    URLQueryItem(name: "redirect_uri", value: redirectURI),
    URLQueryItem(name: "code_challenge", value: challenge),
    URLQueryItem(name: "code_challenge_method", value: "S256"),
    URLQueryItem(name: "state", value: state),
    URLQueryItem(name: "scope", value: "profile:read sessions:self:refresh sessions:self:logout")
]

let session = ASWebAuthenticationSession(
    url: components.url!,
    callbackURLScheme: "com.empresa.app"
) { callbackURL, error in
    guard error == nil,
          let callbackURL,
          let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
          callback.queryItems?.first(where: { $0.name == "state" })?.value == state,
          let code = callback.queryItems?.first(where: { $0.name == "code" })?.value
    else { return }
    // Canjear code con verifier inmediatamente.
}
session.prefersEphemeralWebBrowserSession = false
session.start()
```

Con Universal Links, la recepcion tambien puede manejarse mediante
`application(_:continue:restorationHandler:)` o `onOpenURL`, segun la arquitectura
de la app.

## 8. Canjear el authorization code

El `redirect_uri` debe ser exactamente el mismo usado en authorize:

```http
POST {AUTH_BASE_URL}/api/v1/auth/oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "CODE_RECIBIDO",
  "client_id": "cli_xxx",
  "redirect_uri": "com.empresa.app:/oauth/callback",
  "code_verifier": "VERIFIER_ORIGINAL"
}
```

Respuesta:

```json
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "...",
  "scope": "profile:read sessions:self:refresh sessions:self:logout"
}
```

El code es temporal y de un solo uso. No se debe reintentar el mismo code si el
servidor confirma que fue consumido.

## 9. Usar, renovar y cerrar la sesion

Para endpoints protegidos:

```http
Authorization: Bearer ACCESS_TOKEN
```

Renovacion:

```http
POST {AUTH_BASE_URL}/api/v1/auth/refresh
Content-Type: application/json

{ "refresh_token": "REFRESH_TOKEN_ACTUAL" }
```

El refresh token es rotatorio: cuando la respuesta entregue uno nuevo, se debe
reemplazar el anterior de forma atomica.

Logout:

```http
POST {AUTH_BASE_URL}/api/v1/auth/logout
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{ "scope": "local" }
```

`local` cierra esa sesion. `global` debe reservarse para la accion explicita de
cerrar todas las sesiones del usuario.

## 10. Almacenamiento seguro

- iOS: guardar refresh token en Keychain.
- Android: usar Android Keystore mediante almacenamiento cifrado.
- Mantener access token en memoria cuando sea posible.
- Nunca guardar tokens, verifier, codes o contrasenas en logs, analytics, URLs de
  terceros, crash reports o almacenamiento plano.
- Limpiar tokens locales aunque el logout remoto falle; posteriormente se puede
  reintentar la revocacion.

## 11. Registro, recuperacion y MFA

El navegador de OriginalAuth ofrece las opciones habilitadas para la app:

- **Registro** incluye alta, envio de correo y verificacion de cuenta.
- **Recuperacion de contrasena** incluye solicitud, codigo y cambio final.
- **MFA** se ejecuta despues de validar las credenciales cuando la configuracion
  de la aplicacion o la cuenta lo exige.

Al completar cualquiera de estos pasos, OriginalAuth conserva la transaccion y
reanuda el mismo authorize; la app finalmente recibe `code` y `state`. El cliente
mobile no tiene que reconstruir el flujo ni implementar endpoints MFA internos.

## 12. Errores que la app debe manejar

El callback puede contener:

```text
redirect_uri?error=access_denied&state=STATE
```

Reglas:

- Validar `state` tanto en exito como en error.
- Si falta `state` o no coincide, descartar completamente el callback.
- `invalid_scope`: revisar funciones habilitadas y scopes solicitados.
- `invalid_request`: revisar `client_id`, PKCE y coincidencia exacta del redirect.
- `access_denied`: el usuario cancelo, la cuenta no puede acceder o una politica
  impidio la autorizacion.
- Permitir que el usuario inicie un flujo nuevo; no reutilizar verifier/state.

## 13. Checklist antes de publicar

- [ ] La app fue creada como `mobile` y tiene el `client_id` correcto por ambiente.
- [ ] El redirect registrado coincide caracter por caracter.
- [ ] Se usa navegador del sistema, no WebView embebido.
- [ ] PKCE usa `S256` y aleatoriedad criptografica.
- [ ] `state` se valida antes de usar el code.
- [ ] No existe client secret o API key dentro de la app.
- [ ] App/Universal Link esta verificado en dispositivos reales.
- [ ] Refresh token esta en Keychain/Keystore y se rota correctamente.
- [ ] Login, registro, verificacion, recuperacion y MFA fueron probados segun las
      funciones habilitadas.
- [ ] Logout elimina credenciales locales y revoca la sesion remota.

