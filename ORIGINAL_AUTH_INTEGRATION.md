# Integración HeartCoin ↔ Original Auth

Este documento describe, con detalle, el alcance acordado para integrar Original Auth con HeartCoin. La idea es que cualquiera del equipo —técnico o no— pueda leerlo y entender qué se va a construir, por qué, y qué no cambia.

**Estado: acordado con Nico, pendiente de implementación.**

---

## 1. Qué problema resuelve esto

Nico comunicó en el chat interno que, por requisito legal, todas las plataformas del equipo (webs, apps) necesitan incorporar de forma obligatoria dos cosas: **políticas de privacidad** y **eliminación de cuenta**. Ambas ya están resueltas en HeartCoin (ver `PrivacyPolicyScreen` y `DeleteAccountScreen`).

Como parte de esa misma conversación, surgió un tercer requisito relacionado: **verificar que el correo electrónico de cada usuario que se registra sea real** (que exista, que el usuario tenga acceso a él). Esto evita cuentas con correos inventados o mal escritos, y es una práctica estándar de cualquier plataforma seria.

En vez de construir nuestro propio sistema de envío y verificación de correos (lo cual implica contratar y configurar un servicio de correo transaccional, diseñar las plantillas, manejar los reintentos, etc. — trabajo que ya empezamos a explorar con Resend y que resultó tener varias dependencias, como tener un dominio propio verificado), la decisión fue **usar el sistema que Original Auth ya tiene construido y probado** para esto específicamente.

---

## 2. Decisión de arquitectura: qué rol juega cada sistema

Esta fue la pregunta central que se discutió con Nico a lo largo de varias conversaciones, porque había más de una forma de integrar Original Auth (desde reemplazar todo el sistema de login, hasta usarlo solo como un detalle menor). La versión final, confirmada por Nico, es la más acotada de todas:

> **Original Auth se usa únicamente para verificar el correo electrónico durante el registro. Nada más.**

Concretamente:

- **No** se usa Original Auth para iniciar sesión.
- **No** se usa Original Auth para manejar la sesión activa del usuario (tokens, expiración, etc.) dentro de HeartCoin.
- **No** se usa Original Auth para recuperar una contraseña olvidada.
- **No** se usa Original Auth para eliminar una cuenta.
- **No** hay ninguna migración de usuarios existentes hacia Original Auth.
- **No** hay ningún "puente" que traduzca una sesión de Original Auth en una sesión de Supabase (esa idea se consideró en una etapa anterior de la conversación con Nico, pero se descartó a favor de este alcance más simple).

**Supabase Auth sigue siendo, sin ningún cambio, la única fuente de verdad de HeartCoin** para todo lo relacionado con identidad y sesión: quién puede entrar, cómo se valida la contraseña del día a día, cómo se cierra sesión, y todas las reglas de seguridad de la base de datos (las llamadas "políticas RLS") que dependen de que Supabase sepa quién eres.

Original Auth, en este diseño, es literalmente un **servicio auxiliar que se consulta una sola vez, en un momento puntual del registro**, y después desaparece por completo del flujo del usuario. Es el equivalente a usar un servicio externo para mandar un SMS de verificación — importante, pero acotado a ese momento específico.

---

## 3. Flujo de registro completo, paso a paso

Así se vería el registro de un usuario nuevo con este cambio incorporado:

```
1. El usuario abre "Crear cuenta" en HeartCoin y llena el formulario
   (nombre, correo, contraseña, y los demás campos según su rol:
   Personal, Organización o Empresa — el formulario no cambia)

2. HeartCoin crea la cuenta en Supabase exactamente como lo hace hoy:
   - Se crea el usuario en el sistema de autenticación de Supabase
   - Se crea su fila de perfil correspondiente (personal_profiles,
     organization_profiles o company_profiles, según el rol)
   Hasta este punto, nada cambia respecto al comportamiento actual.

3. Justo después, HeartCoin llama a Original Auth:
   POST /api/v1/integrations/registration
   enviando el mismo correo y la misma contraseña que el usuario
   acaba de elegir en el formulario de HeartCoin.

   Esta llamada no la hace la app directamente — la hace una función
   intermedia de nuestro servidor (ver sección 5), por seguridad.

4. Original Auth, automáticamente y sin que HeartCoin tenga que hacer
   nada adicional, envía un correo con un código de verificación a la
   dirección que el usuario registró.

5. La app le muestra al usuario una pantalla del tipo "Revisa tu correo
   y escribe el código que te enviamos".

6. El usuario copia el código de 6 dígitos que recibió y lo escribe en
   esa pantalla.

7. HeartCoin llama a Original Auth:
   POST /api/v1/integrations/registration/verify-email
   con ese código.

8. Si el código es correcto, la cuenta queda marcada como verificada.
   A partir de aquí, el usuario ya no vuelve a interactuar con Original
   Auth — inicia sesión en HeartCoin de la forma normal, con Supabase,
   como cualquier otro usuario.
```

**Si el usuario no recibe el código** (correo en spam, error de tipeo corregido después, etc.), existe un endpoint para reenviarlo sin tener que registrarse de nuevo: `POST /api/v1/integrations/registration/resend-verification`.

---

## 4. Lo que NO cambia (y por qué es importante decirlo explícitamente)

Uno de los riesgos de este tipo de integraciones es que, sin querer, se termine tocando código que no hacía falta tocar. Por eso vale la pena dejar constancia explícita de que **estas pantallas y flujos, ya construidos, se quedan exactamente como están, sin ninguna modificación**:

- **Login** (`login_screen.dart` + `AuthService.signIn`): sigue validando contra Supabase, como siempre.
- **Recuperación de contraseña** (`forgot_password_screen.dart` → `verify_reset_code_screen.dart` → `reset_password_screen.dart`): este flujo ya lo construimos usando las capacidades propias de Supabase (código de 6 dígitos vía correo). No se conecta con Original Auth de ninguna forma.
- **Eliminación de cuenta** (`delete_account_screen.dart` + la función de servidor `delete-account`): sigue borrando la cuenta únicamente del lado de Supabase. Como Original Auth solo guarda una copia de la contraseña con fines de verificación (ver sección 7), no queda información "viva" de la cuenta del usuario ahí que requiera un borrado adicional más allá de esa copia.

---

## 5. Dónde vive técnicamente esta conexión

HeartCoin ya tiene un patrón establecido para este tipo de integraciones con servicios externos (lo usamos, por ejemplo, para subir imágenes a través de MediaAAS, y para el borrado de cuentas): **la aplicación móvil nunca habla directamente con el servicio externo**. En vez de eso:

1. La app le pide a **nuestro propio servidor** (una función ligera que corre en la nube de Supabase, llamada "Edge Function") que haga el registro de verificación.
2. Esa función de servidor es la que efectivamente llama a Original Auth, usando una credencial secreta (la API key) que **nunca sale del servidor** ni se guarda en el código de la aplicación.

Esto es importante por seguridad: si la API key estuviera dentro de la app móvil, cualquier persona podría extraerla (analizando el archivo instalable de la app) y usarla para hacer llamadas no autorizadas a Original Auth en nombre de HeartCoin.

**Detalles técnicos de esta conexión:**

- La API key vive únicamente como "secreto" configurado en la función de servidor, de la misma forma en que ya guardamos las credenciales de MediaAAS.
- Cada llamada a Original Auth debe ir firmada digitalmente (HMAC), porque la API key que nos van a entregar tiene esa opción de seguridad activada (`require_hmac`). Esto significa que, además de enviar la API key, cada petición incluye una firma calculada a partir del contenido exacto de esa petición — una protección adicional para que nadie pueda interceptar y reutilizar una petición válida.
- Los endpoints concretos de Original Auth que se usan son:
  - `POST /api/v1/integrations/registration` — crea el registro de verificación en Original Auth.
  - `POST /api/v1/integrations/registration/verify-email` — confirma el código que escribió el usuario.
  - `POST /api/v1/integrations/registration/resend-verification` — reenvía el código si hace falta.

---

## 6. El identificador de vínculo entre ambos sistemas

Cuando Original Auth registra la cuenta, su respuesta incluye un identificador propio y único para esa cuenta, con este formato:

```json
"user": {
  "id": "acct_6k2tq4v7mnbx8y3p9hzdw5jcqa",
  "email": "usuario@example.com"
}
```

Ese `id` (campo `data.user.id`) es público — no es un dato sensible — y lo vamos a guardar junto al perfil correspondiente del usuario en HeartCoin. Hoy no tiene un uso funcional inmediato (como se explicó, Original Auth no vuelve a intervenir después del registro), pero se guarda como buena práctica, por si en el futuro se necesita relacionar ambos sistemas — por ejemplo, para la integración con Original Pay que se discutió por separado, que si en algún momento necesita saber "qué cuenta de Original Auth corresponde a este usuario de HeartCoin", esa relación ya estaría guardada desde el registro, sin tener que reconstruirla después.

---

## 7. Nota importante sobre la contraseña

Este es el punto que vale la pena que quede más claro que ningún otro: **Original Auth va a terminar guardando una copia de la misma contraseña que el usuario eligió en HeartCoin**, porque así es como funciona su endpoint de registro (pide correo y contraseña juntos, no existe una forma de "solo verificar un correo" sin pasar también una contraseña).

Esto fue confirmado explícitamente como la decisión a seguir, así que no es un descuido, es intencional. Aun así, es importante remarcar sus implicaciones:

- Esa contraseña, dentro de Original Auth, **no se usa para nada** en el día a día del usuario — el usuario nunca inicia sesión a través de Original Auth, ni directa ni indirectamente. Es una copia inerte.
- El único sistema donde esa contraseña realmente se valida, se protege y controla el acceso real a la cuenta sigue siendo Supabase.
- Si el usuario cambia su contraseña en HeartCoin más adelante (desde "Cambiar contraseña" en Configuración, o recuperándola si la olvidó), **esa copia dentro de Original Auth no se actualiza automáticamente** — quedaría desactualizada, ya que ese flujo no vuelve a llamar a Original Auth. Esto no representa un problema de seguridad para HeartCoin (la contraseña vigente sigue siendo la de Supabase), pero es un detalle a tener presente.

---

## 8. Manejo de casos donde algo falla

Vale la pena anticipar qué pasa si algo no sale como se espera, para que el equipo esté al tanto:

- **Si Original Auth no responde o falla al momento del registro** (caída del servicio, error de red, etc.): la cuenta en HeartCoin/Supabase ya se creó en el paso 2, así que el usuario técnicamente puede usar la app. Hay que decidir si en ese caso se le pide reintentar la verificación más tarde, o si se le deja pasar sin verificar (ver punto abierto en la sección 9).
- **Si el usuario escribe mal el código de verificación varias veces**: Original Auth es quien controla cuántos intentos se permiten; HeartCoin simplemente le muestra al usuario el error que Original Auth devuelva.
- **Si el correo ya está registrado en Original Auth** (por ejemplo, porque el usuario se registró, no verificó, y lo intentó de nuevo): la guía de Original Auth indica que este caso devuelve un error de conflicto, que hay que manejar mostrando un mensaje adecuado en vez de un error genérico.

---

## 9. Puntos abiertos, pendientes de decidir con Nico

- **¿Qué pasa si el usuario nunca verifica su correo?** ¿Se le bloquea el uso de la app hasta que lo haga, o se le permite usarla con normalidad y solo se le recuerda ocasionalmente que le falta verificar? Esto es una decisión de producto, no técnica.
- **¿Aplica este mismo flujo si el usuario cambia su correo más adelante?** Hoy el formulario de "Editar perfil" no contempla cambiar el correo de la cuenta, pero si en el futuro se agrega esa opción, habría que decidir si también dispara una nueva verificación con Original Auth.
