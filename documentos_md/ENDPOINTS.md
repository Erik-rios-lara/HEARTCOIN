# Endpoints — HeartCoin

HeartCoin no tiene un backend propio con rutas custom: usa **Supabase** como backend completo. Esto significa que la "API" real de la app son los endpoints que Supabase genera automáticamente:

1. **Auth** (`/auth/v1/*`) — manejado internamente por el SDK `supabase_flutter`, no se llama a mano.
2. **PostgREST** (`/rest/v1/<tabla>`) — un endpoint REST autogenerado por cada tabla de Postgres, con los verbos permitidos según las políticas RLS de esa tabla. Es lo que el código llama vía `Supabase.instance.client.from('tabla')...`.
3. **RPC** (`/rest/v1/rpc/<función>`) — funciones de Postgres expuestas como endpoint, llamadas vía `.rpc('nombre', params: {...})`. Es el único camino de escritura para las tablas que necesitan validar reglas de negocio (geolocalización, balance de HC) que RLS no puede expresar.
4. **Realtime** (WebSocket) — el mismo mecanismo de PostgREST pero en vivo, vía `.stream()`.
5. **Edge Functions** (`/functions/v1/<nombre>`) — los únicos endpoints verdaderamente custom del proyecto: `upload-media` y `delete-account`.

Este documento lista lo que existe **hoy**. Base URL: `https://bamrvwzpcqwoyuwbvomw.supabase.co`.

---

## 1. Autenticación

Vía `AuthService` ([lib/services/auth_service.dart](lib/services/auth_service.dart)), que envuelve al SDK.

| Acción | Método del SDK | Notas |
|---|---|---|
| Registro | `_client.auth.signUp(email, password, data: {'role': ...})` | El rol se guarda en `user_metadata.role`. Confirmación de correo **desactivada** en el proyecto. |
| Login | `_client.auth.signInWithPassword(email, password)` | Devuelve el `UserRole` leído de `user_metadata`. |
| Logout | `_client.auth.signOut()` | |
| Rol actual | `_client.auth.currentUser?.userMetadata?['role']` | Sin llamada de red, se lee de la sesión local. |

No hay verificación por teléfono, OAuth social, ni recuperación de contraseña implementada en la UI todavía.

---

## 2. Edge Function: `upload-media`

**`POST /functions/v1/upload-media`** — proxy de subida a MediaAAS. Código: [supabase/functions/upload-media/index.ts](supabase/functions/upload-media/index.ts).

- **Auth requerida:** sesión de Supabase válida (`Authorization: Bearer <access_token>` del usuario, no la anon key). La función valida al usuario con `supabase.auth.getUser()` antes de continuar.
- **Body:** `multipart/form-data` con:
  - `file` (binario, requerido)
  - `file_name` (string, requerido)
- **Respuesta 200:**
  ```json
  { "image_url": "https://getfile.media-as-a-service.io/public/...", "file_id": 123 }
  ```
- **Respuesta 401:** usuario no autenticado.
- **Respuesta 422:** falta `file` o `file_name`.
- **Respuesta 502:** MediaAAS rechazó la subida (revisar `detail` en el body).
- **Cliente Dart:** [lib/services/media_service.dart](lib/services/media_service.dart) — arma el `multipart/form-data` con `http.MultipartFile.fromBytes`, detectando el `Content-Type` real vía el paquete `mime` (si no se especifica, MediaAAS rechaza el archivo con `application/octet-stream`).
- Las credenciales de MediaAAS (`MEDIAAS_API_HOST`, `MEDIAAS_API_KEY`, `MEDIAAS_SECRET_KEY`) viven como **secrets de la Edge Function**, nunca en el cliente.

---

## 2b. Edge Function: `delete-account`

**`POST /functions/v1/delete-account`** — borra permanentemente la cuenta del usuario autenticado. Código: [supabase/functions/delete-account/index.ts](supabase/functions/delete-account/index.ts).

- **Auth requerida:** sesión de Supabase válida (`Authorization: Bearer <access_token>`). La función valida al usuario con un cliente anon (`supabase.auth.getUser()`) y luego usa un cliente **admin** (con `SUPABASE_SERVICE_ROLE_KEY`, inyectada automáticamente por Supabase en el entorno de la función — no es un secret manual) para llamar `auth.admin.deleteUser(userId)`.
- **Body:** ninguno (el usuario a borrar es siempre el de la sesión, nunca un id enviado por el cliente).
- **Respuesta 200:** `{ "ok": true }`.
- **Respuesta 401:** usuario no autenticado.
- **Respuesta 500:** falló el borrado en Supabase Auth (`detail` en el body).
- **Cliente Dart:** [lib/services/account_service.dart](lib/services/account_service.dart), usado por `delete_account_screen.dart`.
- **Por qué no hace falta limpiar tablas manualmente:** todas las FK del esquema hacia `auth.users` tienen `ON DELETE CASCADE` (verificado vía `pg_constraint`), así que borrar la fila en `auth.users` arrastra automáticamente perfil, publicaciones, HC, votos, check-ins, seguidores, bloqueos, etc.

---

## 2.1 Funciones RPC (`/rest/v1/rpc/<función>`)

Todas son `SECURITY DEFINER`, usan `auth.uid()` internamente (el cliente nunca envía de quién es la acción) y son el **único** camino de escritura para su tabla — no existe policy de `INSERT` directa para el cliente en `iniciativa_checkins`, `beneficio_redemptions` ni `servicio_redemptions`.

| Función | Parámetros | Qué valida | Cliente |
|---|---|---|---|
| `checkin_iniciativa` | `p_iniciativa_id uuid`, `p_lat double precision`, `p_lng double precision` | `verification_method = 'qr'`, hora actual dentro de `event_date` + `verification_window_hours`, distancia haversine ≤ 200m a `latitude`/`longitude` de la iniciativa. Inserta en `iniciativa_checkins`. | `checkin_service.dart` |
| `redeem_beneficio` | `p_beneficio_id uuid` | Beneficio `activo`, no canjeado antes por este usuario, no supera `max_redemptions`. Si es `cashback` acredita `hc_reward`; si es descuento/beca valida `hc_balance >= hc_cost` y lo descuenta. Inserta en `hc_transactions` + `beneficio_redemptions`, actualiza `redemptions_count`. | `beneficio_service.dart` |
| `redeem_servicio` | `p_servicio_id uuid` | Misma lógica que `redeem_beneficio`, usando `pricing_type` (`costo`/`cashback`) de `servicios` en vez de `benefit_type`. Inserta en `hc_transactions` + `servicio_redemptions`, actualiza `redemptions_count`. | `servicio_service.dart` |

Errores conocidos que estas funciones pueden lanzar (mapeados a mensajes amigables en el cliente): `iniciativa_no_encontrada` / `beneficio_no_encontrado` / `servicio_no_encontrado`, `metodo_no_es_qr`, `fuera_de_horario`, `fuera_de_rango`, `sin_ubicacion_registrada`, `sin_fecha_evento`, `beneficio_inactivo` / `servicio_inactivo`, `limite_alcanzado`, `hc_insuficiente`, y el conflicto de clave primaria cuando ya existe el check-in/canje (`ya_canjeado`).

El escáner de la billetera (`beneficio_scanner_screen.dart`) recibe cualquier código QR y prueba primero `fetchBeneficio()`; si no existe, prueba `fetchServicio()` — así un mismo flujo de cámara cubre ambos tipos de canje sin que el usuario tenga que elegir de antemano qué está escaneando.

---

## 3. MediaAAS (servicio externo detrás de `upload-media`)

Guía completa: [mediaas-client-api-guide.md](mediaas-client-api-guide.md). Base URL: `https://getfile.media-as-a-service.io`. Todos los endpoints van bajo `/client/` y requieren tres headers firmados con HMAC-SHA256 (`X-Api-Key`, `X-Timestamp`, `X-Signature`) — ver la guía para el algoritmo de firma exacto.

| Endpoint | Método | Uso en HeartCoin |
|---|---|---|
| `/client/upload` | `POST` | **El único que usamos.** Sube el archivo (`multipart/form-data`), marcado siempre `is_public=true`. Llamado únicamente desde la Edge Function `upload-media`, nunca directo desde la app. |
| `/client/files/` | `GET` | Lista archivos del cliente en MediaAAS. No se usa en la app (no hay pantalla de "mis archivos subidos"). |
| `/client/media/{s3_key}` | `GET` | Genera una URL firmada temporal para un archivo privado. No se usa — todo lo que subimos es `is_public=true`, así que se sirve directo por `public_url` sin necesidad de firmar cada lectura. |
| `/client/folders/` | `POST` | Crea una carpeta en MediaAAS. No se usa — los archivos caen en la carpeta automática "Uploads API". |
| `/client/files/{file_id}` | `PATCH` | Actualiza metadatos (nombre, visibilidad) de un archivo. No se usa — no hay UI para renombrar u ocultar imágenes ya subidas. |
| `/client/files/{file_id}` | `DELETE` | Borra un archivo de MediaAAS. No se usa todavía. Solo `publicaciones.image_file_id` guarda el `file_id` devuelto por la subida (para poder borrar el archivo remoto cuando se implemente borrar una publicación); `iniciativas.image_url` y `votaciones.image_url` no guardan su `file_id` correspondiente. |

**Webhooks de MediaAAS** (`file.uploaded`, `file.updated`, `file.deleted`): no configurados — la app no tiene un `callback_url` receptor para ellos.

---

## 4. Tablas expuestas vía PostgREST

Cada tabla es un endpoint `/rest/v1/<tabla>` que soporta `GET`/`POST`/`PATCH`/`DELETE` (según la operación equivalente a `select`/`insert`/`update`/`delete` del SDK), filtrado por las policies RLS listadas.

### Perfiles

| Tabla | Quién puede leer | Quién puede insertar/actualizar | Usado en |
|---|---|---|---|
| `personal_profiles` | Cualquier autenticado, solo si `is_public = true` (nombre/ciudad/avatar/bio); dueño ve todo su registro, incluyendo `hc_balance` | Solo el propio usuario (`id = auth.uid()`); `hc_balance` además se actualiza vía trigger desde `hc_transactions`, nunca directo desde el cliente | `auth_service.dart`, `profile_screen.dart`, `user_profile_screen.dart`, `community_service.dart`, `wallet_service.dart`, `edit_profile_screen.dart` |
| `blocked_users` | Solo los propios bloqueos (`user_id = auth.uid()`) | Insertar/borrar solo con `user_id` propio; constraint `blocked_users_no_self_block` impide bloquearse a sí mismo | `block_service.dart`, `home_people_screen.dart`, `user_profile_screen.dart`, `blocked_users_screen.dart` |
| `organization_profiles` | Solo el propio usuario (`auth.uid() = id`) | Solo el propio usuario | `auth_service.dart`, `home_organization_screen.dart`. El nombre se expone públicamente solo de forma denormalizada vía `iniciativas.organization_name` |
| `company_profiles` | Solo el propio usuario (`auth.uid() = id`) | Solo el propio usuario | `auth_service.dart`, `home_company_screen.dart`. El nombre se expone públicamente solo de forma denormalizada vía `beneficios.company_name` |

### Feed social

| Tabla | Lectura | Escritura | Usado en |
|---|---|---|---|
| `publicaciones` | Público | Insertar/editar/borrar solo el autor (`author_id = auth.uid()`) | `create_post_screen.dart`, `home_people_screen.dart`, `profile_screen.dart` |
| `post_likes` | Público | Insertar/borrar solo con `user_id = auth.uid()` propio | `social_service.dart` |
| `comments` | Público | Insertar solo con `author_id = auth.uid()` propio (sin editar/borrar aún) | `social_service.dart`, `comments_sheet.dart` |
| `comment_likes` | Público | Insertar/borrar solo con `user_id` propio | `social_service.dart` |
| `follows` | Público | Insertar/borrar solo con `follower_id` propio | `follow_service.dart`, `follow_button.dart` (feed y detalle de iniciativa) |
| `notifications` | Solo las del propio usuario (`user_id = auth.uid()`) | Solo `UPDATE` (marcar leída) por el propio usuario; el `INSERT` lo hacen triggers internos, no el cliente — y cada trigger respeta `notify_likes`/`notify_comments`/`notify_replies` del destinatario en `personal_profiles` (no inserta si el usuario desactivó ese tipo) | `notification_service.dart`, `notification_preferences_screen.dart` |
| `saved_items` | Solo las propias (`user_id = auth.uid()`) | Insertar/borrar solo con `user_id` propio | `saved_items_service.dart`, `save_button.dart` (tarjetas y detalle de iniciativas/votaciones) |

### Iniciativas y votaciones

| Tabla | Lectura | Escritura | Usado en |
|---|---|---|---|
| `iniciativas` | Público solo si `status='activa'`; el autor ve las suyas en cualquier estado | Insertar solo con `author_id` propio; `UPDATE` también solo el autor (`edit_org_iniciativa_screen.dart`). `organization_name` se sincroniza solo, no se puede escribir directo (trigger sobre `author_id`) | `explore_screen.dart`, `iniciativas_by_category_screen.dart`, `org_iniciativas_screen.dart`, `create_iniciativa_ahorro_screen.dart`, `edit_org_iniciativa_screen.dart` |
| `iniciativa_votes` | Público | Insertar solo con `user_id` propio (sin `DELETE`, el apoyo es definitivo) | `iniciativas_service.dart` |
| `iniciativa_checkins` | Público | **Sin policy de `INSERT` para el cliente** — solo vía la función `checkin_iniciativa()` | `checkin_service.dart` |
| `proveedores` | Público | Sin policy de escritura para el cliente (solo se siembra por SQL) | `create_iniciativa_ahorro_screen.dart` |
| `votaciones` | Público | Sin policy de escritura para el cliente (solo se siembra por SQL; no hay UI de creación todavía) | `votaciones_service.dart` |
| `votacion_votes` | Público | Insertar solo con `user_id` propio, con constraint única (`votacion_id`, `user_id`) que impide votar dos veces (sin `DELETE`) | `votaciones_service.dart` |
| `votacion_comments` | Público | Insertar solo con `author_id` propio (sin editar/borrar aún) | `votacion_comments_service.dart` |

### HeartCoin (HC), beneficios y servicios

| Tabla | Quién puede leer | Quién puede insertar/actualizar | Usado en |
|---|---|---|---|
| `hc_transactions` | Solo las propias (`user_id = auth.uid()`); una empresa también puede leer las transacciones ligadas a sus propios beneficios/servicios (`reference_type='beneficio'\|'servicio'` + `company_id = auth.uid()` en la tabla correspondiente) | **Sin policy de `INSERT`/`UPDATE` para el cliente** — se escribe desde `redeem_beneficio()`/`redeem_servicio()`, y automáticamente vía triggers `AFTER INSERT` en `votacion_votes` (tipo `voto`, monto = `votaciones.hc_reward`) y en `iniciativa_checkins` (tipo `checkin`, monto = `iniciativas.hc_reward`) | `wallet_service.dart`, `company_dashboard_service.dart` |
| `beneficios` | Público solo si `status='activo'`; la empresa ve los suyos en cualquier estado | Insertar/`UPDATE` solo la empresa dueña (`company_id = auth.uid()`); `company_name` se sincroniza solo (trigger sobre `company_id`) | `beneficio_service.dart`, `company_beneficios_screen.dart`, `create_beneficio_screen.dart`, `wallet_screen.dart` |
| `beneficio_redemptions` | El usuario ve las propias; la empresa ve las de sus propios beneficios | **Sin policy de `INSERT` para el cliente** — solo vía la función `redeem_beneficio()` | `beneficio_service.dart` |
| `servicios` | Público solo si `status='activo'`; la empresa ve los suyos en cualquier estado | Insertar/`UPDATE` solo la empresa dueña (`company_id = auth.uid()`); `company_name` se sincroniza solo (trigger sobre `company_id`) | `servicio_service.dart`, `company_servicios_screen.dart`, `create_servicio_screen.dart`, `explore_screen.dart` |
| `servicio_redemptions` | El usuario ve las propias; la empresa ve las de sus propios servicios | **Sin policy de `INSERT` para el cliente** — solo vía la función `redeem_servicio()` | `servicio_service.dart` |

### Notas sobre las policies

- Todas las tablas tienen RLS **habilitado**; si una tabla no aparece con policy de `INSERT`/`UPDATE`/`DELETE` para el rol `authenticated`, esa operación está bloqueada para el cliente aunque el usuario tenga sesión — solo se puede hacer con la Service Role Key (fuera de la app, ej. scripts de siembra).
- Los contadores (`likes_count`, `comments_count`, `votes_count`) **nunca se escriben desde el cliente**: los actualizan triggers de Postgres (`security definer`) al insertar en la tabla de "votos"/"likes" correspondiente. No hay un endpoint para modificarlos directamente.
- `personal_profiles` tiene una policy de lectura pública a nivel de **fila**, no de columna: cualquier autenticado puede pedir cualquier columna de cualquier perfil vía la API, aunque la app solo pida nombre/ciudad/avatar.

---

## 5. Realtime (streams)

Mismo endpoint que PostgREST pero vía WebSocket, usado con `.stream(primaryKey: ['id'])`. Habilitado (agregado a la publicación `supabase_realtime`) en:

- `publicaciones`
- `comments`
- `iniciativas`
- `votaciones`
- `beneficios`
- `servicios`
- `hc_transactions`
- `personal_profiles`
- `votacion_comments`
- `saved_items`

El resto de las tablas se consultan con `.select()` normal (sin tiempo real), ya que no hay una pantalla que necesite actualizarse en vivo sobre ellas.

---

## Pendiente / no existe todavía

- Endpoint para crear/editar `votaciones` desde la app (hoy solo se siembran por SQL).
- `UPDATE`/`DELETE` de `comments` y `votacion_comments` (editar o borrar un comentario propio).
- `DELETE` en `iniciativa_votes`/`votacion_votes` (quitar un apoyo o voto ya emitido).
- Apoyar una iniciativa (`iniciativa_votes`) sigue sin otorgar HC — decisión de diseño, no un pendiente técnico.
- Transferencias P2P de HC entre usuarios — no planteadas por el CEO todavía, no hay tabla ni función para esto.
