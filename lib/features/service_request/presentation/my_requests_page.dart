import 'package:flutter/material.dart';
import '../data/service_request_query_service.dart';
import 'request_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _service = ServiceRequestQueryService();

  late Future<List<Map<String, dynamic>>> _future;
  final _searchCtrl = TextEditingController();

  static const _activeStatuses = ['pending', 'searching', 'matched', 'started'];

  // Histórico: mostrar primero solo los últimos 20
  static const int _initialHistoryLimit = 20;
  int _historyLimit = _initialHistoryLimit;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await _service.listMyRequests();
    // Normalizamos a Map<String, dynamic>
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Ya vienen ordenadas por -created_at desde backend, pero por seguridad:
    list.sort((a, b) {
      final ca = (a['created_at'] ?? '').toString();
      final cb = (b['created_at'] ?? '').toString();
      return cb.compareTo(ca);
    });

    return list;
  }

  Future<void> _refresh() async {
    setState(() {
      _historyLimit = _initialHistoryLimit;
      _future = _load();
    });
  }

  String _s(dynamic v, {String fallback = '-'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _matchesSearch(Map<String, dynamic> r, String q) {
    if (q.isEmpty) return true;

    final id = _toInt(r['id']).toString();
    final status = _s(r['status'], fallback: 'unknown').toLowerCase();
    final loc = _s(r['location_text']).toLowerCase();
    final created = _s(r['created_at']).toLowerCase();

    return id.contains(q) ||
        status.contains(q) ||
        loc.contains(q) ||
        created.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('❌ Error: ${snap.error}'));
          }

          final all = snap.data ?? [];
          if (all.isEmpty) {
            return const Center(child: Text('No tienes solicitudes'));
          }

          // Aplicar filtro de búsqueda
          final filtered = all.where((r) => _matchesSearch(r, query)).toList();

          // Separar activa vs histórico
          final active = <Map<String, dynamic>>[];
          final history = <Map<String, dynamic>>[];

          for (final r in filtered) {
            final status = _s(r['status'], fallback: 'unknown').toLowerCase();
            if (_activeStatuses.contains(status)) {
              active.add(r);
            } else {
              history.add(r);
            }
          }

          // Aplicar límite a histórico (solo si NO hay búsqueda; si hay búsqueda mostramos todo)
          final showAllHistory = query.isNotEmpty;
          final limitedHistory = showAllHistory
              ? history
              : history.take(_historyLimit).toList();

          final canShowMore =
              !showAllHistory && history.length > limitedHistory.length;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar (id, estado, ubicación...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Activa
              if (active.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Activa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ...active.map((r) => _tile(context, r)),
                const Divider(height: 24),
              ],

              // Histórico
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Histórico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('No hay solicitudes históricas'),
                )
              else ...[
                ...limitedHistory.map((r) => _tile(context, r)),

                if (canShowMore) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _historyLimit += 20;
                        });
                      },
                      child: Text(
                        'Ver más (${history.length - limitedHistory.length} restantes)',
                      ),
                    ),
                  ),
                ],

                if (!canShowMore &&
                    query.isEmpty &&
                    history.length > _initialHistoryLimit) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _historyLimit = _initialHistoryLimit;
                        });
                      },
                      child: const Text('Ver menos'),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> r) {
    final id = _toInt(r['id']);
    final status = _s(r['status'], fallback: 'unknown');
    final loc = _s(r['location_text']);
    final created = _s(r['created_at']);
    final ended = _s(r['ended_at']);
    final price = _s(r['calculated_price'], fallback: '0');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('Solicitud #$id — ${status.toUpperCase()}'),
        subtitle: Text('$loc\nCreada: $created\nFinal: $ended\nValor: $price'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RequestDetailPage(request: r)),
          );
        },
      ),
    );
  }
}
