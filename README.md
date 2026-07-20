# HeartCoin

App social de impacto: publicaciones tipo feed, iniciativas ciudadanas por categoría (Voluntariado, Crowdfunding, Social, Ahorro) con check-in por QR y geolocalización, votaciones de fundaciones con recompensa en HeartCoin (HC) configurable por campaña, beneficios y servicios de empresas canjeables con HC (descuentos/cashback/becas), billetera de HC con historial de movimientos y ranking de participación por check-ins, certificados de participación, comentarios y presupuesto por votación, guardado de iniciativas/votaciones favoritas, un historial de "Tus acciones", notificaciones en tiempo real y perfiles de usuario. Construida en Flutter con Supabase como backend.

## Stack

- **Flutter** (Dart) — apps móviles Android/iOS.
- **Supabase** — Postgres, Auth, Realtime, Row Level Security, Edge Functions (Deno).
- **MediaAAS** — servicio externo de almacenamiento de archivos (imágenes/documentos), integrado vía una Edge Function proxy para no exponer credenciales en el cliente.

## Requisitos

- Flutter SDK (canal estable) y un dispositivo/emulador Android o iOS.
- [Supabase CLI](https://supabase.com/docs/guides/cli) si vas a tocar la base de datos o las Edge Functions.

## Puesta en marcha

```bash
flutter pub get
flutter run
```

Las credenciales de Supabase (URL y anon key) están en [lib/main.dart](lib/main.dart). El proyecto de Supabase ya está enlazado localmente vía `supabase link`; para volver a enlazarlo en otra máquina:

```bash
supabase login
supabase link --project-ref <project-ref>
```

## Roles y flujo de autenticación

El registro (`lib/screens/auth/register_screen.dart`) soporta tres roles, cada uno con su tabla de perfil en Supabase:

| Rol | Tabla de perfil | Home |
|---|---|---|
| Personal | `personal_profiles` | `HomePeopleScreen` (funcional) |
| Organización | `organization_profiles` | `HomeOrganizationScreen` (funcional) |
| Empresa | `company_profiles` | `HomeCompanyScreen` (funcional) |

Los tres roles pueden registrarse desde la app. Al elegir Empresa, el formulario ya no está bloqueado: pide nombre de la empresa, representante, cargo, industria, número de empleados y objetivo principal (los dos últimos y el número de empleados son dropdowns cuyos valores deben coincidir exactamente con los `check constraints` de `company_profiles` en Supabase, mismo cuidado que ya se tenía con `profile_type`/`organization_type`).

`AuthService` (`lib/services/auth_service.dart`) centraliza `signUp`, `signIn`, `signOut` y guarda el rol en `user_metadata`.

Tras registrarse, el flujo pasa por verificación de correo (ver sección "Verificación de correo" más abajo) antes de dejar entrar a la app. "¿Olvidaste tu contraseña?" en el login usa un flujo de 3 pasos 100% Supabase (`forgot_password_screen.dart` → `verify_reset_code_screen.dart` → `reset_password_screen.dart`), con un código de 6 dígitos vía correo (`resetPasswordForEmail`/`verifyOTP`) — no tiene relación con Original Auth.

## Estructura del proyecto

```
lib/
├── main.dart                          # Rutas, tema, escalado de texto global
├── screens/
│   ├── auth/                          # Login, registro, recuperar contraseña, verificar correo (Original Auth)
│   ├── home_people_screen.dart        # Feed principal (rol Personal)
│   ├── home_organization_screen.dart  # Dashboard con datos reales (rol Organización)
│   ├── home_company_screen.dart       # Dashboard con datos reales (rol Empresa)
│   ├── org_iniciativas_screen.dart    # "Mis iniciativas": gestión con flujo Borrador→Votación→Activa (rol Organización)
│   ├── edit_org_iniciativa_screen.dart  # Editar iniciativa propia (incluye cambiar de estado)
│   ├── company_beneficios_screen.dart # "Mis beneficios": gestión + activar/desactivar + QR (rol Empresa)
│   ├── create_beneficio_screen.dart   # Publicar beneficio (descuento/cashback/beca/otro) (rol Empresa)
│   ├── beneficio_qr_screen.dart       # Muestra el QR de canje de un beneficio (rol Empresa)
│   ├── beneficio_scanner_screen.dart  # Escanea y canjea un beneficio O servicio con HC (rol Personal)
│   ├── company_servicios_screen.dart  # "Mis servicios": gestión + activar/desactivar + QR (rol Empresa)
│   ├── create_servicio_screen.dart    # Publicar servicio (costo o cashback en HC) (rol Empresa)
│   ├── servicio_qr_screen.dart        # Muestra el QR de canje de un servicio (rol Empresa)
│   ├── servicio_detail_screen.dart    # Detalle de un servicio (canjear o gestionar, según el rol)
│   ├── wallet_screen.dart             # Billetera: balance real, beneficios, historial de HC y ranking por check-ins (rol Personal)
│   ├── checkin_scanner_screen.dart    # Escanea el QR de check-in de una iniciativa (rol Personal)
│   ├── iniciativa_qr_screen.dart      # Muestra el QR de check-in de una iniciativa (rol Organización)
│   ├── certificados_screen.dart       # Lista de certificados generados por check-ins (rol Personal)
│   ├── certificado_detail_screen.dart # Vista tipo diploma de un certificado
│   ├── mis_acciones_screen.dart       # "Tus acciones": participaciones + guardados, buscador y filtros (rol Personal)
│   ├── votaciones_monitor_screen.dart # Ranking de votos por campaña, filtrable (rol Organización)
│   ├── votacion_monitor_detail_screen.dart  # Detalle de una votación: progreso, aprobación, participación, evolución
│   ├── community_screen.dart          # Usuarios que han votado/apoyado (rol Organización)
│   ├── explore_screen.dart            # Explorar iniciativas (todas las categorías)
│   ├── iniciativas_by_category_screen.dart  # Base reutilizable por categoría
│   ├── iniciativas_ahorro_screen.dart # Iniciativas de ahorro (+ botón crear)
│   ├── iniciativas_social_screen.dart # Iniciativas sociales
│   ├── iniciativa_detail_screen.dart  # Detalle + apoyar + check-in QR + fundación (con botón Seguir)
│   ├── create_iniciativa_ahorro_screen.dart  # Asistente de 3 pasos: objetivo → proveedor → detalles
│   ├── votaciones_screen.dart         # Iniciativas por votar (fundaciones, recompensa HC)
│   ├── votacion_detail_screen.dart    # Detalle + votar
│   ├── create_post_screen.dart        # Nueva publicación (texto, multimedia, ubicación)
│   ├── comments_sheet.dart            # Modal de comentarios con respuestas y likes
│   ├── notifications_screen.dart      # Notificaciones (likes, comentarios, respuestas)
│   ├── profile_screen.dart            # Perfil propio (posts, likes, followers/follows)
│   ├── user_profile_screen.dart       # Perfil de **otro** usuario (stats, seguir, publicaciones, bloquear)
│   ├── settings_screen.dart           # Tamaño de texto, ubicación, accesos a Cuenta y Eliminar cuenta
│   ├── edit_profile_screen.dart       # Editar datos del perfil propio + avatar (sube a MediaAAS)
│   ├── change_password_screen.dart    # Cambiar contraseña
│   ├── notification_preferences_screen.dart  # Activar/desactivar notificaciones por tipo (likes/comentarios/respuestas)
│   ├── privacy_screen.dart            # Perfil público/privado (`is_public`)
│   ├── privacy_policy_screen.dart     # Aviso de privacidad (texto legal)
│   ├── about_screen.dart              # Acerca de la app
│   ├── blocked_users_screen.dart      # Lista de usuarios bloqueados + desbloquear
│   └── delete_account_screen.dart     # Eliminar cuenta (con confirmación, vía Edge Function)
├── services/                          # Toda la lógica de acceso a Supabase
│   ├── checkin_service.dart           # Check-in de iniciativas (geolocalización + RPC validado)
│   ├── beneficio_service.dart         # CRUD de beneficios + canje (RPC validado)
│   ├── servicio_service.dart          # CRUD de servicios + canje (RPC validado)
│   ├── wallet_service.dart            # Balance, historial de HC y beneficios disponibles (tiempo real)
│   ├── ranking_service.dart           # Ranking de usuarios por check-ins confirmados
│   ├── follow_service.dart            # Seguir/dejar de seguir
│   ├── block_service.dart             # Bloquear/desbloquear usuarios (filtra el feed y las interacciones)
│   ├── account_service.dart           # Eliminar cuenta (llama a la Edge Function `delete-account`)
│   ├── original_auth_service.dart     # Puente de verificación de correo con Original Auth (ver sección dedicada)
│   ├── saved_items_service.dart       # Guardar/quitar iniciativas y votaciones
│   ├── mis_acciones_service.dart      # Historial de participaciones + estadísticas ("Tus acciones")
│   ├── certificado_service.dart       # Certificados generados a partir de check-ins
│   ├── votacion_comments_service.dart # Comentarios de una votación
│   ├── org_dashboard_service.dart     # Estadísticas reales del dashboard de Organización
│   ├── company_dashboard_service.dart # Estadísticas reales del dashboard de Empresa
│   ├── text_scale_controller.dart     # Tamaño de texto global (persistido con `shared_preferences`)
│   └── location_preference_controller.dart  # Preferencia de uso de GPS (persistido con `shared_preferences`)
├── widgets/
│   ├── iniciativa_widgets.dart        # Tarjetas y chips reutilizables de iniciativas (incluye fundación y guardado)
│   ├── follow_button.dart             # Botón "Seguir/Siguiendo" reutilizable
│   ├── save_button.dart               # Botón "Guardar" reutilizable (modo normal y compacto)
│   └── posts_grid.dart                # Grid de publicaciones (3 columnas) reutilizado por perfil propio y perfil de otros
└── theme/app_colors.dart              # Paleta oficial de la app

supabase/functions/
├── upload-media/                      # Proxy de subida a MediaAAS (firma HMAC server-side)
├── delete-account/                    # Borra la cuenta del usuario autenticado (usa la Service Role Key, nunca expuesta al cliente)
├── _shared/originalauth.ts            # Cliente HMAC compartido para la API de Original Auth
├── originalauth-register/             # Dispara la verificación de correo en Original Auth al registrarse
├── originalauth-verify-email/         # Confirma el código/token de verificación
└── originalauth-resend-verification/  # Reenvía el código de verificación
```

## Base de datos (Supabase / Postgres)

Todas las tablas tienen Row Level Security habilitado.

| Tabla | Qué guarda |
|---|---|
| `personal_profiles` / `organization_profiles` / `company_profiles` | Perfil por rol. `personal_profiles.hc_balance` es el balance de HC, mantenido por trigger desde `hc_transactions`. `personal_profiles` además tiene `notify_likes`/`notify_comments`/`notify_replies` (gatean si los triggers de notificaciones insertan o no) e `is_public` (gatea si otros usuarios pueden leer el perfil) |
| `blocked_users` | Un bloqueo por usuario hacia otro (PK compuesta `user_id`+`blocked_user_id`); el bloqueado desaparece del feed de quien bloquea. Solo cada usuario ve/crea/borra sus propios bloqueos |
| `publicaciones` | Posts del feed (texto, imagen, documentos, ubicación, iniciativa relacionada) |
| `post_likes` / `comments` / `comment_likes` | Likes y comentarios (con un nivel de respuestas) de publicaciones |
| `follows` | Relación seguidor/seguido, con UI real (`FollowButton`) en el detalle de iniciativa (seguir fundación) y en el feed (seguir autor) |
| `notifications` | Generadas automáticamente por triggers (like a post/comentario, comentario, respuesta); cada trigger revisa primero `notify_likes`/`notify_comments`/`notify_replies` del destinatario en `personal_profiles` y no inserta nada si está desactivado |
| `iniciativas` | Iniciativas por categoría (Voluntariado/Crowdfunding/Social/Ahorro), con votos, ubicación, objetivo/proveedor/monto/fecha (metas de ahorro), estado (`borrador`/`votacion`/`activa`), método de verificación (`qr`/`manual`/`foto`), `hc_reward` (HC que otorga el check-in, **configurable desde la app** al crear/editar una iniciativa, default 50) y `organization_name` (denormalizado, sincronizado por trigger desde `organization_profiles.author_id`) |
| `iniciativa_votes` | Un "apoyo" por usuario por iniciativa; al llegar a `votes_goal` en estado `votacion`, la iniciativa pasa a `activa` automáticamente vía trigger. No otorga HC (decisión de diseño: actividad de bajo esfuerzo) |
| `iniciativa_checkins` | Un check-in por usuario por iniciativa (PK compuesta), insertado solo vía la función `checkin_iniciativa()` (geolocalización + ventana de horario). Al insertarse, un trigger acredita `iniciativas.hc_reward` al usuario en `hc_transactions`, y ese check-in es lo que genera un certificado de participación |
| `proveedores` | Catálogo de proveedores aliados para metas de ahorro (vivienda/educación/vehículo/otro) |
| `votaciones` | Campañas de fundaciones que compiten por votos, con recompensa en HC (`hc_reward`) y `budget_items` (jsonb: desglose de presupuesto por categoría con su porcentaje, específico de cada campaña) |
| `votacion_votes` | Un voto por usuario por votación (constraint única `votacion_id`+`user_id` — antes no existía, aunque el cliente ya esperaba el error de duplicado). Al insertarse, un trigger acredita `votaciones.hc_reward` al usuario en `hc_transactions` |
| `votacion_comments` | Comentarios de una votación (tabla propia, separada de `comments` para no tocar los triggers de notificaciones de publicaciones); lectura pública, inserción con `author_id` propio |
| `hc_transactions` | Ledger de movimientos de HC (monto +/-, tipo, referencia); es la única fuente de verdad del balance, solo se escribe desde funciones `SECURITY DEFINER` |
| `beneficios` | Ofertas de empresas canjeables con HC (descuento/cashback/beca/otro), con `company_name` denormalizado (mismo patrón que `organization_name`), estado, vencimiento y límite de canjes |
| `beneficio_redemptions` | Un canje por usuario por beneficio (PK compuesta), insertado solo vía la función `redeem_beneficio()` |
| `servicios` | Catálogo de servicios que ofrece una empresa (ej. consultoría, diseño, capacitación), con categoría libre, `pricing_type` (`costo`/`cashback`), `hc_cost`/`hc_reward`, límite de canjes y `company_name` denormalizado |
| `servicio_redemptions` | Un canje por usuario por servicio (PK compuesta), insertado solo vía la función `redeem_servicio()` |
| `saved_items` | Iniciativas/votaciones guardadas por un usuario (`item_type` + `item_id`, único por usuario), leído/escrito solo por su dueño |

`personal_profiles` también tiene una policy de lectura pública para otros usuarios autenticados, pero condicionada a `is_public = true` (controlable desde "Privacidad" en Configuración) — se usa en la pantalla "Comunidad" del rol Organización y en `user_profile_screen.dart` (perfil de otro usuario). Es una policy a nivel de fila, no de columna, así que técnicamente cualquier request autenticado con un perfil marcado público podría pedir otras columnas vía la API aunque la app solo pida nombre/ciudad/avatar/bio.

`iniciativas` solo es visible públicamente cuando `status = 'activa'`; una organización siempre puede leer sus propias iniciativas sin importar el estado (RLS con dos policies SELECT permisivas, vía `author_id`), y también puede `UPDATE` solo las suyas.

### Funciones RPC (`SECURITY DEFINER`)

Para las dos operaciones que necesitan validar reglas de negocio que RLS no puede expresar (geolocalización, ventana de tiempo, balance suficiente) sin exponer un camino de escritura directa que un cliente modificado pueda saltarse, la tabla de destino **no tiene policy de `INSERT` para el cliente** — solo se escribe a través de estas funciones:

- **`checkin_iniciativa(p_iniciativa_id, p_lat, p_lng)`**: valida que el método de verificación sea `qr`, que la hora actual esté dentro de la ventana del evento (`event_date` + `verification_window_hours`), y que la distancia (haversine) a la ubicación registrada sea ≤ 200m. Inserta en `iniciativa_checkins`.
- **`redeem_beneficio(p_beneficio_id)`**: valida que el beneficio esté activo, que no se haya canjeado ya, y que no se supere `max_redemptions`. Si es `cashback`, acredita `hc_reward` en `hc_transactions`; si es descuento/beca, valida que `hc_balance` alcance y descuenta `hc_cost`. Inserta en `beneficio_redemptions` y actualiza `redemptions_count`.
- **`redeem_servicio(p_servicio_id)`**: misma lógica que `redeem_beneficio` pero sobre `servicios`/`servicio_redemptions`, usando `pricing_type` (`costo`/`cashback`) en vez de `benefit_type`.

Todas usan `auth.uid()` internamente, así que el cliente nunca envía de quién es el check-in/canje — solo el id de la iniciativa/beneficio/servicio (el mismo valor codificado en el QR). El escáner de la billetera (`beneficio_scanner_screen.dart`) prueba primero si el código corresponde a un beneficio y, si no, a un servicio, así que un mismo flujo de escaneo cubre ambos.

**Valores válidos de catálogos** (deben coincidir exactamente con los `check constraints` de la base de datos, no solo con las opciones del dropdown en la app):
- `personal_profiles.profile_type`: `Voluntario`, `Emprendedor`, `Profesional`, `Estudiante`, `Investigador`, `Otro`.
- `organization_profiles.organization_type`: `ONG`, `Fundación`, `Gobierno`, `Universidad`, `Comunidad`, `Asociación Civil`, `Cooperativa`, `Organización Internacional`, `Otra`.

Los contadores (`likes_count`, `comments_count`, `votes_count`) se mantienen sincronizados con **triggers de Postgres**, no desde el cliente — así el feed y las listas se actualizan en tiempo real vía Supabase Realtime sin recalcular nada en Flutter.

## Multimedia

Las imágenes y documentos se suben a **MediaAAS** (servicio externo, ver [mediaas-client-api-guide.md](mediaas-client-api-guide.md)) a través de la Edge Function `upload-media`: la app llama a la función ya autenticada con su sesión de Supabase, y la función firma el request a MediaAAS con HMAC usando credenciales que solo existen como secrets del servidor — nunca se exponen en el cliente.

```bash
supabase functions deploy upload-media
supabase secrets set MEDIAAS_API_HOST=... MEDIAAS_API_KEY=... MEDIAAS_SECRET_KEY=...
```

## Cuenta

Borrar una cuenta requiere la `service_role_key` (nunca expuesta al cliente), así que se hace vía la Edge Function `delete-account`: valida la sesión del usuario, y con un cliente admin llama a `auth.admin.deleteUser(userId)`. No necesita secrets propios — Supabase inyecta `SUPABASE_SERVICE_ROLE_KEY` automáticamente en el entorno de toda Edge Function.

```bash
supabase functions deploy delete-account
```

## Verificación de correo (puente con Original Auth)

Por requisito legal (verificar que el correo de cada usuario nuevo sea real), el registro llama a **Original Auth** — pero solo para esto. Ver [ORIGINAL_AUTH_INTEGRATION.md](ORIGINAL_AUTH_INTEGRATION.md) para el documento completo pensado para stakeholders no técnicos; esta sección es la referencia técnica para quien toque el código.

### Qué NO cambia

Este es el punto más importante de todo el diseño: **Supabase Auth sigue siendo, sin ningún cambio, la única fuente de verdad de HeartCoin** para login, sesiones, recuperación de contraseña y eliminación de cuenta. Original Auth no reemplaza nada de eso — es un servicio auxiliar que se consulta una sola vez, durante el registro, y después no vuelve a intervenir. No hay ningún "puente de sesión": nunca se traduce una sesión de Original Auth en una sesión de Supabase, ni al revés.

### Flujo

```
1. AuthService.registerX(...) crea la cuenta en Supabase, como siempre
   (auth.users + fila en personal_profiles / organization_profiles / company_profiles)

2. OriginalAuthService.startEmailVerification(password) llama a la Edge
   Function `originalauth-register`, que:
   a. valida la sesión recién creada (JWT del usuario, cliente anon)
   b. llama a Original Auth: POST /api/v1/integrations/registration
      con el mismo correo y contraseña que el usuario eligió en HeartCoin
   c. guarda `data.user.id` (ej. "acct_...") en la columna `original_auth_id`
      de la tabla de perfil correspondiente (vía cliente admin / service role)

3. La app navega a VerifyEmailScreen — el usuario NO puede entrar a la
   app hasta verificar (decisión de producto: bloquear hasta verificar)

4. El usuario escribe el código/token que recibió por correo

5. OriginalAuthService.verifyEmailCode(code) llama a
   `originalauth-verify-email`, que llama a Original Auth:
   POST /api/v1/integrations/registration/verify-email  con { token: code }
   y si es válido, marca `email_verified = true` en el perfil

6. El usuario entra a la app normalmente — login futuro sigue siendo
   100% Supabase, Original Auth ya no participa
```

Si el usuario no recibe el código, `OriginalAuthService.resendVerificationCode()` llama a `originalauth-resend-verification` (`POST /registration/resend-verification`).

### Autenticación con Original Auth

Integración `server_to_server` por API key + firma HMAC-SHA256 (no OAuth, no navegador, no deep linking). El helper compartido está en [supabase/functions/_shared/originalauth.ts](supabase/functions/_shared/originalauth.ts):

- Cadena canónica: `METODO\nRUTA\nTIMESTAMP\nNONCE\nSHA256_DEL_BODY`, firmada con la API key como secreto.
- Headers enviados: `X-API-Key`, `X-Timestamp` (Unix, segundos), `X-Nonce` (UUID), `X-Signature` (`sha256=<hex>`).
- Implementado con `crypto.subtle` (Web Crypto API de Deno), no con `node:crypto`.

```bash
supabase secrets set ORIGINAL_AUTH_BASE_URL=https://api.test.originalauth.com ORIGINAL_AUTH_API_KEY=oa_live_...
supabase functions deploy originalauth-register
supabase functions deploy originalauth-verify-email
supabase functions deploy originalauth-resend-verification
```

La API key debe estar asociada a una aplicación `server_to_server` en el panel de Original Auth (si no, cualquier request devuelve `403 — "La API key debe estar asociada a una aplicacion"`), con los flujos `Registro` habilitados como mínimo.

### Caveats descubiertos probando contra el ambiente `test`

- **El campo `country` no se envía.** El formulario de registro de HeartCoin captura el país como texto libre (ej. "México"); Original Auth espera un código corto (ISO 3166-1 alpha-2, máx. 5 caracteres) y responde `400` si no coincide. Como el campo es opcional para este flujo, `originalauth-register` simplemente lo omite en vez de intentar mapear texto libre a un código.
- **El ambiente `test` no manda correos reales** (por diseño, para no agotar cuota del proveedor de correo). Cuando la aplicación de Original Auth está configurada como `test`, la respuesta de `/registration` puede incluir `data.verification.token` directo — `originalauth-register` lo captura y lo devuelve a la app (`testToken`), y `VerifyEmailScreen` lo precarga automáticamente con un aviso visible de que es modo prueba. En `prod` este campo no viene; el usuario escribe el código real que le llegó por correo.
- **El código de verificación no se asume de 6 dígitos numéricos.** El campo que espera `verify-email` se llama `token` (no `code` como en recuperación de contraseña), así que el `TextField` de `VerifyEmailScreen` acepta cualquier texto, sin restringir tipo de teclado ni longitud.
- **`FunctionException` hay que capturarla explícitamente.** `_client.functions.invoke()` del SDK de Supabase lanza `FunctionException` en respuestas no-200 (no solo regresa un `response.status` para inspeccionar) — si no se captura ese tipo específico además del propio `OriginalAuthException`, el error real se pierde y el usuario solo ve "ocurrió un error inesperado". Mismo patrón ya usado en `media_service.dart`/`account_service.dart`.

### Pendiente de decidir (no es un bug, es una decisión de producto sin tomar)

El bloqueo por falta de verificación solo aplica **en el momento del registro** — si un usuario cierra la app antes de verificar, su cuenta de Supabase ya existe y el login normal (100% Supabase) no revisa `email_verified` en absoluto, así que puede volver a entrar sin haber verificado nunca. Si se decide que esto debe impedirse también en logins futuros, haría falta agregar esa validación en `AuthService.signIn` o en la pantalla de login.

## Funcionalidades por pantalla

- **Feed** (`home_people_screen.dart`): publicaciones en tiempo real, like, comentarios con respuestas (un nivel), notificaciones con contador de no leídas, botón "Seguir" junto al nombre del autor.
- **Explorar**: buscador + filtro, categorías (Voluntariado/Crowdfunding/Social/Ahorro/**Servicios**), orden (Cercanos vía GPS / Popular / Reciente), tarjeta banner de Votaciones. Al elegir "Servicios" la pantalla cambia de fuente de datos (tabla `servicios` en vez de `iniciativas`) y oculta lo que no aplica (orden, ubicación); cada tarjeta muestra el costo/recompensa en HC y abre el detalle real del servicio.
- **Iniciativas de ahorro / social**: mismo patrón que Explorar filtrado a una categoría; Ahorro además permite crear una meta con un asistente de 3 pasos (objetivo → proveedor con calificación → nombre/descripción/monto/fecha).
- **Detalle de iniciativa**: apoyar (voto), fundación que la creó con botón "Seguir", botón "Guardar", método de verificación, y — si es `qr` y la categoría no es Ahorro — botón "Escanear QR para check-in" que abre la cámara, valida geolocalización + ventana de horario vía `checkin_iniciativa()`, y se deshabilita tras un check-in exitoso.
- **Editar iniciativa** (Organización): formulario de una sola pantalla para su propia iniciativa, incluyendo cambiar el estado (Borrador/Votación/Activa) y la recompensa en HC por check-in.
- **QR de check-in** (Organización): pantalla que genera el QR (contiene solo el id de la iniciativa) para proyectar en el evento, accesible desde "Mis iniciativas".
- **Iniciativas por votar (Votaciones)**: buscador, orden (Todas / Por tiempo / +HC), tarjeta con tipo, fundación, área de impacto, recompensa HC, botón "Guardar" y barra de progreso de votos; detalle con tabs Detalles/Comentarios (en tiempo real, con campo para comentar)/Presupuesto (desglose por categoría con barra de progreso, específico de cada campaña).
- **Certificados**: lista de certificados de participación generados automáticamente a partir de cada check-in confirmado; cada uno abre una vista tipo diploma con el nombre del usuario, la iniciativa, la organización y la fecha.
- **Tus acciones** (Personal, 4° botón del tab inferior): resumen de balance de HC/votos totales/check-ins, buscador, y dos vistas alternables — "Participaciones" (apoyos, votos, check-ins y canjes combinados y ordenados por fecha, con filtro por tipo y el HC ganado/gastado en cada una) y "Guardado" (iniciativas/votaciones guardadas, cada una abre su detalle real).
- **Perfil**: estadísticas (Posts/Followers/Follows), grid de publicaciones propias y de publicaciones con like.
- **Perfil de otro usuario** (`user_profile_screen.dart`): se abre al tocar el avatar o el nombre de un autor en el feed. Muestra estadísticas, bio/ubicación, botón "Seguir" y sus publicaciones; si el perfil es privado (`is_public = false`) muestra "Este perfil no está disponible" en vez de los datos. Incluye un menú (⋮) para bloquear/desbloquear.
- **Billetera** (Personal, botón central del tab inferior): balance real de HC, botón "Canjear" que abre el escáner de beneficios/servicios, y tres tabs — "Beneficios" (explorar lo publicado por empresas, con detalle completo de cada uno), "Historial" (cada movimiento del ledger con fecha, tipo y +/-) y "Ranking" (top 20 de usuarios por check-ins confirmados, con medallas para el top 3 y tu propia posición resaltada aunque no estés en el top 20).
- **Configuración**: control de tamaño de texto (85%–130%) aplicado globalmente vía `MediaQuery`/`TextScaler`; sección "Cuenta" con Editar perfil, Cambiar contraseña, Notificaciones (activar/desactivar por tipo: likes/comentarios/respuestas), Privacidad (perfil público/privado), Acerca de, Usuarios bloqueados, y un switch de "Preferencia de ubicación" (gatea si `explore_screen.dart` pide GPS para ordenar por "Cercanos"); sección aparte "Zona de riesgo" con Eliminar cuenta. Todo persistido con `shared_preferences` (texto/ubicación) o en Supabase (el resto).
- **Bloquear usuarios**: desde el menú (⋮) de un post en el feed o desde el perfil de otro usuario. Al bloquear, sus publicaciones desaparecen del feed inmediatamente (filtro local por `author_id`) y queda registrado en `blocked_users`; "Usuarios bloqueados" en Configuración lista y permite desbloquear.
- **Eliminar cuenta**: pantalla con advertencia, checklist de lo que se borra y checkbox de confirmación obligatorio. Llama a la Edge Function `delete-account`, que borra el usuario en `auth.users` — todas las tablas relacionadas (perfil, publicaciones, HC, votos, check-ins, etc.) se borran en cascada porque cada FK hacia `auth.users` tiene `ON DELETE CASCADE`, así que no hay limpieza manual del lado de la app.
- **Dashboard de Organización**: header con saludo real, tarjeta "NEW Initiative" (conectada a `CreateOrgIniciativaScreen`), resumen de actividad y gráfica de votos semanales con **datos reales** (iniciativas activas, votos recibidos desde `iniciativa_votes`, personas alcanzadas desde `iniciativa_checkins`), drawer con Mis iniciativas, Monitor de votaciones, Comunidad, Configuración y Cerrar sesión. El tab inferior no tiene botón central (se quitó a propósito para este rol).
- **Mis iniciativas** (Organización): tarjeta con contadores en tiempo real (Total/En Votación/Activas), buscador, filtro por estado (Todas/Borrador/Votación), y tarjetas con progreso ("X% aprobado"), tiempo restante y botones Ver / Editar (real) / Mostrar QR (si `verification_method = 'qr'`). Solo muestra iniciativas propias de Voluntariado/Crowdfunding/Social — Ahorro tiene su propio flujo de creación.
- **Monitor de votaciones** (Organización): ranking real de todas las votaciones ordenado por votos, filtrable por categoría y por más votados/más recientes; cada fila abre un detalle con banner de estado, tasa de aprobación, participación (sobre el total de usuarios registrados) y una gráfica de evolución de votos por día (dibujada con un `CustomPainter` propio, sin dependencias externas de charts).
- **Comunidad** (Organización): lista de usuarios que han votado en votaciones o apoyado iniciativas, con conteo de participaciones y buscador por nombre.
- **Dashboard de Empresa**: header con saludo real, tarjeta "Nuevo beneficio", resumen con datos reales (beneficios activos, por vencer en 7 días, canjes totales, HC cobrados), y acceso a "Mis beneficios". Tab inferior sin botón central: 2° botón → Beneficios, **3° botón → Servicios** (`CompanyServiciosScreen`).
- **Mis beneficios** (Empresa): lista de beneficios propios con tipo, estado, contador de canjes, botón activar/desactivar y botón para mostrar el QR de canje.
- **Nuevo beneficio** (Empresa): formulario para publicar descuento/cashback/beca/otro, con costo o recompensa en HC, términos, límite de canjes y fecha de vencimiento.
- **Mis servicios** (Empresa): catálogo propio de servicios (consultoría, diseño, capacitación, etc.), independiente de los beneficios; cada tarjeta muestra el costo/recompensa en HC, el conteo de canjes, y botones activar/desactivar y mostrar QR.
- **Nuevo servicio** (Empresa): formulario con categoría, título, descripción, tipo de recompensa (cuesta HC o da HC de regreso) y límite de canjes opcional.
- **Detalle de servicio**: visible tanto desde Explorar (Personal) como desde "Mis servicios" (Empresa) — mismo componente, que muestra u oculta acciones según quién sea el dueño (`company_id == auth.uid()`). El dueño ve estado y botón "Mostrar QR"; cualquier otro usuario ve el botón "Escanear para canjear" (deshabilitado si ya lo canjeó).

## Datos de demo

La base ya tiene datos de prueba sembrados directamente vía la Admin API de Supabase (no a través de la app):

- 20 cuentas de rol Personal (correo `nombre.apellido@heartcoin-demo.mx`) con 15 publicaciones cada una (300 en total), imágenes reales subidas a MediaAAS, y ~1,000 comentarios/respuestas repartidos entre ellas.
- 6 cuentas de rol Organización (correo `contacto@<nombre-org>.mx`), autoras de las 51 iniciativas de ejemplo (repartidas entre las 6, round-robin).
- 3 cuentas de rol Empresa (Grupo VEQ, TechSolve, Vértice Retail — correo `contacto@<empresa>.mx`), repartiéndose **20 beneficios** (descuento/cashback/beca/otro) y **20 servicios** (costo/cashback) de ejemplo, todos publicados y activos, listos para canjear desde la billetera o desde Explorar → Servicios.
- Todas comparten la contraseña `HeartCoin2026!` (pídele la lista completa de correos a quien tenga el historial de esta siembra, o consulta `personal_profiles`/`organization_profiles`/`company_profiles` filtrando por `heartcoin-demo.mx`/`.mx`).
- 51 iniciativas de ejemplo repartidas en las 4 categorías, todas con `verification_method` y `organization_name` asignados, y varias votaciones de ejemplo con distintos estados de progreso.

## Pendientes conocidos

- **HC de apoyar una iniciativa (`iniciativa_votes`) sigue sin otorgar nada** — decisión de diseño: actividad de bajo esfuerzo (apoyar/like) no otorga HC; solo votar en una `votacion` y hacer check-in en una `iniciativa` lo hacen.
- **Ahorro sigue ligado a organizaciones, no a empresas**: se decidió explícitamente no migrar las iniciativas de categoría Ahorro (Vivienda/Educación/Vehículo) al rol Empresa por ahora; siguen usando `organization_profiles`/`proveedores` como hasta ahora.
- **El botón "Guardar" solo vive en las pantallas de detalle y en las tarjetas de iniciativas/votaciones** — no existe en, por ejemplo, publicaciones del feed.
- Sistema de moneda virtual HeartCoin (HC): el diseño económico general ya está definido por el CEO e implementado de punta a punta — organizaciones publican iniciativas sociales donde la gente gana HC participando (voto/check-in), empresas publican beneficios donde la gente gasta o gana HC canjeando por QR. Pendiente de definir con el CEO: transferencias P2P entre usuarios (no planteadas todavía), y de dónde sale el saldo inicial de HC de una organización para financiar sus propias campañas (no hay pasarela de pagos, sigue sin resolver).