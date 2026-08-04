# Cuentas de demo — HeartCoin

Listado de todas las cuentas que existen hoy en el proyecto de Supabase (`bamrvwzpcqwoyuwbvomw`), por rol. Sembradas el 31 de julio de 2026, después de limpiar por completo la base de datos anterior (cuentas y contenido previos). Todas comparten la contraseña:

```
HeartCoin2026!
```

Todas las cuentas fueron creadas directo por la Admin API de Supabase (no a través del formulario de registro de la app), con el correo ya confirmado — el mismo método usado en la siembra original.

---

## Personal (`personal_profiles`)

Autoras de las **50 publicaciones** (10 por cuenta), cada publicación con imagen real subida a MediaAAS y **10 comentarios** (500 en total, rotando entre las 5 cuentas como autoras de los comentarios). Las 5 cuentas tienen foto de perfil (`avatar_url`).

| Nombre | Correo | Tipo de perfil | Ciudad |
|---|---|---|---|
| Ana Martínez | `ana.martinez@heartcoin-demo.mx` | Voluntario | Durango |
| Carlos López | `carlos.lopez@heartcoin-demo.mx` | Emprendedor | Guadalajara |
| Sofía Hernández | `sofia.hernandez@heartcoin-demo.mx` | Estudiante | Monterrey |
| Diego Ramírez | `diego.ramirez@heartcoin-demo.mx` | Profesional | Puebla |
| Valeria Torres | `valeria.torres@heartcoin-demo.mx` | Investigador | Mérida |

---

## Organización (`organization_profiles`)

Autoras de **200 iniciativas** (40 por organización: 10 de cada categoría — Voluntariado, Crowdfunding, Social, Ahorro —, todas en `status = 'activa'`). Las 5 organizaciones tienen logo (`logo_url`).

| Organización | Correo | Tipo | Área de impacto | Ciudad |
|---|---|---|---|---|
| Raíces Verdes A.C. | `contacto@raicesverdes-demo.mx` | Asociación Civil | Medio ambiente | Durango |
| Manos Unidas MX | `contacto@manosunidas-demo.mx` | Fundación | Pobreza | Ciudad de México |
| Futuro Educativo | `contacto@futuroeducativo-demo.mx` | ONG | Educación | Puebla |
| Salud Para Todos | `contacto@saludparatodos-demo.mx` | Fundación | Salud | Guadalajara |
| EcoAcción | `contacto@ecoaccion-demo.mx` | Organización Internacional | Medio ambiente | Monterrey |

---

## Empresa (`company_profiles`)

Entre las 5 hay **25 beneficios** (locales de comida, supermercados y tiendas ficticias, repartidos en 10 ciudades de México, todos con imagen real subida a MediaAAS) y **25 servicios** (consultoría, tecnología, diseño, legal, marketing, capacitación), 5 de cada uno vez marcados como "destacado". Las 5 empresas tienen logo (`logo_url`).

| Empresa | Correo | Industria | Empleados | Objetivo principal | Ciudad |
|---|---|---|---|---|---|
| Grupo Sabor MX | `contacto@gruposabor-demo.mx` | Retail | 201-500 | Responsabilidad Social Empresarial (RSE) | Ciudad de México |
| Mercado Fresco | `contacto@mercadofresco-demo.mx` | Retail | 501-1000 | ESG | Guadalajara |
| Moda Express | `contacto@modaexpress-demo.mx` | Retail | 51-200 | Marketplace de impacto | Monterrey |
| TecnoDigital | `contacto@tecnodigital-demo.mx` | Tecnología | 11-50 | Medición de impacto | Querétaro |
| Casa y Comodidad | `contacto@casaycomodidad-demo.mx` | Retail | 201-500 | Donaciones | León |

Para el listado completo de beneficios/servicios, consulta las tablas `beneficios`/`servicios` filtrando por `company_name` — con 25 de cada uno, no tiene sentido mantener el detalle línea por línea aquí (se desactualiza rápido).

---

## Notas

- Este archivo refleja el estado de la base al momento de escribirlo (31 de julio de 2026); si se crean o eliminan cuentas después, puede quedar desactualizado — para el estado real, consulta `personal_profiles` / `organization_profiles` / `company_profiles` directamente.
- Las imágenes de las publicaciones, de los 25 beneficios y las fotos de perfil/logos de las 15 cuentas fueron subidas realmente a MediaAAS a través de la Edge Function `upload-media` (no son URLs de placeholder embebidas directo en la base de datos). Los servicios no tienen columna de imagen en el esquema actual.
- Todas las iniciativas se crearon directamente con `status = 'activa'` (saltando la fase de votación), para que la demo muestre contenido funcional de inmediato.
