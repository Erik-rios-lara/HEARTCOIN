import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Aviso de privacidad de HeartCoin. Texto legal — cambios de contenido
/// deben pasar por revisión legal antes de publicarse, no solo por code
/// review.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Política de privacidad'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _LastUpdated(),
          SizedBox(height: 16),
          _Section(
            title: '1. Responsable del tratamiento de datos',
            body:
                'The Original Lab ("nosotros", "HeartCoin") es responsable del '
                'tratamiento de los datos personales que recabamos a través de '
                'la aplicación HeartCoin, de acuerdo con este aviso de '
                'privacidad y con la legislación aplicable en materia de '
                'protección de datos personales.',
          ),
          _Section(
            title: '2. Datos que recabamos',
            body:
                'Dependiendo del rol con el que te registras (Personal, '
                'Organización o Empresa), podemos recabar:\n\n'
                '• Datos de identificación: nombre completo, correo '
                'electrónico, teléfono, país y ciudad.\n'
                '• Datos de perfil: fotografía de perfil, biografía, tipo de '
                'perfil o giro/industria (según el rol).\n'
                '• Datos de organización o empresa: nombre de la '
                'organización/empresa, nombre del representante, cargo, '
                'correo corporativo.\n'
                '• Contenido que publicas: publicaciones, imágenes, '
                'documentos, comentarios y "me gusta".\n'
                '• Datos de ubicación: solo si activas la preferencia de '
                'ubicación en Configuración, para hacer check-in en '
                'iniciativas y ordenar contenido cercano. Puedes desactivarla '
                'en cualquier momento.\n'
                '• Historial de HeartCoins (HC): tus movimientos de saldo '
                '(ganados y canjeados) y con qué actividad, beneficio o '
                'servicio se relacionan.\n'
                '• Datos técnicos de la cuenta: contraseña (almacenada de '
                'forma cifrada, nunca en texto plano) e identificador único '
                'de usuario.',
          ),
          _Section(
            title: '3. Para qué usamos tus datos',
            body:
                '• Crear y administrar tu cuenta y perfil.\n'
                '• Mostrar tu perfil, publicaciones e interacciones a otros '
                'usuarios, según tu configuración de privacidad.\n'
                '• Calcular y mostrar tu saldo de HeartCoins y su historial.\n'
                '• Validar check-ins mediante geolocalización, cuando la '
                'preferencia de ubicación está activada.\n'
                '• Enviarte notificaciones dentro de la app sobre actividad '
                'relacionada contigo (puedes desactivarlas por tipo en '
                'Configuración).\n'
                '• Cumplir obligaciones legales y de seguridad de la '
                'plataforma.',
          ),
          _Section(
            title: '4. Con quién compartimos tus datos',
            body:
                'No vendemos tus datos personales. Para operar la app, '
                'utilizamos proveedores de infraestructura que procesan datos '
                'en nuestro nombre, bajo sus propias políticas de seguridad:\n\n'
                '• Supabase: aloja la base de datos, la autenticación y el '
                'almacenamiento en tiempo real de la app.\n'
                '• MediaAAS: almacena las imágenes y documentos que subes a '
                'tus publicaciones y perfil.\n\n'
                'Estos proveedores solo tienen acceso a los datos necesarios '
                'para prestar su servicio y no están autorizados a usarlos '
                'con otro fin.',
          ),
          _Section(
            title: '5. Tus derechos (ARCO)',
            body:
                'Puedes ejercer en cualquier momento tus derechos de Acceso, '
                'Rectificación, Cancelación y Oposición sobre tus datos '
                'personales:\n\n'
                '• Acceso y rectificación: desde "Editar perfil" en '
                'Configuración puedes consultar y actualizar tus datos '
                'directamente.\n'
                '• Cancelación: desde "Eliminar cuenta" en Configuración '
                'puedes borrar permanentemente tu cuenta y todos los datos '
                'asociados (perfil, publicaciones, historial de HC, etc.). '
                'Esta acción no se puede deshacer.\n'
                '• Oposición y otras solicitudes: escríbenos a '
                'lab@theoriginallab.com.',
          ),
          _Section(
            title: '6. Menores de edad',
            body:
                'HeartCoin no está dirigida a menores de edad. Si detectamos '
                'una cuenta creada por un menor sin la autorización '
                'correspondiente, podremos eliminarla.',
          ),
          _Section(
            title: '7. Seguridad',
            body:
                'Aplicamos medidas técnicas y administrativas razonables para '
                'proteger tus datos, incluyendo reglas de acceso a nivel de '
                'base de datos que limitan qué información puede leer o '
                'modificar cada usuario, y cifrado de contraseñas. Ningún '
                'sistema es 100% infalible, pero trabajamos para mantener tus '
                'datos seguros.',
          ),
          _Section(
            title: '8. Cambios a este aviso',
            body:
                'Podemos actualizar este aviso de privacidad periódicamente. '
                'Si los cambios son significativos, te avisaremos dentro de '
                'la app antes de que entren en vigor.',
          ),
          _Section(
            title: '9. Contacto',
            body:
                'Si tienes dudas sobre este aviso de privacidad o sobre el '
                'tratamiento de tus datos, escríbenos a '
                'lab@theoriginallab.com.',
          ),
        ],
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  const _LastUpdated();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Última actualización: 13 de julio de 2026',
      style: TextStyle(fontSize: 12, color: AppColors.gris600),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.gris700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
