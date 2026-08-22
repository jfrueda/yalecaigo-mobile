import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/service_display.dart';
import '../../service_request/data/trust_service.dart';

class ProviderReputationPage extends StatefulWidget {
  const ProviderReputationPage({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  final int providerId;
  final String providerName;

  @override
  State<ProviderReputationPage> createState() => _ProviderReputationPageState();
}

class _ProviderReputationPageState extends State<ProviderReputationPage> {
  final TrustService _service = TrustService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.providerReputation(widget.providerId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.providerReputation(widget.providerId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reputación del acompañante')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is DioException
                  ? 'No fue posible consultar la reputación.'
                  : snapshot.error.toString();
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.cloud_off_outlined, size: 52),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }

            final data = snapshot.data ?? const <String, dynamic>{};
            final reviews = data['public_reviews'] is List
                ? (data['public_reviews'] as List)
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList()
                : const <Map<String, dynamic>>[];
            final average = data['average_rating']?.toString() ?? '0.00';
            final ratingCount = data['rating_count']?.toString() ?? '0';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  widget.providerName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        const Icon(Icons.star_rounded, size: 44),
                        Text(
                          '$average / 5',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text('$ratingCount calificaciones'),
                        const Divider(height: 28),
                        _metric(
                          'Actividades finalizadas',
                          data['completed_services'],
                        ),
                        _metric(
                          'Cancelaciones atribuibles',
                          data['cancelled_services'],
                        ),
                        _metric('No presentado', data['no_show_count']),
                        _metric(
                          'Cumplimiento',
                          '${data['completion_rate'] ?? '0.00'} %',
                        ),
                        _metric(
                          'Tasa de cancelación',
                          '${data['cancellation_rate'] ?? '0.00'} %',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Comentarios públicos aprobados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (reviews.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Aún no hay comentarios públicos aprobados.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...reviews.map(
                    (review) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${review['score'] ?? '—'}'),
                        ),
                        title: Text(
                          review['author_display_name']?.toString() ??
                              'Usuario',
                        ),
                        subtitle: Text(
                          '${review['public_comment'] ?? ''}\n${formatDateTime(review['created_at'])}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metric(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value?.toString() ?? '0',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
