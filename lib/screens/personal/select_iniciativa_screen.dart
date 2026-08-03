import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

/// Busca una iniciativa activa por título para relacionarla con una
/// publicación. Devuelve el mapa {id, title} por Navigator.pop.
class SelectIniciativaScreen extends StatefulWidget {
  const SelectIniciativaScreen({super.key});

  @override
  State<SelectIniciativaScreen> createState() =>
      _SelectIniciativaScreenState();
}

class _SelectIniciativaScreenState extends State<SelectIniciativaScreen> {
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      var request = _client
          .from('iniciativas')
          .select('id, title, category')
          .eq('status', 'activa');
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        request = request.ilike('title', '%$trimmed%');
      }
      final rows = await request.order('title').limit(30);
      if (!mounted) return;
      setState(() => _results = (rows as List).cast<Map<String, dynamic>>());
    } finally {
      if (mounted) setState(() => _isSearching = false);
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
        title: const Text('Relacionar con iniciativa'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar iniciativa por nombre...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.primarioBlanco,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron iniciativas activas con ese nombre.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.gris200),
                    itemBuilder: (context, index) {
                      final iniciativa = _results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.favorite,
                          color: AppColors.primarioRojo,
                        ),
                        title: Text(
                          iniciativa['title'] as String? ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                        subtitle: iniciativa['category'] != null
                            ? Text(iniciativa['category'] as String)
                            : null,
                        onTap: () => Navigator.of(context).pop(iniciativa),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
