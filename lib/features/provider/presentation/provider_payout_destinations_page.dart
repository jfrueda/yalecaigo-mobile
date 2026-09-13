import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/provider_payout_destination_service.dart';

class ProviderPayoutDestinationSummaryCard extends StatefulWidget {
  const ProviderPayoutDestinationSummaryCard({super.key});

  @override
  State<ProviderPayoutDestinationSummaryCard> createState() =>
      _ProviderPayoutDestinationSummaryCardState();
}

class _ProviderPayoutDestinationSummaryCardState
    extends State<ProviderPayoutDestinationSummaryCard> {
  final ProviderPayoutDestinationService _service =
      ProviderPayoutDestinationService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.listDestinations();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _service.listDestinations());
  }

  Future<void> _openManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderPayoutDestinationsPage(),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final destinations = snapshot.data ?? const <Map<String, dynamic>>[];
        final active = destinations
            .where((item) => item['is_active'] != false)
            .toList();
        Map<String, dynamic>? primary;
        for (final item in active) {
          if (item['is_primary'] == true) {
            primary = item;
            break;
          }
        }

        final hasPrimary = primary != null;
        final pendingConnector =
            primary?['external_channel']?.toString() == 'pending_connector';
        final subtitle = snapshot.connectionState == ConnectionState.waiting
            ? 'Consultando destino de pago...'
            : hasPrimary
            ? pendingConnector
                  ? '${primary['masked_destination'] ?? 'Destino registrado'} · transferencias próximamente'
                  : '${primary['masked_destination'] ?? 'Destino registrado'} · registrado para pagos'
            : 'Agrega una cuenta bancaria o DaviPlata para recibir tus pagos.';

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openManager,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      hasPrimary
                          ? Icons.account_balance_wallet_rounded
                          : Icons.add_card_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dónde recibir mis pagos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProviderPayoutDestinationsPage extends StatefulWidget {
  const ProviderPayoutDestinationsPage({super.key});

  @override
  State<ProviderPayoutDestinationsPage> createState() =>
      _ProviderPayoutDestinationsPageState();
}

class _ProviderPayoutDestinationsPageState
    extends State<ProviderPayoutDestinationsPage> {
  final ProviderPayoutDestinationService _service =
      ProviderPayoutDestinationService();
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listDestinations();
  }

  Future<void> _reload({Map<String, dynamic>? ensureVisible}) async {
    final next = _service.listDestinations();
    if (mounted) setState(() => _future = next);

    final fresh = await next;
    if (!mounted || ensureVisible == null) return;

    final createdId = ensureVisible['id']?.toString();
    final alreadyVisible = fresh.any(
      (item) => item['id']?.toString() == createdId,
    );
    if (alreadyVisible) return;

    final merged = <Map<String, dynamic>>[
      ensureVisible,
      ...fresh.where((item) => item['id']?.toString() != createdId),
    ];
    setState(() => _future = Future.value(merged));
  }

  Future<void> _addDestination() async {
    List<Map<String, dynamic>> previous = const [];
    try {
      previous = await _future;
    } catch (_) {
      // La creación puede continuar aunque la lista previa haya fallado.
    }

    if (!mounted) return;
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const _PayoutDestinationFormPage(),
      ),
    );
    if (created == null || !mounted) return;

    final createdId = created['id']?.toString();
    final optimistic = <Map<String, dynamic>>[
      created,
      ...previous.where((item) => item['id']?.toString() != createdId),
    ];
    setState(() => _future = Future.value(optimistic));

    try {
      await _reload(ensureVisible: created);
    } catch (_) {
      // Conserva el destino recién creado en pantalla. El usuario puede
      // volver a sincronizar con Actualizar o pull-to-refresh.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Destino de pago registrado.')),
    );
  }

  Future<void> _setPrimary(Map<String, dynamic> destination) async {
    final id = int.tryParse(destination['id']?.toString() ?? '');
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.setPrimary(id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destino principal actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate(Map<String, dynamic> destination) async {
    final id = int.tryParse(destination['id']?.toString() ?? '');
    if (id == null || _busy) return;
    final isPrimary = destination['is_primary'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desactivar destino'),
        content: Text(
          isPrimary
              ? 'Este es tu destino principal. Si lo desactivas, los pagos quedarán pendientes hasta que registres o selecciones otro destino habilitado.'
              : 'Este destino dejará de estar disponible para futuros pagos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _service.deactivate(id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Destino desactivado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dónde recibir mis pagos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.cloud_off_outlined, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'No pudimos cargar tus destinos de pago.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }

            final destinations =
                (snapshot.data ?? const <Map<String, dynamic>>[])
                    .where((item) => item['is_active'] != false)
                    .toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Recibe tus ganancias',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra un destino a tu nombre. GoWith libera el pago después de la ventana de seguridad definida para cada actividad.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No necesitas esperar una aprobación manual. Debes confirmar que la cuenta o billetera está a tu nombre y bajo tu control.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (destinations.isEmpty)
                  _EmptyDestinationCard(onAdd: _addDestination)
                else ...[
                  ...destinations.map(
                    (destination) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DestinationCard(
                        destination: destination,
                        busy: _busy,
                        onSetPrimary: () => _setPrimary(destination),
                        onDeactivate: () => _deactivate(destination),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addDestination,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar otro destino'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final hasActive = (snapshot.data ?? const <Map<String, dynamic>>[])
              .any((item) => item['is_active'] != false);
          if (!hasActive) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _busy ? null : _addDestination,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Agregar'),
          );
        },
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.busy,
    required this.onSetPrimary,
    required this.onDeactivate,
  });

  final Map<String, dynamic> destination;
  final bool busy;
  final VoidCallback onSetPrimary;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final type = destination['destination_type']?.toString() ?? '';
    final isPrimary = destination['is_primary'] == true;
    final isVerified = destination['is_verified'] == true;
    final pendingConnector =
        destination['external_channel']?.toString() == 'pending_connector';
    final masked = destination['masked_destination']?.toString().trim();
    final title = masked == null || masked.isEmpty
        ? _destinationTypeLabel(type)
        : masked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(_destinationIcon(type))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(_destinationTypeLabel(type)),
                    ],
                  ),
                ),
                if (isPrimary)
                  const Chip(
                    avatar: Icon(Icons.star_rounded, size: 18),
                    label: Text('Principal'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  pendingConnector
                      ? Icons.schedule_outlined
                      : isVerified
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pendingConnector
                        ? 'Registrado. Transferencias a Nequi aún no están habilitadas.'
                        : isVerified
                        ? 'Registrado para recibir pagos.'
                        : 'Destino registrado, pero todavía no está habilitado para pagos.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isPrimary && isVerified)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onSetPrimary,
                    icon: const Icon(Icons.star_outline_rounded),
                    label: const Text('Usar para pagos'),
                  ),
                TextButton.icon(
                  onPressed: busy ? null : onDeactivate,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: const Text('Desactivar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDestinationCard extends StatelessWidget {
  const _EmptyDestinationCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: 14),
            Text(
              'Aún no tienes un destino de pago',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Puedes registrar una cuenta bancaria, DaviPlata o Nequi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Registrar destino'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutDestinationFormPage extends StatefulWidget {
  const _PayoutDestinationFormPage();

  @override
  State<_PayoutDestinationFormPage> createState() =>
      _PayoutDestinationFormPageState();
}

class _PayoutDestinationFormPageState
    extends State<_PayoutDestinationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProviderPayoutDestinationService();
  final _holderController = TextEditingController();
  final _documentTypeController = TextEditingController(text: 'CC');
  final _documentNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String _type = 'bank_account';
  String _accountType = 'Ahorros';
  bool _ownershipConfirmed = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _holderController.dispose();
    _documentTypeController.dispose();
    _documentNumberController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Este dato es obligatorio.';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_ownershipConfirmed) {
      setState(
        () => _error =
            'Confirma que el destino está a tu nombre y bajo tu control.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'destination_type': _type,
      'account_holder_name': _holderController.text.trim(),
      'document_type': _documentTypeController.text.trim().toUpperCase(),
      'document_number': _documentNumberController.text.trim(),
      'ownership_confirmed': true,
      // Nequi se registra para dejarlo listo, pero no desplaza un destino
      // que ya pueda recibir pagos mientras el conector no esté habilitado.
      'is_primary': _type != 'nequi',
      'is_active': true,
    };

    if (_type == 'bank_account') {
      data.addAll({
        'bank_name': _bankNameController.text.trim(),
        'account_type': _accountType,
        'account_number': _accountNumberController.text.trim(),
      });
    } else {
      data['phone_number'] = _phoneController.text.trim();
    }

    try {
      final created = await _service.createDestination(data);
      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>(created);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBank = _type == 'bank_account';
    final isNequi = _type == 'nequi';

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar destino de pago')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo de destino',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'bank_account',
                  child: Text('Cuenta bancaria'),
                ),
                DropdownMenuItem(value: 'daviplata', child: Text('DaviPlata')),
                DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _type = value);
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del titular',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 105,
                  child: TextFormField(
                    controller: _documentTypeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      hintText: 'CC',
                      border: OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _documentNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Documento',
                      border: OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isBank) ...[
              TextFormField(
                controller: _bankNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ej. Bancolombia',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _accountType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de cuenta',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Ahorros', child: Text('Ahorros')),
                  DropdownMenuItem(
                    value: 'Corriente',
                    child: Text('Corriente'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _accountType = value);
                        }
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de cuenta',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
            ] else ...[
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de ${isNequi ? 'Nequi' : 'DaviPlata'}',
                  hintText: '3001234567',
                  border: const OutlineInputBorder(),
                ),
                validator: _required,
              ),
            ],
            if (isNequi) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Puedes registrar Nequi desde ahora. La transferencia a este canal se habilitará cuando GoWith confirme el conector de dispersión.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _ownershipConfirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Confirmo que esta cuenta o billetera está a mi nombre y bajo mi control.',
              ),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _ownershipConfirmed = value == true);
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Registrando...' : 'Registrar destino'),
            ),
          ],
        ),
      ),
    );
  }
}

String _destinationTypeLabel(String type) {
  switch (type) {
    case 'bank_account':
      return 'Cuenta bancaria';
    case 'daviplata':
      return 'DaviPlata';
    case 'nequi':
      return 'Nequi';
    default:
      return 'Destino de pago';
  }
}

IconData _destinationIcon(String type) {
  switch (type) {
    case 'bank_account':
      return Icons.account_balance_outlined;
    case 'daviplata':
      return Icons.phone_android_rounded;
    case 'nequi':
      return Icons.smartphone_rounded;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

String _apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final detail = map['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      for (final value in map.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
  }
  return 'No pudimos completar la operación. Revisa los datos e intenta nuevamente.';
}
