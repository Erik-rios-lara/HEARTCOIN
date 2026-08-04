# MediaAAS — Guia de Integracion de API Cliente

> Generado el 2026-06-12. Fuente: Dashboard de Documentacion de MediaAAS.
> Este archivo esta disenado para ser consumido por desarrolladores y agentes IA.
### API de MAAS
https://getfile.media-as-a-service.io
---

## Indice

1. [Que es MediaAAS](#que-es-mediaas)
2. [Inicio Rapido](#inicio-rapido)
3. [Autenticacion HMAC-SHA256](#autenticacion-hmac-sha256)
4. [Endpoints](#endpoints)
5. [Webhooks](#webhooks)
6. [Errores Comunes](#errores-comunes)
7. [Resumen para Agentes IA](#resumen-para-agentes-ia)

---

## Que es MediaAAS

MediaAAS es una plataforma SaaS para almacenar, gestionar y servir contenido multimedia (imagenes, videos, audio y documentos) via API REST.

**Jerarquia de entidades:**

```
cliente (tu empresa)
  └── app (aplicacion registrada, tiene api_key propia)
        └── carpeta (agrupa archivos dentro de la app)
              └── archivo (multimedia almacenado en S3/CloudFront)
```

**Base URL:** `{API_HOST}`

Todos los endpoints de la API Cliente tienen el prefijo `/client/`.

---

## Inicio Rapido

El siguiente ejemplo hace un request autenticado a `GET /client/files/` en menos de 30 lineas.

```python
import hmac, hashlib, time, requests

API_KEY    = "tu_api_key"
SECRET_KEY = "tu_secret_key"
HOST       = "{API_HOST}"

def firmar(method, path, body_bytes=b""):
    ts         = int(time.time())
    body_hash  = hashlib.sha256(body_bytes).hexdigest()
    canonical  = f"{method}\n{path}\n{ts}\n{body_hash}"
    firma      = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return ts, f"sha256={firma}"

ts, sig = firmar("GET", "/client/files/")
resp = requests.get(
    f"{HOST}/client/files/",
    headers={"X-Api-Key": API_KEY, "X-Timestamp": str(ts), "X-Signature": sig},
)
print(resp.json())
```

```javascript
import crypto from 'node:crypto';

const API_KEY    = 'tu_api_key';
const SECRET_KEY = 'tu_secret_key';
const HOST       = '{API_HOST}';

function firmar(method, path, bodyBytes = Buffer.alloc(0)) {
    const ts       = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${ts}\n${bodyHash}`;
    const firma    = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { ts, sig: `sha256=${firma}` };
}

const { ts, sig } = firmar('GET', '/client/files/');
const resp = await fetch(`${HOST}/client/files/`, {
    headers: { 'X-Api-Key': API_KEY, 'X-Timestamp': String(ts), 'X-Signature': sig },
});
console.log(await resp.json());
```

---

## Autenticacion HMAC-SHA256

Todos los endpoints `/client/*` requieren tres headers en cada request.

### Credenciales

Cada App registrada en el dashboard tiene **dos credenciales**. Las obtienes en la seccion de tu cliente → Apps → Generar keys:

| Credencial | Visibilidad | Uso |
|------------|-------------|-----|
| `api_key` | Publica — visible en el dashboard | Se envia en el header `X-Api-Key` de cada request. |
| `secret_key` | Privada — se muestra **una sola vez** al generarla | Nunca viaja en los requests. Se usa localmente para generar la firma HMAC. |

> Guarda la `secret_key` en una variable de entorno. Si la pierdes, deberas regenerar el par de credenciales desde el dashboard.

### Headers requeridos

| Header | Descripcion |
|--------|-------------|
| `X-Api-Key` | Tu `api_key` (publica). Identifica al cliente y la app. |
| `X-Timestamp` | Unix timestamp (segundos). El servidor rechaza timestamps con diferencia > 5 minutos. |
| `X-Signature` | Firma HMAC-SHA256 del mensaje canonico, generada con tu `secret_key`. Formato: `sha256=<hex>`. |

### Mensaje canonico

El mensaje que se firma tiene exactamente cuatro lineas:

```
{METHOD}
{PATH_CON_QUERY_ORDENADO}
{UNIX_TIMESTAMP}
{SHA256_HEX_DEL_BODY}
```

**Reglas:**

- `PATH_CON_QUERY_ORDENADO`: la ruta completa incluyendo query string con los parametros ordenados
  alfabeticamente. Sin host ni esquema. Ejemplo: `/client/files/?media_type=image&page=1`
- `SHA256_HEX_DEL_BODY`: hash SHA256 del cuerpo del request en hex lowercase.
  Para requests sin body (GET, DELETE) usar el hash del string vacio:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- **EXCEPCION multipart**: para `POST /client/upload` (multipart/form-data) el body NO se hashea.
  Siempre usar el hash de string vacio. La integridad binaria se delega a TLS.
- El `Content-Type` NO entra en el mensaje canonico.

### Helper de firma

```python
import hmac, hashlib, time

def sign_request(api_key, secret_key, method, path, body_bytes=b"", is_multipart=False):
    """Genera los headers de autenticacion para un request a MediaAAS."""
    timestamp  = int(time.time())
    body_hash  = hashlib.sha256(b"" if is_multipart else body_bytes).hexdigest()
    canonical  = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    signature  = hmac.new(secret_key.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return {
        "X-Api-Key":   api_key,
        "X-Timestamp": str(timestamp),
        "X-Signature": f"sha256={signature}",
    }
```

```javascript
import crypto from 'node:crypto';

function signRequest(apiKey, secretKey, method, path, bodyBytes = Buffer.alloc(0), isMultipart = false) {
    const ts       = Math.floor(Date.now() / 1000);
    const toHash   = isMultipart ? Buffer.alloc(0) : bodyBytes;
    const bodyHash = crypto.createHash('sha256').update(toHash).digest('hex');
    const canonical = `${method}\n${path}\n${ts}\n${bodyHash}`;
    const sig      = crypto.createHmac('sha256', secretKey).update(canonical).digest('hex');
    return { 'X-Api-Key': apiKey, 'X-Timestamp': String(ts), 'X-Signature': `sha256=${sig}` };
}
```

---

## Endpoints

### `GET` /client/files/

**Listar archivos del cliente**

Devuelve un listado paginado de archivos pertenecientes al cliente autenticado. El aislamiento es estricto: aunque se envie un folder_id de otro cliente, el sistema solo devuelve archivos propios. Nunca expone la identidad del creador (user_id).

> **Notas:**
> - El campo media_url siempre esta presente y requiere firma HMAC para acceder.
> - El campo public_url solo tiene valor cuando is_public=true. Apunta a GET /public/{s3_key}, accesible sin autenticacion. Si el archivo es privado, public_url es null.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `folder_id` | query | integer | No | Filtra por carpeta. Sin este param devuelve todos los archivos del cliente. |
| `app_id` | query | integer | No | Filtra por aplicacion. Verificado contra el cliente autenticado. |
| `media_type` | query | string | No | Filtra por tipo: image | video | audio | document |
| `is_public` | query | boolean | No | Filtra por visibilidad publica: true | false |
| `search` | query | string | No | Busqueda por nombre de archivo (case-insensitive, parcial). |
| `page` | query | integer | No | Numero de pagina (default: 1). |
| `page_size` | query | integer | No | Registros por pagina (default: 50, max: 100). |

**Respuesta exitosa**

```json
{
  "items": [
    {
      "file_id": 42,
      "original_name": "banner-home.jpg",
      "media_type": "image",
      "mime_type": "image/jpeg",
      "file_size": 204800,
      "is_public": false,
      "media_url": "/client/media/acme/mi-app/image/a1b2c3d4-banner-home.jpg",
      "public_url": null,
      "folder_id": 7,
      "create_date": "2026-04-23T14:00:00"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 50,
  "pages": 1
}
```

**cURL**

```bash
curl \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  "{API_HOST}/client/files/?folder_id={folder_id}&app_id={app_id}&media_type={media_type}&is_public={is_public}&search={search}&page={page}&page_size={page_size}"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"

params = {
    # "folder_id": ...,  # Filtra por carpeta. Sin este param devuelve todos los archivos del cliente.
    # "app_id": ...,  # Filtra por aplicacion. Verificado contra el cliente autenticado.
    # "media_type": ...,  # Filtra por tipo: image | video | audio | document
    # "is_public": ...,  # Filtra por visibilidad publica: true | false
    # "search": ...,  # Busqueda por nombre de archivo (case-insensitive, parcial).
    # "page": ...,  # Numero de pagina (default: 1).
    # "page_size": ...,  # Registros por pagina (default: 50, max: 100).
}

body_bytes = json.dumps(body).encode() if body else b""
timestamp, signature = sign_request("GET", "/client/files/")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.get(
    f"{HOST}/client/files/",
    params=params,
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

const body = { /* params del body */ };
const bodyBytes = Buffer.from(JSON.stringify(body));
const { timestamp, signature } = signRequest('GET', '/client/files/', bodyBytes);

const resp = await fetch(`{API_HOST}/client/files/?{params}`, {
    method: 'GET',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
        'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
});

const data = await resp.json();
console.log(resp.status, data);
```

---

### `GET` /client/media/{s3_key}

**Obtener URL firmada de un archivo**

Genera una URL firmada de CloudFront y redirige (HTTP 302). Con ?format=json devuelve la URL en JSON sin redirigir, util para clientes que no pueden seguir redirecciones. El archivo debe pertenecer al cliente autenticado; de lo contrario devuelve 404 (nunca 403, para no revelar la existencia de archivos de otros clientes).

> **Notas:**
> - Sin ?format=json el endpoint devuelve 302 redirect directamente.
> - La URL firmada tiene una duracion configurable via SIGNED_URL_TTL_SECONDS (default: 3600s).
> - Alternativa sin autenticacion: los archivos con is_public=true también son accesibles via GET /public/{s3_key} sin ningun header de firma. La URL estable esta en el campo public_url de la respuesta de GET /client/files/. Util para incrustar en <img src> o compartir enlaces directos.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `s3_key` | path | string | Si | Clave S3 del archivo. Formato: {client-slug}/{app-slug}/{media_type}/{uuid}-{nombre}.{ext} |
| `format` | query | string | No | Si es 'json', devuelve JSON en lugar de redirigir. |

**Respuesta exitosa**

```json
{
  "url": "https://cdn.example.com/acme/mi-app/image/a1b2c3d4-banner.jpg?Expires=1714003600&...",
  "file_id": 42,
  "original_name": "banner-home.jpg",
  "mime_type": "image/jpeg",
  "media_type": "image",
  "file_size": 204800
}
```

**cURL**

```bash
curl \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  "{API_HOST}/client/media/{s3_key}?format={format}"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"

params = {
    # "format": ...,  # Si es 'json', devuelve JSON en lugar de redirigir.
}

body_bytes = json.dumps(body).encode() if body else b""
timestamp, signature = sign_request("GET", "/client/media/{s3_key}")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.get(
    f"{HOST}/client/media/{s3_key}",
    params=params,
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

const body = { /* params del body */ };
const bodyBytes = Buffer.from(JSON.stringify(body));
const { timestamp, signature } = signRequest('GET', '/client/media/{s3_key}', bodyBytes);

const resp = await fetch(`{API_HOST}/client/media/{s3_key}?{params}`, {
    method: 'GET',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
        'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
});

const data = await resp.json();
console.log(resp.status, data);
```

---

### `POST` /client/folders/

**Crear una carpeta**

Crea una nueva carpeta dentro de una aplicacion del cliente autenticado. La carpeta queda vinculada al creador de la App, no a un usuario del dashboard.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `app_id` | body | integer | Si | ID de la aplicacion donde crear la carpeta. |
| `name` | body | string | Si | Nombre de la carpeta. |
| `parent_id` | body | integer | No | ID de la carpeta padre para anidamiento (opcional). |

**Respuesta exitosa**

```json
{
  "status": "ok",
  "folder_id": 15
}
```

**cURL**

```bash
curl -X POST \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  -H "Content-Type: application/json" \
  -d '{
  "app_id": 0,
  "name": "{name}",
  "parent_id": 0
}' \
  "{API_HOST}/client/folders/"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"

body = {
    "app_id": ...,  # integer, requerido
    "name": ...,  # string, requerido
    "parent_id": ...,  # integer
}

body_bytes = json.dumps(body).encode() if body else b""
timestamp, signature = sign_request("POST", "/client/folders/")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.post(
    f"{HOST}/client/folders/",
    json=body,
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

const body = { /* params del body */ };
const bodyBytes = Buffer.from(JSON.stringify(body));
const { timestamp, signature } = signRequest('POST', '/client/folders/', bodyBytes);

const resp = await fetch(`{API_HOST}/client/folders/`, {
    method: 'POST',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
        'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
});

const data = await resp.json();
console.log(resp.status, data);
```

---

### `POST` /client/upload

**Subir un archivo**

Recibe un archivo binario como multipart/form-data y lo almacena en S3. Si no se especifica folder_id, el archivo se deposita en una carpeta 'Uploads API' creada automaticamente para la aplicacion. El user_id del archivo queda en NULL (operacion maquina a maquina). Dispara el webhook file.uploaded si la app tiene webhook_url configurado.

> **Notas:**
> - FIRMA ESPECIAL: para multipart/form-data el body NO se incluye en el calculo del hash canonico. Usar SHA256 de string vacio: e3b0c44298fc1c149afbf4c8996fb924 (truncado). Esto evita cargar el binario en memoria.
> - La integridad binaria se delega a TLS/HTTPS.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `file` | form | file | Si | Archivo binario a subir. |
| `file_name` | form | string | Si | Nombre original del archivo (se preserva en BD). |
| `folder_id` | form | integer | No | ID de la carpeta destino. Sin valor, se usa 'Uploads API'. |
| `is_public` | form | boolean | No | Si true, el archivo sera accesible sin autenticacion via /public/{s3_key}. |

**Respuesta exitosa**

```json
{
  "status": "ok",
  "file_id": 43,
  "s3_key": "acme/mi-app/image/a1b2c3d4-banner-home.jpg",
  "original_name": "banner-home.jpg",
  "media_type": "image",
  "is_public": false,
  "media_url": "/client/media/acme/mi-app/image/a1b2c3d4-banner-home.jpg",
  "public_url": null
}
```

**cURL**

```bash
curl -X POST \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  -F "file=@archivo.jpg" \
  -F "file_name={file_name}" \
  -F "folder_id={folder_id}" \
  -F "is_public={is_public}" \
  "{API_HOST}/client/upload"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"


# NOTA: multipart — body_hash usa string vacio (no el binario)
body_bytes = b""
timestamp, signature = sign_request("POST", "/client/upload")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.post(
    f"{HOST}/client/upload",
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

// NOTA: multipart — body_hash usa string vacio
const bodyBytes = Buffer.alloc(0);
const { timestamp, signature } = signRequest('POST', '/client/upload', bodyBytes);

const resp = await fetch(`{API_HOST}/client/upload`, {
    method: 'POST',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
    },
});

const data = await resp.json();
console.log(resp.status, data);
```

---

### `PATCH` /client/files/{file_id}

**Actualizar metadatos de un archivo**

Modifica los metadatos de un archivo existente. Solo se actualizan los campos enviados (PATCH parcial). Dispara el webhook file.updated.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `file_id` | path | integer | Si | ID del archivo a modificar. |
| `original_name` | body | string | No | Nuevo nombre del archivo. |
| `is_public` | body | boolean | No | Cambia la visibilidad publica del archivo. |

**Respuesta exitosa**

```json
{
  "status": "ok"
}
```

**cURL**

```bash
curl -X PATCH \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  -H "Content-Type: application/json" \
  -d '{
  "original_name": "{original_name}",
  "is_public": false
}' \
  "{API_HOST}/client/files/{file_id}"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"

body = {
    "original_name": ...,  # string
    "is_public": ...,  # boolean
}

body_bytes = json.dumps(body).encode() if body else b""
timestamp, signature = sign_request("PATCH", "/client/files/{file_id}")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.patch(
    f"{HOST}/client/files/{file_id}",
    json=body,
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

const body = { /* params del body */ };
const bodyBytes = Buffer.from(JSON.stringify(body));
const { timestamp, signature } = signRequest('PATCH', '/client/files/{file_id}', bodyBytes);

const resp = await fetch(`{API_HOST}/client/files/{file_id}`, {
    method: 'PATCH',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
        'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
});

const data = await resp.json();
console.log(resp.status, data);
```

---

### `DELETE` /client/files/{file_id}

**Eliminar un archivo**

Elimina permanentemente el archivo de la base de datos y su objeto en S3. Esta accion no tiene vuelta atras. Dispara el webhook file.deleted.

**Parametros**

| Nombre | Ubicacion | Tipo | Requerido | Descripcion |
|--------|-----------|------|-----------|-------------|
| `file_id` | path | integer | Si | ID del archivo a eliminar. |

**Respuesta exitosa**

```json
{
  "status": "ok"
}
```

**cURL**

```bash
curl -X DELETE \
  -H "X-Api-Key: {tu_api_key}" \
  -H "X-Timestamp: {timestamp}" \
  -H "X-Signature: {sha256=firma_generada}" \
  "{API_HOST}/client/files/{file_id}"
```

**Python**

```python
import hmac, hashlib, time, json
import requests

API_KEY = "{tu_api_key}"
SECRET_KEY = "{tu_secret_key}"
HOST = "{API_HOST}"

def sign_request(method, path, body_bytes=b""):
    timestamp = int(time.time())
    body_hash = hashlib.sha256(body_bytes).hexdigest()
    canonical = f"{method}\n{path}\n{timestamp}\n{body_hash}"
    sig = hmac.new(SECRET_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    return timestamp, f"sha256={sig}"


body_bytes = json.dumps(body).encode() if body else b""
timestamp, signature = sign_request("DELETE", "/client/files/{file_id}")

headers = {
    "X-Api-Key": API_KEY,
    "X-Timestamp": str(timestamp),
    "X-Signature": signature,
}

resp = requests.delete(
    f"{HOST}/client/files/{file_id}",
    headers=headers,
)
print(resp.status_code, resp.json())
```

**Node.js**

```javascript
import crypto from 'node:crypto';

const API_KEY = '{tu_api_key}';
const SECRET_KEY = '{tu_secret_key}';

function signRequest(method, path, bodyBytes = Buffer.alloc(0)) {
    const timestamp = Math.floor(Date.now() / 1000);
    const bodyHash = crypto.createHash('sha256').update(bodyBytes).digest('hex');
    const canonical = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
    const sig = crypto.createHmac('sha256', SECRET_KEY).update(canonical).digest('hex');
    return { timestamp, signature: `sha256=${sig}` };
}

const body = { /* params del body */ };
const bodyBytes = Buffer.from(JSON.stringify(body));
const { timestamp, signature } = signRequest('DELETE', '/client/files/{file_id}', bodyBytes);

const resp = await fetch(`{API_HOST}/client/files/{file_id}`, {
    method: 'DELETE',
    headers: {
        'X-Api-Key': API_KEY,
        'X-Timestamp': String(timestamp),
        'X-Signature': signature,
        'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
});

const data = await resp.json();
console.log(resp.status, data);
```

---


---

## Webhooks

MediaAAS envia webhooks a la URL configurada en tu App (`callback_url`) en cada operacion de escritura exitosa realizada via API Cliente.

### Eventos disponibles

| Evento | Cuando se dispara |
|--------|-------------------|
| `file.uploaded` | Al subir un archivo via `POST /client/upload` |
| `file.updated` | Al modificar metadatos via `PATCH /client/files/{id}` |
| `file.deleted` | Al eliminar via `DELETE /client/files/{id}` |

### Estructura del payload

```json
{
  "event": "file.uploaded",
  "timestamp": 1714003600,
  "app_id": 1,
  "data": {
    "file_id": 43,
    "original_name": "banner.jpg",
    "media_type": "image",
    "s3_key": "acme/mi-app/image/a1b2c3-banner.jpg",
    "is_public": false
  }
}
```

### Verificacion de firma del webhook

Cada webhook incluye el header `X-Signature` firmado con el mismo mecanismo HMAC-SHA256.
El mensaje canonico del webhook usa el body JSON del evento como payload.

```python
import hmac, hashlib

def verify_webhook(secret_key: str, payload_bytes: bytes, signature_header: str) -> bool:
    """Verifica la firma de un webhook entrante de MediaAAS."""
    expected = "sha256=" + hmac.new(
        secret_key.encode(), payload_bytes, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)
```

```javascript
import crypto from 'node:crypto';

function verifyWebhook(secretKey, payloadBuffer, signatureHeader) {
    const expected = 'sha256=' + crypto
        .createHmac('sha256', secretKey)
        .update(payloadBuffer)
        .digest('hex');
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signatureHeader));
}
```

**Importante:** usa siempre comparacion de tiempo constante (`hmac.compare_digest` / `timingSafeEqual`)
para evitar ataques de timing.

**Reintentos:** el sistema reintenta con backoff exponencial hasta 5 veces si tu endpoint no responde
con 2xx dentro de los 10 segundos.

---

## Errores Comunes

| Codigo | Causa tipica | Solucion |
|--------|--------------|----------|
| `401` | Headers de firma ausentes o malformados | Verificar que los tres headers esten presentes |
| `403` | Firma invalida o timestamp fuera de ventana | Sincronizar el reloj del servidor; verificar el algoritmo de firma |
| `403` | API Key desactivada o no existe | Regenerar las keys en el dashboard |
| `404` | Archivo no encontrado o de otro cliente | El aislamiento es estricto; verificar que el file_id pertenezca a tu cliente |
| `422` | Parametros de body invalidos | Verificar tipos y campos requeridos |
| `429` | Rate limit excedido | Reducir la frecuencia de requests; el limite se aplica por IP |

### Ventana de timestamp

El servidor rechaza requests con `X-Timestamp` que difiera mas de **5 minutos** del tiempo actual del servidor.
Asegurate de que el reloj de tu sistema este sincronizado (NTP).

---

## Resumen para Agentes IA

Este resumen esta disenado para que un agente de IA pueda implementar la integracion sin contexto adicional.

**Servicio:** MediaAAS — API REST SaaS para gestion de archivos multimedia.

**Base URL:** `{API_HOST}`

**Credenciales:** cada App tiene dos: `api_key` (publica, va en el header) y `secret_key` (privada, nunca viaja en requests — solo se usa para firmar localmente). Ambas se obtienen del dashboard al registrar la App.

**Autenticacion:** HMAC-SHA256. Requiere tres headers por request:
- `X-Api-Key`: tu `api_key` publica.
- `X-Timestamp`: Unix epoch en segundos.
- `X-Signature`: `sha256=<hmac_hex>` del mensaje canonico firmado con tu `secret_key`: `METHOD\nPATH_CON_QUERY\nTIMESTAMP\nSHA256_BODY`.
- Para multipart, siempre usar SHA256 de string vacio como body hash.

**Endpoints disponibles:**

- `GET /client/files/` — Listar archivos del cliente
- `GET /client/media/{s3_key}` — Obtener URL firmada de un archivo
- `POST /client/folders/` — Crear una carpeta
- `POST /client/upload` — Subir un archivo
- `PATCH /client/files/{file_id}` — Actualizar metadatos de un archivo
- `DELETE /client/files/{file_id}` — Eliminar un archivo

**Reglas de aislamiento:**
- El `client_id` se extrae del `X-Api-Key`. No existe parametro para especificarlo.
- Un cliente nunca puede acceder a recursos de otro cliente; las respuestas siempre retornan 404 (no 403) para no revelar existencia.
- El `user_id` interno de MediaAAS nunca se expone en las respuestas de la API Cliente.

**Formato de respuesta:** JSON. Listas paginadas retornan `{ items, total, page, page_size, pages }`.

**Webhooks:** Cada escritura exitosa dispara un POST firmado a la `callback_url` de la App con el payload del evento.
