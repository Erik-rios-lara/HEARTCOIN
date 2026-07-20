import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

/// Control de visibilidad del perfil: cuando está desactivado, otros
/// usuarios ya no pueden leer el nombre/ciudad/avatar del perfil
/// (RLS a nivel de fila sobre `is_public`), aunque el dueño siempre
/// puede ver el suyo.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _client
          .from('personal_profiles')
          .select('is_public')
          .eq('id', userId)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() => _isPublic = data['is_public'] as bool? ?? true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPublic(bool value) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isPublic = value);
    try {
      await _client
          .from('personal_profiles')
          .update({'is_public': value})
          .eq('id', userId);
    } catch (_) {
      if (mounted) {
        setState(() => _isPublic = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el cambio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Privacidad'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.primarioRojo,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perfil visible para otros usuarios',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primarioNegro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Si lo desactivas, otras personas ya no podrán ver tu nombre, '
                              'ciudad ni foto de perfil en la comunidad o el ranking. Tú '
                              'siempre puedes ver tu propio perfil.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.gris600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: _setPublic,
                        activeThumbColor: AppColors.primarioRojo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
