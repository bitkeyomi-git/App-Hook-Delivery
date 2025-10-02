// lib/Rastreo/track_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../Configuraciones/app_localizations.dart';
import '../Configuraciones/settings_controller.dart';

const String _TRACK_URL = 'https://25fe0fbbec48.ngrok-free.app/get-servicio-info';
const String _API_KEY   = 'yacjDEIxyrZPgAZMh83yUAiP86Y256QNkyhuix5qSgP7LnTQ4S';

class TrackShipmentPage extends StatefulWidget {
  const TrackShipmentPage({super.key});

  @override
  State<TrackShipmentPage> createState() => _TrackShipmentPageState();
}

class _TrackShipmentPageState extends State<TrackShipmentPage> {
  final TextEditingController _guideCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _res; // primer objeto dentro de "result"

  @override
  void dispose() {
    _guideCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ===== Helpers =====
  String L(String es, String en) {
    final lang = context.read<SettingsController>().language;
    return lang == AppLanguage.es ? es : en;
  }

  Color get _mainColor {
    final settings = context.read<SettingsController>();
    final isDark = settings.theme == AppTheme.blueDark;
    return isDark ? const Color(0xFF29B6F6) : const Color(0xFFF20A32);
  }

  bool _isValid(String s) => RegExp(r'^\d+$').hasMatch(s);

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final txt = (data?.text ?? '').replaceAll(RegExp(r'\s+'), '');
    if (txt.isEmpty) return;
    _guideCtrl.text = txt;
    _focus.requestFocus();
  }

  String _fmtDT(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final d = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final h = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d, $h';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _track() async {
    final code = _guideCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (!_isValid(code)) {
      _showSnack(L('Ingresa solo números.', 'Digits only.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _res = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(_TRACK_URL),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': _API_KEY,
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          "id": int.tryParse(code) ?? code,
          "timezone": "America/Mexico_City",
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
      final json = jsonDecode(resp.body);
      if (json is! Map || json['status'] != 'ok') {
        throw Exception('Respuesta inesperada: ${resp.body}');
      }
      final list = (json['result'] as List?) ?? const [];
      if (list.isEmpty) {
        throw Exception(L('Sin resultados para esa guía.', 'No results.'));
      }
      _res = Map<String, dynamic>.from(list.first as Map);
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ===== Widgets pequeños =====
  Widget _chip(String title, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: 6,
              child: Text(
                v,
                style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400),
              ),
            ),
          ],
        ),
      );

  void _showPackagesSheet(List pkgs) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pkgs.length,
          itemBuilder: (_, i) {
            final p = Map<String, dynamic>.from(pkgs[i] as Map);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${p['id_final_package_order'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _kv(L('Descripción', 'Description'), '${p['package_description'] ?? '-'}'),
                    _kv(L('Concepto', 'Concept'), '${p['concept'] ?? '-'}'),
                    _kv(L('Peso', 'Weight'), '${p['weight'] ?? '-'}'),
                    _kv(L('Alto', 'Height'), '${p['height'] ?? '-'}'),
                    _kv(L('Largo', 'Length'), '${p['length'] ?? '-'}'),
                    _kv(L('Ancho', 'Width'), '${p['width'] ?? '-'}'),
                    _kv(L('Precio por paquete', 'Price per package'), '${p['price_per_package'] ?? '-'}'),
                    _kv(L('Total', 'Total'), '${p['total_price'] ?? '-'}', bold: true),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L('Rastrear mi envío', 'Track my shipment'), style: TextStyle(color: _mainColor)),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: _mainColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        children: [
          // Buscador
          TextField(
            controller: _guideCtrl,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(22),
            ],
            decoration: InputDecoration(
              labelText: L('Número / ID de servicio', 'Service ID / Guide'),
              hintText: L('Ingresa tu número', 'Enter your number'),
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.25),
              prefixIcon: Icon(Icons.confirmation_number_outlined, color: _mainColor),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: L('Pegar', 'Paste'), icon: const Icon(Icons.content_paste), onPressed: _paste),
                  IconButton(tooltip: L('Limpiar', 'Clear'), icon: const Icon(Icons.clear), onPressed: () => _guideCtrl.clear()),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _mainColor.withOpacity(0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _mainColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              counterText: '',
            ),
            onSubmitted: (_) => _track(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: _loading ? null : _track,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(L('Rastrear', 'Track')),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          if (_res != null) ...[
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header título + estado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Service', 'Service'),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(
                                '#${_res!['r_id_service_and_delivery_data'] ?? '-'}',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${L('Creado', 'Created on')}: ${_fmtDT(_res!['r_created_at_local'])}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              Text(
                                'Hora Salida: ${_fmtDT(_res!['r_hora_salida'])}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (_res!['r_status'] ?? '-').toString().toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Origen / Destino chips
                    Row(
                      children: [
                        Expanded(child: _chip('${L('Origen', 'Origin')}\n${_res!['r_origin'] ?? '-'}', Icons.person_pin_circle)),
                        const SizedBox(width: 12),
                        Expanded(child: _chip('${L('Destino', 'Destination')}\n${_res!['r_destination'] ?? '-'}', Icons.place_outlined)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Sender / Recipient (dos columnas)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Remitente', 'Sender'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kv(L('Nombre', 'First name'), '${_res!['r_sender_name'] ?? '-'}', bold: true),
                              _kv(L('Apellido', 'Last name'), '${_res!['r_sender_last_name'] ?? '-'}'),
                              _kv('Email', '${_res!['r_sender_email'] ?? '-'}'),
                              _kv(L('Teléfono', 'Phone'), '${_res!['r_sender_phone_number'] ?? '-'}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Destinatario', 'Recipient'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kv(L('Nombre', 'First name'), '${_res!['r_recipient_first_name'] ?? '-'}', bold: true),
                              _kv(L('Apellido', 'Last name'), '${_res!['r_recipient_last_name'] ?? '-'}'),
                              _kv('Email', '${_res!['r_recipient_email'] ?? '-'}'),
                              _kv(L('Teléfono', 'Phone'), '${_res!['r_recipient_phone_number'] ?? '-'}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Package + Concept
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Paquete', 'Package'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kv(L('Descripción', 'Description'), '${_res!['r_package_description'] ?? '-'}'),
                              _kv(L('Dimensiones', 'Dimensions'),
                                  '${_res!['r_length'] ?? '-'} × ${_res!['r_width'] ?? '-'} × ${_res!['r_height'] ?? '-'}'),
                              _kv(L('Peso', 'Weight'), '${_res!['r_weight'] ?? '-'}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Concepto', 'Concept'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kv(L('Tipo', 'Type'), '${_res!['r_concept'] ?? '-'}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Price summary
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L('Precio', 'Price'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              _kv(L('Precio por paquete', 'Unit price'),
                                  '\$${(_res!['r_price_per_package'] ?? '-').toString()}'),
                              const SizedBox(height: 2),
                              Text(L('Total', 'Total price'),
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('\$${(_res!['r_total_price'] ?? '-').toString()}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(color: cs.outlineVariant),
                    const SizedBox(height: 12),

                    // Ver todos los paquetes
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final pkgs = (_res!['r_packages'] as List?) ?? const [];
                          if (pkgs.isEmpty) {
                            _showSnack(L('Sin paquetes para mostrar.', 'No packages.'));
                          } else {
                            _showPackagesSheet(pkgs);
                          }
                        },
                        child: Text(L('Ver todos los paquetes', 'View All Packages'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Derivaciones (resumen breve dentro de la misma card)
                    if ((_res!['r_derivations'] as List?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(L('Derivaciones de pago', 'Payment derivations'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...List<Map<String, dynamic>>.from((_res!['r_derivations'] as List))
                          .map((d) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${d['payment_method'] ?? '-'} • ${d['concepto'] ?? '-'}')),
                                    Text(
                                      '\$${(d['cash_amount'] ?? 0)} / \$${(d['card_amount'] ?? 0)} / \$${(d['transfer_amount'] ?? 0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
