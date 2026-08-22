import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_brand.dart';
import '../data/auth_service.dart';
import 'auth_error.dart';
import 'onboarding_status_page.dart';

class LegalDocumentsPage extends StatefulWidget {
  const LegalDocumentsPage({super.key});

  @override
  State<LegalDocumentsPage> createState() => _LegalDocumentsPageState();
}

class _LegalDocumentsPageState extends State<LegalDocumentsPage> {
  final AuthService _auth = AuthService();
  final Set<int> _accepted = <int>{};

  List<Map<String, dynamic>> _documents = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _documentId(Map<String, dynamic> document) {
    final raw = document['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents = await _auth.getLegalDocuments();
      if (!mounted) return;
      setState(() {
        _documents = documents.where((document) {
          return _documentId(document) != null;
        }).toList();
        _loading = false;
        if (_documents.isEmpty) {
          _error =
              'Los documentos legales no están disponibles en este momento. Intenta nuevamente.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = readableAuthError(error);
        _loading = false;
      });
    }
  }

  void _acceptRequired() {
    setState(() {
      for (final document in _documents) {
        if (document['acceptance_required'] == true) {
          final id = _documentId(document);
          if (id != null) _accepted.add(id);
        }
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_documents.isEmpty) {
      setState(() {
        _error = 'Los documentos legales no están disponibles en este momento.';
      });
      return;
    }

    final requiredIds = _documents
        .where((document) => document['acceptance_required'] == true)
        .map(_documentId)
        .whereType<int>()
        .toSet();

    if (requiredIds.isEmpty) {
      setState(() {
        _error =
            'No pudimos cargar los documentos necesarios. Intenta nuevamente.';
      });
      return;
    }

    if (!_accepted.containsAll(requiredIds)) {
      setState(() {
        _error = 'Debes aceptar todos los documentos obligatorios.';
      });
      return;
    }

    final selectedIds = _accepted
        .where(
          (id) => _documents.any((document) => _documentId(document) == id),
        )
        .toList();
    if (selectedIds.isEmpty) {
      setState(() {
        _error = 'Selecciona al menos un documento antes de continuar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.acceptLegalDocuments(selectedIds);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OnboardingStatusPage()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = readableAuthError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos legales')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _documents.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              children: [
                                const AppBrandHeader(
                                  compact: true,
                                  showName: false,
                                ),
                                const SizedBox(height: 20),
                                const Icon(
                                  Icons.description_outlined,
                                  size: 58,
                                  color: AppColors.amber,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Documentos no disponibles',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.tealDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _error ??
                                      'No hay documentos legales vigentes para mostrar.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                OutlinedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Volver a consultar'),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                24,
                              ),
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Lee cada documento y acepta los obligatorios para continuar.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _acceptRequired,
                                      child: const Text('Aceptar obligatorios'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._documents.map((document) {
                                  final id = _documentId(document)!;
                                  final required =
                                      document['acceptance_required'] == true;
                                  final name =
                                      document['name']?.toString() ??
                                      'Documento legal';
                                  final version =
                                      document['version']?.toString() ?? '-';
                                  final content =
                                      document['content']?.toString().trim() ??
                                      '';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      child: ExpansionTile(
                                        leading: CircleAvatar(
                                          backgroundColor: required
                                              ? AppColors.coral.withValues(
                                                  alpha: 0.12,
                                                )
                                              : AppColors.amber.withValues(
                                                  alpha: 0.18,
                                                ),
                                          foregroundColor: required
                                              ? AppColors.coral
                                              : AppColors.tealDark,
                                          child: Icon(
                                            required
                                                ? Icons.gavel_outlined
                                                : Icons.description_outlined,
                                          ),
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Versión $version · '
                                          '${required ? 'Obligatorio' : 'Opcional'}',
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              4,
                                              16,
                                              10,
                                            ),
                                            child: SelectableText(
                                              content.isEmpty
                                                  ? 'Este documento no está disponible para lectura en este momento.'
                                                  : content,
                                            ),
                                          ),
                                          CheckboxListTile(
                                            value: _accepted.contains(id),
                                            activeColor: AppColors.teal,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  _accepted.add(id);
                                                } else {
                                                  _accepted.remove(id);
                                                }
                                                _error = null;
                                              });
                                            },
                                            title: Text(
                                              required
                                                  ? 'He leído y acepto este documento obligatorio'
                                                  : 'He leído y acepto este documento',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),
                  if (_error != null && _documents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _documents.isEmpty || _loading
                            ? null
                            : _submit,
                        child: const Text('Aceptar y continuar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
