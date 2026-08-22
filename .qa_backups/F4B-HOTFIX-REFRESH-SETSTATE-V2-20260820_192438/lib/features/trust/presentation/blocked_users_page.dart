import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../service_request/data/trust_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final TrustService _service = TrustService();
  late Future<List<Map<String, dynamic>>> _future;
  int? _busyUserId;

  @override
  void initState() {
    super.initState();
    _future = _service.listBlockedUsers();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.listBlockedUsers());
    await _future;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _unblock(Map<String, dynamic> block) async {
    final userId = _int(block['blocked']);
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desbloquear usuario'),
        content: Text(
          '¿Deseas permitir nuevamente futuros emparejamientos con ${block['blocked_username'] ?? 'este usuario'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUserId = userId);
    try {
      await _service.unblockUser(userId);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario desbloqueado.')));
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : 'No fue posible desbloquear al usuario.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.cloud_off_outlined, size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    'No fue posible consultar tus bloqueos.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.people_outline, size: 52),
                  SizedBox(height: 12),
                  Text(
                    'No tienes usuarios bloqueados.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final block = items[index];
                final userId = _int(block['blocked']);
                final busy = userId != null && userId == _busyUserId;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(
                      block['blocked_username']?.toString() ?? 'Usuario',
                    ),
                    subtitle: (block['reason']?.toString().trim() ?? '').isEmpty
                        ? const Text('Bloqueo activo')
                        : Text('Motivo: ${block['reason']}'),
                    trailing: TextButton(
                      onPressed: busy ? null : () => _unblock(block),
                      child: Text(busy ? 'Procesando…' : 'Desbloquear'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
