import 'package:flutter/material.dart';

import '../../services/common/location_preference_controller.dart';
import '../../services/common/text_scale_controller.dart';
import '../../theme/app_colors.dart';
import 'about_screen.dart';
import 'blocked_users_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_preferences_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tamaño de texto',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajusta qué tan grande se ve el texto en toda la app.',
            style: TextStyle(fontSize: 13, color: AppColors.gris600),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarioBlanco,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: TextScaleController.instance.scale,
              builder: (context, scale, _) {
                final percent = (scale * 100).round();
                final canDecrease = scale > TextScaleController.min + 0.001;
                final canIncrease = scale < TextScaleController.max - 0.001;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ScaleButton(
                          icon: Icons.remove,
                          onTap: canDecrease
                              ? TextScaleController.instance.decrease
                              : null,
                        ),
                        Column(
                          children: [
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primarioNegro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: TextScaleController.instance.reset,
                              child: const Text(
                                'Restablecer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primarioRojo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _ScaleButton(
                          icon: Icons.add,
                          onTap: canIncrease
                              ? TextScaleController.instance.increase
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Slider(
                      value: scale,
                      min: TextScaleController.min,
                      max: TextScaleController.max,
                      activeColor: AppColors.primarioRojo,
                      inactiveColor: AppColors.gris300,
                      onChanged: (value) =>
                          TextScaleController.instance.setScale(value),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gris100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Así se verá el texto en la app.',
                        style: TextStyle(color: AppColors.primarioNegro),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Cuenta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primarioBlanco,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  label: 'Editar perfil',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  label: 'Cambiar contraseña',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                _SettingsTile(
                  icon: Icons.notifications_none,
                  label: 'Notificaciones',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                _SettingsTile(
                  icon: Icons.visibility_outlined,
                  label: 'Privacidad',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                _SettingsTile(
                  icon: Icons.info_outline,
                  label: 'Acerca de',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                _SettingsTile(
                  icon: Icons.block_outlined,
                  label: 'Usuarios bloqueados',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.gris200),
                ValueListenableBuilder<bool>(
                  valueListenable:
                      LocationPreferenceController.instance.enabled,
                  builder: (context, enabled, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.location_on_outlined,
                        color: AppColors.gris700,
                      ),
                      title: Text(
                        'Preferencia de ubicación',
                        style: TextStyle(
                          color: AppColors.primarioNegro,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Usar tu ubicación para mostrar contenido cercano.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gris600,
                        ),
                      ),
                      value: enabled,
                      activeThumbColor: AppColors.primarioRojo,
                      onChanged:
                          LocationPreferenceController.instance.setEnabled,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Zona de riesgo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primarioBlanco,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _SettingsTile(
              icon: Icons.delete_outline,
              label: 'Eliminar cuenta',
              iconColor: AppColors.primarioRojo,
              labelColor: AppColors.primarioRojo,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.gris700),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? AppColors.primarioNegro,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.gris400, size: 20),
      onTap: onTap,
    );
  }
}

class _ScaleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _ScaleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarioRojo : AppColors.gris300,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
