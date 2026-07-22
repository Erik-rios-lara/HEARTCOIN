# Manual técnico — HeartCoin

Documento de referencia integral del proyecto: qué es, cómo está construido, qué hace cada pantalla y en qué estado se encuentra. Pensado para que cualquier persona nueva en el proyecto —técnica o no— pueda leerlo y entender de un tirón qué existe hoy, sin tener que reconstruir el contexto leyendo el código o el historial de conversaciones.

Este documento complementa, no reemplaza, a `README.md` (referencia técnica rápida para quien va a tocar código) y a los documentos de integración dedicados (`ORIGINAL_AUTH_INTEGRATION.md`, `ORIGINAL_PAY_INTEGRATION.md`, `ENDPOINTS.md`). Aquí se prioriza la vista completa y narrativa; ahí, el detalle de implementación de cada pieza.

**Última actualización de este documento: 22 de julio de 2026.**

---

## 1. Qué es HeartCoin

HeartCoin es una app móvil (Flutter, Android/iOS) de impacto social que conecta tres tipos de usuario en un mismo ecosistema:

- **Personal**: personas que participan en iniciativas sociales, votan campañas, ahorran para una meta con apoyo de otros, y ganan una moneda virtual propia (**HeartCoin / HC**) que pueden canjear por beneficios y servicios reales.
- **Organización**: fundaciones, ONGs, asociaciones civiles, etc. que publican iniciativas (voluntariado, crowdfunding, causas sociales) y campañas de votación, y les otorgan HC a quienes participan.
- **Empresa**: negocios que publican beneficios (descuentos, cashback, becas) y servicios canjeables con HC, funcionando como el lado de "gasto" de la economía de HC.

La idea central: una organización le da HC a la gente por participar en causas reales; una empresa deja que esa gente use esos HC en beneficios reales. HeartCoin es el puente entre ambos lados, con una billetera, un feed social, y —agregado en esta última ronda de trabajo— ubicación en mapa para encontrar beneficios/servicios cercanos y un sistema real de participantes para metas de ahorro colectivas.

---

## 2. Stack y arquitectura

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Dart), Android e iOS |
| Backend | Supabase: Postgres, Auth, Realtime, Row Level Security, Edge Functions (Deno) |
| Almacenamiento de archivos | MediaAAS (servicio externo), vía Edge Function proxy con firma HMAC |
| Verificación de correo | Original Auth (servicio externo, solo durante el registro — ver §7) |
| Consulta/cobro de saldo HC desde fuera de la app | Original Pay (servicio externo, llama hacia HeartCoin — ver §7) |
| Mapas | flutter_map + tiles de OpenStreetMap (sin API key, sin costo) |

No hay backend propio fuera de Supabase: toda la lógica de negocio vive en Postgres (RLS, triggers, funciones `SECURITY DEFINER`) o en Edge Functions cuando hace falta un secreto de servidor (llamar a un servicio externo, o usar la Service Role Key). El cliente Flutter nunca tiene una credencial que le permita saltarse una regla de negocio.

**Proyecto de Supabase activo:** `bamrvwzpcqwoyuwbvomw` (nombre "heartcoin-v1"). Existe un proyecto anterior ("heartcoin", inactivo) que ya no se usa.

---

## 3. Roles y autenticación

Los tres roles se registran desde la misma pantalla (`register_screen.dart`), con un selector tipo "pill" (Personal / Organización / Empresa) que cambia los campos del formulario. Cada rol tiene su propia tabla de perfil en Postgres (`personal_profiles`, `organization_profiles`, `company_profiles`), y su propio home (`HomePeopleScreen`, `HomeOrganizationScreen`, `HomeCompanyScreen`).

**Flujo de registro:**
1. Se crea la cuenta en Supabase Auth + la fila de perfil correspondiente.
2. Se dispara una verificación de correo real vía **Original Auth** (ver §7) — el usuario no puede entrar a la app hasta ingresar el código que le llega por correo.
3. A partir de ahí, todo el login/sesión/recuperación de contraseña es 100% Supabase — Original Auth no vuelve a intervenir nunca.

**Login y registro tienen diseño oscuro** (rediseñados en esta ronda de trabajo): imagen ilustrada de marca en la parte superior (la misma en ambas pantallas, sin cambios), tarjeta oscura que ocupa exactamente la mitad inferior de la pantalla, campos de texto rellenos (no de contorno), botón principal en pill completo. El selector de rol en registro cambia de campos según el rol elegido, pero ninguna de esas reglas de negocio se tocó — solo el estilo visual.

---

## 4. Manual funcional por rol

### 4.1 Personal

- **Feed** (home): publicaciones tipo red social — texto, imagen, documentos, ubicación opcional, y ahora también **una iniciativa relacionada real** (buscador que consulta las iniciativas activas de la plataforma; antes era una lista de relleno con nombres falsos). La iniciativa relacionada aparece como una etiqueta roja tocable en la tarjeta de la publicación, que lleva a su detalle. Cada publicación admite like, comentarios con un nivel de respuestas, y seguir al autor.
- **Explorar**: todas las iniciativas (Voluntariado/Crowdfunding/Social/Ahorro) más una pestaña "Servicios". Buscador, filtro por categoría, orden (Cercanos vía GPS / Popular / Reciente) — el orden "Cercanos" ahora también funciona para Servicios (antes estaba desactivado a propósito para esa categoría).
- **Detalle de iniciativa**: apoyar (voto), seguir a la organización, guardar, y si aplica, escanear QR de check-in (geolocalización + ventana de horario).
- **Iniciativas de Ahorro — rediseño completo**: cada meta de ahorro ahora tiene **participantes reales** (Titular = quien la creó, Participantes = gente invitada), un botón para invitar a alguien (buscador de usuarios), una barra de progreso editable por el Titular, y un botón "Solicitar unirme" para cualquiera que no participe — el Titular ve esas solicitudes y puede aceptarlas o rechazarlas. Las pestañas "Proveedor → Avances reportados / Contrato" y "Actividad" quedan como "Próximamente": no hay todavía un panel para que el proveedor cargue esa información.
- **Votaciones**: campañas de fundaciones compitiendo por votos, con recompensa en HC, comentarios en tiempo real y desglose de presupuesto por campaña.
- **Certificados**: uno por cada check-in confirmado, con vista tipo diploma.
- **Tus acciones**: historial combinado de apoyos/votos/check-ins/canjes, más lo guardado.
- **Billetera** — ahora con **4 pestañas** (antes 3):
  - *Beneficios*: explorar lo publicado por empresas, con orden "Recientes/Cercanos".
  - **Mapa** (nueva): todos los beneficios activos con ubicación, agrupados **por negocio** (si una empresa publicó varios beneficios en el mismo local, se ven como un solo pin, no uno encimado por beneficio), centrado en tu ubicación actual si la tienes activada. Los pines usan un diseño propio de marca (gota de mapa con un corazón blanco al centro, en vez de un ícono genérico). Tocar un pin abre una tarjeta flotante minimalista con el nombre del negocio; tocarla de nuevo muestra la lista de beneficios de ese negocio.
  - *Historial*: cada movimiento de HC.
  - *Ranking*: top 20 por check-ins, con tu posición aunque no estés en el top 20.
- **Notificaciones**: además de la campanita en tiempo real (ya existía), ahora también llega un **banner nativo del sistema operativo** (notificación local) cuando algo nuevo pasa mientras usas la app (abierta o en segundo plano) — ver §6.
- **Perfil / Configuración**: tamaño de texto, privacidad, notificaciones por tipo, usuarios bloqueados, eliminar cuenta.

### 4.2 Organización

- **Dashboard**: resumen de actividad real (iniciativas activas, votos recibidos, personas alcanzadas) y gráfica de votos semanales.
- **Mis iniciativas**: gestión con flujo Borrador → Votación → Activa, editar, y mostrar QR de check-in.
- **Monitor de votaciones**: ranking de todas las campañas por votos, con detalle de aprobación/participación/evolución diaria.
- **Comunidad**: quién ha votado/apoyado, con buscador.

### 4.3 Empresa

- **Dashboard**: beneficios activos, por vencer, canjes totales, HC cobrados.
- **Mis beneficios**: gestión (activar/desactivar, QR de canje) — ahora la tarjeta de cada beneficio **sí lleva al detalle completo** (con mapa, si tiene ubicación); antes era una pantalla aislada sin ese enlace.
- **Nuevo beneficio / Nuevo servicio**: formularios de publicación que ahora incluyen un botón **"Usar mi ubicación actual"** para capturar dónde está el local (opcional) — esa ubicación es la que después aparece en el mapa del detalle y en la billetera de los usuarios.
- **Mis servicios**: catálogo propio, mismo patrón que beneficios.

---

## 5. El sistema de HeartCoins (HC)

- Ledger único de verdad: `hc_transactions`. El balance de cada usuario (`personal_profiles.hc_balance`) se mantiene por trigger, nunca se calcula ni se escribe desde la app.
- **Se gana HC**: votando en una campaña (`votaciones.hc_reward`), o haciendo check-in confirmado en una iniciativa (`iniciativas.hc_reward`, configurable por la organización al crear/editar, default 50). Apoyar/votar una iniciativa (like de bajo esfuerzo) **no** otorga HC — decisión de diseño explícita.
- **Se gasta o se gana HC**: canjeando un beneficio o servicio de una empresa (descuento/beca gastan HC; cashback otorga HC), siempre a través de una función `SECURITY DEFINER` (`redeem_beneficio`/`redeem_servicio`) que valida balance, estado activo y límite de canjes — nunca un `INSERT` directo del cliente.
- **Pendiente de definir con el CEO** (ya estaba anotado en `README.md`, sigue sin resolver): transferencias P2P entre usuarios, y de dónde sale el HC inicial que una organización necesita para financiar sus propias campañas (no hay pasarela de pagos todavía del lado de "cargar" HC).

---

## 6. Notificaciones

Dos capas, ambas construidas sobre Supabase Realtime (no polling):

1. **Campanita en tiempo real dentro de la app**: ya existía para Personal, se extendió esta ronda a **Organización y Empresa** — los tres roles ahora tienen el mismo indicador de "no leídas" y la misma pantalla de notificaciones.
2. **Notificación nativa del sistema (banner del celular)**, solo para Personal por ahora: cuando llega un nuevo like/comentario/respuesta mientras la app está abierta o en segundo plano, se muestra un banner del sistema operativo (`flutter_local_notifications`), no solo el indicador dentro de la app. Requirió habilitar *core library desugaring* en el build de Android.

**Límite importante, ya conocido y aceptado:** esto **no** es push real. Si el sistema operativo mata el proceso de la app por completo, no llega nada — para eso hace falta Firebase Cloud Messaging (Android) y APNs vía cuenta de Apple Developer (iOS), que quedó fuera de alcance por ahora (requiere crear esas cuentas, con costo en el caso de Apple).

---

## 7. Integraciones externas

Documentadas a detalle en sus propios archivos; resumen aquí:

- **Original Auth** (`ORIGINAL_AUTH_INTEGRATION.md`): usado **únicamente** para verificar que el correo de un usuario nuevo es real, durante el registro. No participa en login, sesión, recuperación de contraseña ni eliminación de cuenta — eso siempre es 100% Supabase.
- **Original Pay** (`ORIGINAL_PAY_INTEGRATION.md`): dirección inversa — Original Pay le pregunta a HeartCoin (identificando al usuario por correo) cuánto HC tiene y puede registrar un cobro con HC, sin pasar por la app. **Implementado y probado de punta a punta**, incluyendo reembolso automático si un pago se rechaza.
- **MediaAAS**: almacenamiento de imágenes/documentos subidos desde la app (posts, perfiles, avatares), vía Edge Function proxy que firma con HMAC — la credencial nunca se expone en el cliente.
- **OpenStreetMap** (nuevo en esta ronda): tiles de mapa gratuitos, sin API key ni cuenta. Se usó también para geocodificar direcciones de texto a coordenadas (Nominatim) al sembrar datos de ejemplo con ubicación real.

Las tres integraciones server-to-server (Original Auth, Original Pay, MediaAAS) comparten el mismo patrón: firma HMAC-SHA256 por request, credenciales solo como secrets de Edge Functions, nunca en el cliente.

---

## 8. Base de datos — qué se agregó en esta ronda

`README.md` tiene el detalle completo de todas las tablas. Lo nuevo desde la última actualización de ese documento:

| Cambio | Detalle |
|---|---|
| `iniciativas.current_amount` | Monto ahorrado hasta ahora en una meta de Ahorro, editable por el Titular. |
| `iniciativa_participants` (tabla nueva) | Participantes reales de una meta de Ahorro (el Titular se deriva de `iniciativas.author_id`, no tiene fila propia aquí). |
| `iniciativa_join_requests` (tabla nueva) | Solicitudes de "quiero unirme" a una meta de Ahorro, con estado `pending`/`accepted`/`rejected`; aceptarla crea la fila en `iniciativa_participants` de forma atómica vía la función `accept_iniciativa_join_request()`. |
| `beneficios.location` / `latitude` / `longitude` | Ubicación del local, mismo shape que ya tenía `iniciativas`. |
| `servicios.location` / `latitude` / `longitude` | Igual que arriba, para servicios. |
| `publicaciones.iniciativa_id` | FK real a `iniciativas` (antes solo existía `initiative_name`, un texto suelto sin relación, que nunca se mostraba en ningún lado). |

Todas estas migraciones están versionadas en `SQL/migrations/` (no existían migraciones versionadas antes de esta ronda; el esquema se aplicaba directo en Supabase Studio). Se corrieron contra el proyecto activo con `supabase db query --linked -f ...`.

---

## 9. Publicación en Google Play — estado actual

Se dejó lista la parte técnica para publicar la app:

- **`applicationId` cambiado** de `com.example.heartcoin` (el de plantilla) a **`com.theoriginallab.heartcoin`** — permanente una vez publicado, no se puede cambiar después.
- **Firma de release real**: antes la app firmaba los releases con la clave de debug (Play Store no la acepta). Se generó una clave de firma real (`android/keystore/heartcoin-upload.jks` + `android/key.properties`, ambos fuera de git a propósito). **Hay que respaldar ese archivo en un lugar seguro** — si se pierde, no se pueden subir actualizaciones a la misma ficha sin pasar por recuperación con Google.
- **Política de privacidad pública**: se publicó el mismo texto legal que ya tenía la app (sin cambiar ni una palabra), con el diseño de `theoriginallab.com`, en una URL pública que Play Console exige — pendiente que Nico/el equipo la marque como compartida.
- Se generó exitosamente `app-release.aab` (72.6 MB), firmado y verificado.

**Lo que sigue siendo 100% manual** (cuenta de Play Console ya existe): subir el `.aab` a la pista de pruebas internas, completar el cuestionario de "Seguridad de los datos" (ya recopila ubicación, por los mapas de esta ronda), capturas de pantalla y descripción de la ficha, y la pregunta de "contenido restringido" (sí aplica — la app exige login; usar las cuentas demo de `CUENTAS_DEMO.md` como credenciales de prueba para el revisor).

**Sin construir todavía, y fuera de alcance por ahora**: Términos y condiciones (hay un tile en "Acerca de" que dice literalmente "Próximamente" — no hay contenido real), y notificaciones push reales (ver §6).

---

## 10. Cuentas de demo

Ver `CUENTAS_DEMO.md` para la lista completa con correos y tipo de perfil. Resumen:

- 20 cuentas Personal, 6 Organización, 3 Empresa, todas con contraseña `HeartCoin2026!`.
- **Ese archivo quedó parcialmente desactualizado por esta ronda de trabajo**: dice "20 beneficios y 20 servicios" pero los beneficios/servicios de ejemplo se reemplazaron por datos con ubicación real (15 beneficios repartidos en varias ciudades de México más 5 restaurantes en Durango, 10 servicios) — vale la pena actualizarlo o simplemente consultar las tablas `beneficios`/`servicios` directamente para el conteo real.

---

## 11. Pendientes conocidos (para decidir con el CEO/Nico)

Heredados de `README.md` (siguen sin resolver):
- Transferencias P2P de HC entre usuarios.
- De dónde sale el HC inicial de una organización para financiar sus propias campañas (no hay pasarela de pago).
- HC de "apoyar" (like) una iniciativa: decisión ya tomada de no otorgar nada.

Nuevos de esta ronda:
- **Beneficios/servicios no se pueden editar una vez publicados** (solo crear + activar/desactivar) — si una empresa quiere agregar ubicación a algo que ya publicó, o corregir un dato, hoy no puede.
- **Nadie recibe notificación** cuando alguien invita o solicita unirse a una meta de Ahorro — el otro usuario solo se entera si vuelve a abrir la pantalla.
- **Ubicación solo se captura por GPS** al momento de crear el beneficio/servicio (el teléfono tiene que estar físicamente en el local) — no hay forma de escribir una dirección a mano ni de editarla después.
- **Un admin** (panel web de administración, o un rol de administrador dentro de la app) — se discutió con el CEO y por ahora se dejó de lado a favor de enfocarse en publicar en Play Store.
- Términos y condiciones y notificaciones push reales — ver §9 y §6.

---

## 12. Dónde seguir leyendo

- `README.md` — referencia técnica rápida: estructura de carpetas, schema completo de base de datos, funciones RPC, guía de puesta en marcha.
- `ORIGINAL_AUTH_INTEGRATION.md` / `ORIGINAL_PAY_INTEGRATION.md` — cada integración externa a detalle.
- `ENDPOINTS.md` — referencia de endpoints/RPCs.
- `CUENTAS_DEMO.md` — credenciales de todas las cuentas de prueba.
- `SQL/migrations/` — historial versionado de cambios de esquema desde que se empezó a versionar.
