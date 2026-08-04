# Guía de integración de autenticación para aplicaciones externas

Esta guía explica cómo consumir los flujos de identidad de Original Auth desde una aplicación externa mediante una API key asociada a una aplicación `server_to_server`.

## 1. Arquitectura obligatoria

La API key es una credencial secreta y solamente debe existir en infraestructura controlada por el integrador.

```text
App móvil, desktop o web
          |
          | HTTPS (sin API key)
          v
Backend o BFF del integrador
          |
          | HTTPS + X-API-Key (+ HMAC)
          v
Original Auth /api/v1/integrations/*
```

- No se debe incluir la API key en una aplicación móvil, desktop, SPA, repositorio público o paquete distribuible.
- Estos endpoints no usan callback, redirect URI ni abren un navegador. Reciben JSON y responden JSON.
- Si el cliente no tiene un backend seguro, debe usar el flujo de cliente público para mobile/desktop, no esta integración por API key.
- Todos los accesos deben realizarse mediante HTTPS.

### Alcance del protocolo

Esta es una integración privada de identidad basada en API key y HMAC. No debe presentarse como un flujo OAuth 2.0 u OpenID Connect.

El login directo implica que las credenciales del usuario atraviesan el backend del integrador. Por ello, este modelo debe ofrecerse únicamente a aplicaciones propias o integradores server-to-server expresamente confiables, con controles contractuales y técnicos. Para clientes públicos o integraciones abiertas a terceros se debe usar el flujo mobile/desktop correspondiente y, como evolución futura, OIDC con Authorization Code y PKCE.

## 2. Preparación en el panel

1. Crear una aplicación de tipo `server_to_server`.
2. Crear una API key y asociarla a esa aplicación.
3. Seleccionar únicamente los flujos que utilizará la integración:
   - `Autenticación`
   - `Registro`
   - `Administración de contraseña`
   - `Administración de cuenta`
   - `Alta de usuarios por invitación`
4. Guardar la API key al crearla. El valor completo es secreto y no debe volver a mostrarse.
5. Para producción, configurar IPs permitidas, vencimiento y rotación, y habilitar HMAC.

Cada flujo habilita internamente todos los permisos que necesita. El integrador no tiene que administrar scopes técnicos individuales.

La API key debe pertenecer al mismo ambiente que la API: una key de `test` no funciona en `prod` y viceversa.

## 3. Convenciones generales

En los ejemplos se usan estas variables:

```bash
export AUTH_BASE_URL="https://auth.example.com"
export AUTH_API_KEY="oa_live_REEMPLAZAR"
```

Headers básicos:

```http
Content-Type: application/json
X-API-Key: oa_live_REEMPLAZAR
```

Las respuestas siguen esta forma general:

```json
{
  "success": true,
  "data": {}
}
```

Los errores siguen esta forma general:

```json
{
  "success": false,
  "error": {
    "code": 403,
    "message": "Permisos insuficientes"
  }
}
```

Los nombres y campos adicionales dentro de `data` pueden variar según el endpoint. El cliente debe basar sus decisiones en el código HTTP y en los campos documentados, no en el texto del mensaje.

## 4. Firma HMAC

Si la API key tiene habilitada la opción `require_hmac`, cada petición debe incluir:

```http
X-Timestamp: 1783916400
X-Nonce: 550e8400-e29b-41d4-a716-446655440000
X-Signature: sha256=HEXADECIMAL_DE_LA_FIRMA
```

El timestamp es Unix en segundos. El nonce debe ser aleatorio, único por petición y tener entre 16 y 255 caracteres. Un nonce repetido es rechazado.

La cadena canónica es:

```text
METODO_HTTP
RUTA_Y_QUERY_CANONICA
TIMESTAMP
NONCE
SHA256_DEL_BODY_EXACTO
```

La query canónica ordena las claves alfabéticamente. La firma es `HMAC-SHA256`, usando el valor completo de la API key como secreto.

Ejemplo para Node.js 18 o superior:

```js
import crypto from "node:crypto";

const baseUrl = process.env.AUTH_BASE_URL;
const apiKey = process.env.AUTH_API_KEY;

function canonicalPath(path, query = {}) {
  const params = new URLSearchParams();
  for (const key of Object.keys(query).sort()) {
    const values = Array.isArray(query[key]) ? query[key] : [query[key]];
    for (const value of values) params.append(key, String(value));
  }
  const encoded = params.toString();
  return encoded ? `${path}?${encoded}` : path;
}

async function authRequest(method, path, payload, { userToken, query } = {}) {
  const requestPath = canonicalPath(path, query);
  const body = payload === undefined ? "" : JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = crypto.randomUUID();
  const bodyHash = crypto.createHash("sha256").update(body).digest("hex");
  const canonical = [method.toUpperCase(), requestPath, timestamp, nonce, bodyHash].join("\n");
  const signature = crypto.createHmac("sha256", apiKey).update(canonical).digest("hex");

  const response = await fetch(`${baseUrl}${requestPath}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": apiKey,
      "X-Timestamp": timestamp,
      "X-Nonce": nonce,
      "X-Signature": `sha256=${signature}`,
      ...(userToken ? { "X-User-Token": userToken } : {}),
    },
    ...(body ? { body } : {}),
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(result?.error?.message || "Original Auth rechazó la petición");
    error.status = response.status;
    error.response = result;
    throw error;
  }
  return result;
}
```

Es indispensable firmar exactamente los mismos bytes que se envían. No se debe serializar el objeto una vez para firmarlo y otra vez para transmitirlo.

## 5. Flujo de autenticación

Requiere tener habilitado el flujo `Autenticación`.

### Iniciar sesión

```http
POST /api/v1/integrations/auth/login
```

```json
{
  "email": "usuario@example.com",
  "password": "ContraseñaSegura123!",
  "remember_me": false
}
```

Ejemplo sin HMAC, válido solamente si la key no lo exige:

```bash
curl -X POST "$AUTH_BASE_URL/api/v1/integrations/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AUTH_API_KEY" \
  -d '{"email":"usuario@example.com","password":"ContraseñaSegura123!","remember_me":false}'
```

Si el usuario no requiere MFA, `data` incluye el token de usuario, refresh token y datos de la sesión. El backend del integrador debe guardar estos valores de forma segura.

Si MFA está habilitado para la aplicación y el usuario, el login devuelve un desafío con `challenge_id`. En ese caso todavía no existe una sesión autenticada.

### Verificar MFA

```http
POST /api/v1/integrations/auth/login/verify-mfa
```

```json
{
  "challenge_id": "challenge_recibido_en_login",
  "code": "123456"
}
```

El desafío está ligado a la misma aplicación y API key que lo creó. No puede completarse usando otra integración.

### Cambiar el método del desafío MFA

```http
POST /api/v1/integrations/auth/login/switch-mfa
```

```json
{
  "challenge_id": "challenge_recibido_en_login",
  "new_method_type": "email"
}
```

Solo se puede seleccionar un método disponible para ese usuario y desafío.

### Renovar tokens

```http
POST /api/v1/integrations/auth/refresh
```

```json
{
  "refresh_token": "refresh_token_actual"
}
```

Los refresh tokens rotan: al recibir uno nuevo se debe sustituir el anterior de forma atómica. Reutilizar un refresh token rotado puede revocar la familia completa por seguridad.

### Cerrar sesión

```http
POST /api/v1/integrations/auth/logout
```

```json
{
  "session_id": "session_id_recibido_en_login"
}
```

El cierre es local a esa sesión y aplicación. El endpoint no usa callbacks.

## 6. Flujo de registro

Requiere tener habilitado el flujo `Registro`. La verificación y el reenvío de correo forman parte del mismo flujo.

### Registrar usuario

```http
POST /api/v1/integrations/registration
```

```json
{
  "email": "nuevo@example.com",
  "password": "ContraseñaSegura123!",
  "first_name": "Ana",
  "last_name": "López",
  "language": "es",
  "country": "MX"
}
```

Original Auth envía el correo de validación. La aplicación externa debe mostrar una pantalla indicando que el usuario revise su correo.

### Validar correo

```http
POST /api/v1/integrations/registration/verify-email
```

```json
{
  "token": "token_recibido_en_el_correo"
}
```

El enlace del correo puede dirigir a una página del integrador que extraiga el token y haga esta llamada desde su backend. El token nunca debe registrarse en logs ni servicios de analítica.

### Reenviar validación

```http
POST /api/v1/integrations/registration/resend-verification
```

```json
{
  "email": "nuevo@example.com"
}
```

## 7. Administración de contraseña

Requiere el flujo `Administración de contraseña`.

### Recuperar una contraseña olvidada

Paso 1, solicitar el código:

```http
POST /api/v1/integrations/password/request-reset
```

```json
{
  "email": "usuario@example.com"
}
```

La respuesta es deliberadamente genérica aunque el correo no exista, para evitar enumeración de usuarios.

Paso 2, verificar el código recibido:

```http
POST /api/v1/integrations/password/verify-reset-code
```

```json
{
  "email": "usuario@example.com",
  "code": "123456"
}
```

La respuesta exitosa entrega un `change_token` temporal.

Paso 3, establecer la nueva contraseña:

```http
POST /api/v1/integrations/password/reset
```

```json
{
  "email": "usuario@example.com",
  "change_token": "token_temporal_del_paso_anterior",
  "new_password": "NuevaContraseña123!"
}
```

### Cambiar la contraseña de una sesión autenticada

```http
POST /api/v1/integrations/password/change
X-API-Key: oa_live_REEMPLAZAR
X-User-Token: TOKEN_DEVUELTO_POR_LOGIN
```

```json
{
  "current_password": "ContraseñaActual123!",
  "new_password": "NuevaContraseña123!"
}
```

`X-User-Token` debe proceder de un login de integración, estar activo y pertenecer a la misma aplicación que la API key. Al cambiar o restablecer la contraseña se revocan las sesiones correspondientes; el cliente debe volver a iniciar sesión.

## 8. Administración de cuenta

Requiere el flujo `Administración de cuenta`. Estas operaciones de autoservicio aplican a cuentas de usuario compatibles con el flujo de la aplicación.

### Desactivar la cuenta actual

```http
POST /api/v1/integrations/account/deactivate
X-API-Key: oa_live_REEMPLAZAR
X-User-Token: TOKEN_DEVUELTO_POR_LOGIN
```

```json
{
  "current_password": "ContraseñaActual123!"
}
```

La desactivación revoca las sesiones. Para recuperar la cuenta se debe usar el flujo de reactivación.

### Solicitar reactivación

```http
POST /api/v1/integrations/account/reactivation/request
```

```json
{
  "email": "usuario@example.com"
}
```

### Confirmar reactivación

```http
POST /api/v1/integrations/account/reactivation/confirm
```

```json
{
  "email": "usuario@example.com",
  "code": "123456"
}
```

Después de reactivar la cuenta, el usuario debe iniciar una sesión nueva.

### Eliminar definitivamente la cuenta

```http
DELETE /api/v1/integrations/account/delete
X-API-Key: oa_live_REEMPLAZAR
X-User-Token: TOKEN_DEVUELTO_POR_LOGIN
```

```json
{
  "current_password": "ContraseñaActual123!",
  "confirmation": "DELETE"
}
```

La confirmación distingue mayúsculas y minúsculas. La eliminación es definitiva y no puede revertirse mediante el flujo de reactivación.

## 9. Alta de usuarios por invitación

Este flujo es distinto al registro público. Se usa cuando el sistema externo da de alta al usuario y Original Auth le envía un enlace para establecer su primera contraseña.

Requiere el flujo `Alta de usuarios por invitación`.

### Crear el usuario pendiente

```http
POST /api/v1/integrations/users/provision
```

```json
{
  "first_name": "Ana",
  "last_name": "López",
  "email": "invitada@example.com"
}
```

### Reenviar el enlace para crear contraseña

```http
POST /api/v1/integrations/users/password-bootstrap/resend
```

```json
{
  "email": "invitada@example.com"
}
```

No debe combinarse este flujo con `Registro` para la misma operación:

- `Registro`: el usuario elige la contraseña al registrarse y después valida su correo.
- `Alta por invitación`: el backend crea la cuenta pendiente y el usuario establece su primera contraseña desde el enlace recibido.

## 10. Manejo de errores

| Código | Significado típico | Acción del integrador |
| --- | --- | --- |
| `400` | JSON o datos inválidos | Corregir la solicitud; no reintentar automáticamente |
| `401` | API key, firma o token de usuario inválido/expirado | Revisar credenciales o volver a iniciar sesión |
| `403` | Flujo no habilitado, aplicación incorrecta o cuenta bloqueada | Revisar configuración y estado; no repetir sin cambios |
| `404` | Recurso no disponible | No asumir que el recurso existe |
| `409` | Conflicto de estado, por ejemplo correo ya registrado | Resolver el conflicto antes de repetir |
| `429` | Límite de solicitudes alcanzado | Aplicar espera y backoff; respetar `Retry-After` si está presente |
| `5xx` | Error temporal del servicio | Reintentar con backoff exponencial y límite de intentos |

No se deben reintentar automáticamente operaciones destructivas o no idempotentes como registro, desactivación o eliminación sin comprobar primero el resultado anterior.

## 11. Lista de verificación del integrador para producción

- Todas las solicitudes se envían a la URL HTTPS proporcionada por Original Auth.
- La API key vive únicamente en un secret manager o variable segura del backend.
- La aplicación asociada es `server_to_server` y está activa.
- La key corresponde al ambiente correcto y tiene fecha de expiración.
- Solo están habilitados los flujos realmente necesarios.
- Se configuraron IPs permitidas cuando la infraestructura usa egresos estables.
- HMAC está habilitado para reducir el riesgo de manipulación y replay.
- El reloj del servidor está sincronizado mediante NTP.
- Los timeouts HTTP son acotados y los reintentos usan backoff.
- API keys, contraseñas, códigos MFA, tokens de correo, access tokens y refresh tokens se excluyen de logs, trazas y analítica.
- La aplicación no revela al usuario detalles internos de errores `401` o `403`.
- Existe un procedimiento de rotación y revocación de API keys.
- Los tokens se eliminan del almacenamiento local cuando una sesión termina, una contraseña cambia o una cuenta se desactiva.

## 12. Resumen de endpoints

| Flujo | Método | Endpoint | Requiere `X-User-Token` |
| --- | --- | --- | --- |
| Autenticación | `POST` | `/api/v1/integrations/auth/login` | No |
| Autenticación | `POST` | `/api/v1/integrations/auth/login/verify-mfa` | No |
| Autenticación | `POST` | `/api/v1/integrations/auth/login/switch-mfa` | No |
| Autenticación | `POST` | `/api/v1/integrations/auth/refresh` | No |
| Autenticación | `POST` | `/api/v1/integrations/auth/logout` | No |
| Registro | `POST` | `/api/v1/integrations/registration` | No |
| Registro | `POST` | `/api/v1/integrations/registration/verify-email` | No |
| Registro | `POST` | `/api/v1/integrations/registration/resend-verification` | No |
| Contraseña | `POST` | `/api/v1/integrations/password/request-reset` | No |
| Contraseña | `POST` | `/api/v1/integrations/password/verify-reset-code` | No |
| Contraseña | `POST` | `/api/v1/integrations/password/reset` | No |
| Contraseña | `POST` | `/api/v1/integrations/password/change` | Sí |
| Cuenta | `POST` | `/api/v1/integrations/account/deactivate` | Sí |
| Cuenta | `POST` | `/api/v1/integrations/account/reactivation/request` | No |
| Cuenta | `POST` | `/api/v1/integrations/account/reactivation/confirm` | No |
| Cuenta | `DELETE` | `/api/v1/integrations/account/delete` | Sí |
| Alta por invitación | `POST` | `/api/v1/integrations/users/provision` | No |
| Alta por invitación | `POST` | `/api/v1/integrations/users/password-bootstrap/resend` | No |

Todas las rutas de esta tabla requieren `X-API-Key`. Si la key exige HMAC, también requieren `X-Timestamp`, `X-Nonce` y `X-Signature`.
