import 'package:flutter/material.dart';

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  // ====== ESTADO MVP ======
  bool _loading = false;

  /// Simulación MVP:
  /// luego esto vendrá del backend (GET servicio activo)
  Map<String, dynamic>? _activeService;

  /// Lista simulada de solicitudes disponibles
  /// luego vendrá de GET /api/services/requests/available/
  final List<Map<String, dynamic>> _availableRequests = [
    {
      "id": 101,
      "category": "Acompañamiento",
      "location_text": "Parque de la 93",
      "duration": 60,
      "price": 30000,
    },
    {
      "id": 102,
      "category": "Compañía social",
      "location_text": "Centro Comercial Gran Estación",
      "duration": 90,
      "price": 45000,
    },
  ];

  // =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: _activeService != null
            ? _buildActiveService()
            : _buildAvailableRequests(),
      ),
    );
  }

  // =======================
  // UI BLOQUES
  // =======================

  Widget _buildActiveService() {
    final s = _activeService!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicio activo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Ubicación', s['location_text']),
                _kv('Duración', '${s['duration']} min'),
                _kv('Valor', '${_formatCop(s['price'])} COP'),
                _kv('Estado', s['status'] ?? 'En curso'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Ver servicio'),
            onPressed: () {
              // 👉 en el siguiente paso navega a ActiveServicePage
              _showSnack('Ir a servicio activo (pendiente)');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Solicitudes disponibles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (_availableRequests.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No hay solicitudes disponibles en este momento'),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _availableRequests.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final r = _availableRequests[index];
                return Card(
                  child: ListTile(
                    title: Text(r['location_text']),
                    subtitle: Text(
                      '${r['category']} • ${r['duration']} min',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_formatCop(r['price'])} COP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      // 👉 siguiente paso: ir a detalle de solicitud
                      _showSnack('Ver solicitud ${r['id']} (pendiente)');
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // =======================
  // HELPERS
  // =======================

  Widget _kv(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$k:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(v ?? '—')),
        ],
      ),
    );
  }

  String _formatCop(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  void _reload() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _loading = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

