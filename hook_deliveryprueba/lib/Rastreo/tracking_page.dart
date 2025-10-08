// lib/Rastreo/tracking_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../Configuraciones/app_localizations.dart';
import '../Configuraciones/settings_controller.dart';
import '../Inicio/home_page.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum AppMsgType { success, error, info, warning }

void showMsg(
  BuildContext context, {
  required String text,
  AppMsgType type = AppMsgType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final cs = Theme.of(context).colorScheme;
  Color bg, fg;
  IconData icon;
  switch (type) {
    case AppMsgType.success:
      bg = cs.tertiaryContainer;
      fg = cs.onTertiaryContainer;
      icon = Icons.check_circle_rounded;
      break;
    case AppMsgType.error:
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      icon = Icons.error_rounded;
      break;
    case AppMsgType.warning:
      bg = cs.secondaryContainer;
      fg = cs.onSecondaryContainer;
      icon = Icons.warning_amber_rounded;
      break;
    case AppMsgType.info:
    default:
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
      icon = Icons.info_rounded;
  }

  final snack = SnackBar(
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    backgroundColor: Colors.transparent,
    duration: duration,
    content: Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.15),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Icon(Icons.close_rounded, size: 20, color: fg),
          ),
        ],
      ),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(snack);
}

/// ================== OVERLAY DEL ESCÁNER (TOP-LEVEL) ==================

class _ScanOverlay extends StatelessWidget {
  final ColorScheme colorScheme;
  final String label;
  const _ScanOverlay({required this.colorScheme, required this.label});

  @override
  Widget build(BuildContext context) {
    // Tamaño del recuadro adaptado por dispositivo (ancho de pantalla)
    final w = MediaQuery.sizeOf(context).width;
    final double boxW = w < 360 ? w * 0.78 : (w <= 400 ? w * 0.74 : w * 0.70);
    final Size box = Size(boxW, boxW * 0.60); // rectángulo horizontal

    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2.2;
        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: box.width,
          height: box.height,
        );

        return Stack(
          children: [
            // Sombreado con agujero
            Positioned.fill(
              child: CustomPaint(
                painter: _HolePainter(
                  rect: rect,
                  overlayColor: Colors.black.withOpacity(0.45),
                ),
              ),
            ),
            // Marco
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.primary, width: 3),
                  ),
                ),
              ),
            ),
            // Texto guía
            Positioned(
              top: rect.bottom + 12,
              left: 0,
              right: 0,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect rect;
  final Color overlayColor;
  _HolePainter({required this.rect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    final path = Path.combine(PathOperation.difference, bg, hole);
    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ================== PÁGINA ==================

const String _TRACK_URL =
    'https://api-ticket-6wly.onrender.com/get-servicio-info';
const String _UPDATE_URL =
    'https://api-ticket-6wly.onrender.com/update-service-status';
const String _API_KEY = 'yacjDEIxyrZPgAZMh83yUAiP86Y256QNkyhuix5qSgP7LnTQ4S';

class TrackShipmentPage extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  const TrackShipmentPage({super.key, required this.userInfo});

  @override
  State<TrackShipmentPage> createState() => _TrackShipmentPageState();
}

class _TrackShipmentPageState extends State<TrackShipmentPage> {
  Map<String, dynamic>? get personal {
    final list = widget.userInfo['personalInfo'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      return Map<String, dynamic>.from(list.first as Map);
    }
    return null;
  }

  final TextEditingController _guideCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _res;

  String? _selectedOfficeAction = 'Recibió';
  String? _selectedStatus;
  bool _savingStatus = false;

  final List<String> _statusOptions = const [
    'pendiente',
    'en tránsito',
    'entregado',
    'cancelado',
  ];

  String _normalizeStatus(String s) => s.trim().toLowerCase();

  String? _statusFromOfficeAction(String? action) {
    switch ((action ?? '').toLowerCase()) {
      case 'recibió':
      case 'recibio':
        return 'recibio';
      case 'envió':
      case 'envio':
        return 'envio';
      case 'devolvió':
      case 'devolvio':
        return 'devolvio';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _guideCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

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
      final d =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final h =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d, $h';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _track() async {
    final code = _guideCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (!_isValid(code)) {
      _showSnack(
        L('Ingresa solo números.', 'Digits only.'),
        type: AppMsgType.warning,
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _res = null;
      _selectedStatus = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(_TRACK_URL),
        headers: {
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
        if (mounted) {
          _res = null;
          _selectedStatus = null;
          _error = null;
          _focus.requestFocus();
          // feedback opcional:
          // HapticFeedback.lightImpact();

          _showSnack(
            L(
              'No encontramos esa guía. Verifica el número.',
              'We couldn’t find that ID. Please check the number.',
            ),
            type: AppMsgType.warning,
          );
        }
        return; // Salimos sin romper el flujo
      }

      _res = Map<String, dynamic>.from(list.first as Map);
      _selectedStatus = (_res!['r_status'] as String?)?.toLowerCase();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveStatus() async {
    if (_res == null) {
      _showSnack('No hay servicio cargado.');
      return;
    }
    final idRaw = _res!['r_id_service_and_delivery_data'];
    final id = (idRaw is int) ? idRaw : int.tryParse('${idRaw ?? ''}');
    if (id == null) {
      _showSnack('ID de servicio no disponible.');
      return;
    }

    final officeActionStatus = _statusFromOfficeAction(_selectedOfficeAction);
    final chosen =
        officeActionStatus ??
        (_selectedStatus ??
            (_res!['r_status']?.toString().toLowerCase() ?? 'pendiente'));

    final statusForApi = _normalizeStatus(chosen);

    final officeId =
        personal?['id_office'] ??
        personal?['r_id_office'] ??
        personal?['idOffice'];

    setState(() => _savingStatus = true);
    try {
      final body = <String, dynamic>{
        "id": id,
        "status": '${statusForApi} - ${personal?['r_name_office'] ?? '-'}',
        "timezone": "America/Mexico_City",
        if (officeActionStatus != null) "id_office": officeId,
      };
      final resp = await http.post(
        Uri.parse(_UPDATE_URL),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': _API_KEY,
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      setState(() {
        if (officeActionStatus == null) {
          _selectedStatus = statusForApi;
          _res!['r_status'] = statusForApi;
        }
      });

      _showSnack(
        officeActionStatus != null
            ? 'Acción registrada: $_selectedOfficeAction (${personal?['r_name_office'] ?? personal?['name_office'] ?? '-'})'
            : 'Estatus actualizado a: $statusForApi',
      );
    } catch (e) {
      _showSnack(
        'Estatus actualizado a: $statusForApi',
        type: AppMsgType.success,
      );
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }

    Future<void> _postEmail(String email) async {
      if (email.isEmpty) return;
      final body = {
        "to": email,
        "user_name": personal?['r_name_office'] ?? 'Hook Delivery',
        "service_delivery_id":
            "${_res?['r_id_service_and_delivery_data'] ?? '-'}",
        "timezone": "America/Mexico_City",
        "new_status":
            _selectedStatus ?? (_res?['r_status']?.toString() ?? 'actualizado'),
        "timeUpdate": DateTime.now().toString().substring(0, 16),
      };

      final resp = await http.post(
        Uri.parse(
          'https://api-ticket-6wly.onrender.com/send-alert-package-plm',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': _API_KEY,
          if (kIsWeb) 'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    }

    try {
      final emails = <String>[
        (_res?['to'] ?? '').toString(),
        (_res?['r_sender_email'] ?? '').toString(),
        (_res?['r_recipient_email'] ?? '').toString(),
      ].map((e) => e.trim()).where((e) => e.contains('@')).toSet().toList();

      for (final email in emails) {
        await _postEmail(email);
      }

      _showSnack('Correo enviado a: ${emails.join(', ')}');
    } catch (e) {
      _showSnack('Error al enviar el correo: $e', type: AppMsgType.error);
    }
  }

  void _showSnack(String msg, {AppMsgType type = AppMsgType.info}) =>
      showMsg(context, text: msg, type: type);

  // ====== SCAN: QR/Código de barras para r_id_service_and_delivery_data ======
  void _handleScannedValue(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map && v['r_id_service_and_delivery_data'] != null) {
        _guideCtrl.text = '${v['r_id_service_and_delivery_data']}';
        _track();
        return;
      }
    } catch (_) {}

    final m = RegExp(r'\d{4,}').firstMatch(raw);
    if (m != null) {
      _guideCtrl.text = m.group(0)!;
      _track();
      return;
    }

    if (RegExp(r'^\d+$').hasMatch(raw)) {
      _guideCtrl.text = raw;
      _track();
      return;
    }

    _showSnack('Código inválido. No se encontró un ID numérico.');
  }

  Future<void> _openScanner() async {
    bool handled = false;
    final cs = Theme.of(context).colorScheme;

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code93,
        BarcodeFormat.itf,
        BarcodeFormat.codabar,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
      ],
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            elevation: 0,
            title: Text(L('Escanear código', 'Scan code')),
            actions: [
              IconButton(
                tooltip: L('Cerrar', 'Close'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Cámara
              Positioned.fill(
                child: MobileScanner(
                  controller: controller,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error) {
                    final msg =
                        error.errorCode ==
                            MobileScannerErrorCode.permissionDenied
                        ? L(
                            'Permiso de cámara denegado',
                            'Camera permission denied',
                          )
                        : '${L('Error de cámara', 'Camera error')}: ${error.errorCode.name}';
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(msg, style: TextStyle(color: cs.onSurface)),
                      ),
                    );
                  },
                  onDetect: (capture) {
                    if (handled) return;
                    final raw = capture.barcodes.isNotEmpty
                        ? (capture.barcodes.first.rawValue ?? '')
                        : '';
                    if (raw.isEmpty) return;
                    handled = true;
                    Navigator.of(context).pop();
                    _handleScannedValue(raw);
                  },
                ),
              ),

              // Overlay
              Positioned.fill(
                child: _ScanOverlay(
                  colorScheme: cs,
                  label: L(
                    'Alinea el código dentro del recuadro',
                    'Align the code in the frame',
                  ),
                ),
              ),

              // Controles inferiores
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Linterna (escucha el estado desde el ValueListenable del controller)
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: controller,
                        builder: (context, state, __) {
                          final torch = state.torchState;
                          final on = torch == TorchState.on;
                          final available = torch != TorchState.unavailable;
                          return FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.inverseSurface.withOpacity(
                                0.25,
                              ),
                            ),
                            onPressed: available
                                ? controller.toggleTorch
                                : null,
                            icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                            label: Text(
                              on ? L('Linterna', 'Torch') : L('Apagada', 'Off'),
                            ),
                          );
                        },
                      ),
                      // Cambiar cámara
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.inverseSurface.withOpacity(0.25),
                        ),
                        onPressed: controller.switchCamera,
                        icon: const Icon(Icons.cameraswitch),
                        label: Text(L('Cámara', 'Camera')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      controller.dispose();
    });
  }

  // ====== RESPONSIVE UTILS ======
  double rs(BuildContext context, double base) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= 340) return base * 0.85; // teléfonos muy pequeños
    if (w <= 380) return base * 0.92; // compactos
    if (w <= 420) return base * 0.98; // medianos
    return base; // resto
  }

  double fs(BuildContext context, double base) {
    final t = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.15);
    final w = MediaQuery.sizeOf(context).width;
    final shrink = w <= 360 ? 0.94 : (w <= 400 ? 0.97 : 1.0);
    return base * t * shrink;
  }

  Widget _chip(String title, IconData icon) => Builder(
    builder: (context) => Container(
      padding: EdgeInsets.all(rs(context, 14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rs(context, 14)),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: rs(context, 18)),
          SizedBox(width: rs(context, 8)),
          // <- aquí permitimos que el texto se ajuste
          Flexible(
            child: Text(
              title,
              maxLines: 2, // permite 1 o 2 líneas
              overflow: TextOverflow.ellipsis, // corta con "..."
              softWrap: true, // puede hacer salto de línea
              textAlign: TextAlign.start,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: fs(context, 9),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _kv(String k, String v, {bool bold = false}) => Builder(
    builder: (context) => Padding(
      padding: EdgeInsets.symmetric(vertical: rs(context, 2)),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              k,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: fs(context, 13),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              v,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                fontSize: fs(context, 13),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _showPackagesSheet(List pkgs) {
    final h = MediaQuery.of(context).size.height;
    final factor = h < 680 ? 0.88 : 0.75;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: factor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pkgs.length,
          itemBuilder: (_, i) {
            final p = Map<String, dynamic>.from(pkgs[i] as Map);
            return Builder(
              builder: (context) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(rs(context, 14)),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(rs(context, 14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${p['id_final_package_order'] ?? '-'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: fs(context, 15),
                        ),
                      ),
                      SizedBox(height: rs(context, 8)),
                      _kv(
                        L('Descripción', 'Description'),
                        '${p['package_description'] ?? '-'}',
                      ),
                      _kv(L('Concepto', 'Concept'), '${p['concept'] ?? '-'}'),
                      _kv(L('Peso', 'Weight'), '${p['weight'] ?? '-'}'),
                      _kv(L('Alto', 'Height'), '${p['height'] ?? '-'}'),
                      _kv(L('Largo', 'Length'), '${p['length'] ?? '-'}'),
                      _kv(L('Ancho', 'Width'), '${p['width'] ?? '-'}'),
                      _kv(
                        L('Precio por paquete', 'Price per package'),
                        '${p['price_per_package'] ?? '-'}',
                      ),
                      _kv(
                        L('Total', 'Total'),
                        '${p['total_price'] ?? '-'}',
                        bold: true,
                      ),
                    ],
                  ),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          rs(context, 16),
          rs(context, 10),
          rs(context, 16),
          rs(context, 16),
        ),
        children: [
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
              prefixIcon: Icon(
                Icons.confirmation_number_outlined,
                color: _mainColor,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: L('Escanear', 'Scan'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: _openScanner,
                  ),
                  IconButton(
                    tooltip: L('Pegar', 'Paste'),
                    icon: const Icon(Icons.content_paste),
                    onPressed: _paste,
                  ),
                  IconButton(
                    tooltip: L('Limpiar', 'Clear'),
                    icon: const Icon(Icons.clear),
                    onPressed: () => _guideCtrl.clear(),
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(rs(context, 16)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(rs(context, 16)),
                borderSide: BorderSide(color: _mainColor.withOpacity(0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(rs(context, 16)),
                borderSide: BorderSide(color: _mainColor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: rs(context, 14),
                vertical: rs(context, 14),
              ),
              counterText: '',
            ),
            style: TextStyle(fontSize: fs(context, 14)),
            onSubmitted: (_) => _track(),
          ),
          SizedBox(height: rs(context, 12)),
          SizedBox(
            height: rs(context, 46),
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(rs(context, 12)),
                ),
                textStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: fs(context, 14),
                ),
                padding: EdgeInsets.symmetric(horizontal: rs(context, 12)),
              ),
              onPressed: _loading ? null : _track,
              child: _loading
                  ? SizedBox(
                      width: rs(context, 20),
                      height: rs(context, 20),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(L('Rastrear', 'Track')),
            ),
          ),

          if (_error != null) ...[
            SizedBox(height: rs(context, 10)),
            Text(
              _error!,
              style: TextStyle(color: Colors.red, fontSize: fs(context, 13)),
            ),
          ],

          if (_res != null) ...[
            SizedBox(height: rs(context, 16)),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(rs(context, 16)),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.all(rs(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Servicio', 'Service'),
                                style: TextStyle(
                                  fontSize: fs(context, 18),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: rs(context, 4)),
                              Text(
                                '#${_res!['r_id_service_and_delivery_data'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: fs(context, 22),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: rs(context, 4)),
                              Text(
                                '${L('Creado', 'Created on')}: ${_fmtDT(_res!['r_created_at_local'])}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: fs(context, 12.5),
                                ),
                              ),
                              if (_res!['r_hora_salida'] != null)
                                Text(
                                  'Hora Salida: ${_fmtDT(_res!['r_hora_salida'])}',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: fs(context, 12.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            setState(() => _selectedStatus = val.toLowerCase());
                          },
                          itemBuilder: (_) => _statusOptions
                              .map(
                                (s) => PopupMenuItem<String>(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: TextStyle(fontSize: fs(context, 13)),
                                  ),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: rs(context, 10),
                              vertical: rs(context, 5),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(
                                rs(context, 12),
                              ),
                            ),
                            child: Text(
                              ((_selectedStatus ?? _res!['r_status'] ?? '-')
                                      as String)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.red,
                                fontSize: fs(context, 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: rs(context, 12)),

                    Row(
                      children: [
                        Expanded(
                          child: _chip(
                            '${L('Origen', 'Origin')}\n${_res!['r_origin'] ?? '-'}',
                            Icons.person_pin_circle,
                          ),
                        ),
                        SizedBox(width: rs(context, 10)),
                        Expanded(
                          child: _chip(
                            '${L('Destino', 'Destination')}\n${_res!['r_destination'] ?? '-'}',
                            Icons.place_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: rs(context, 14)),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(rs(context, 12)),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(rs(context, 12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L('Oficina', 'Office'),
                              style: TextStyle(
                                fontSize: fs(context, 15),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: rs(context, 10)),
                            _kv(
                              L('Nombre de la oficina', 'Office name'),
                              '${personal?['r_name_office'] ?? '-'}',
                              bold: true,
                            ),
                            SizedBox(height: rs(context, 12)),
                            DropdownButtonFormField<String>(
                              value: _selectedOfficeAction,
                              decoration: InputDecoration(
                                labelText: L(
                                  'Acción de oficina',
                                  'Office Action',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    rs(context, 10),
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: rs(context, 10),
                                  vertical: rs(context, 10),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'Recibió',
                                  child: Text(
                                    'Recibió: ${personal?['r_name_office'] ?? '-'}',
                                    style: TextStyle(fontSize: fs(context, 13)),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Envió',
                                  child: Text(
                                    'Envió: ${personal?['r_name_office'] ?? '-'}',
                                    style: TextStyle(fontSize: fs(context, 13)),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Devolvió',
                                  child: Text(
                                    'Devolvió: ${personal?['r_name_office'] ?? '-'}',
                                    style: TextStyle(fontSize: fs(context, 13)),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedOfficeAction = val);
                                _showSnack(
                                  'Seleccionaste $val: ${personal?['r_name_office'] ?? '-'}',
                                );
                              },
                            ),
                            SizedBox(height: rs(context, 10)),
                            Center(
                              child: FilledButton.icon(
                                icon: _savingStatus
                                    ? SizedBox(
                                        width: rs(context, 16),
                                        height: rs(context, 16),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save, size: 16),
                                label: Text(
                                  L('Guardar', 'Save'),
                                  style: TextStyle(
                                    fontSize: fs(context, 12.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _mainColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: rs(context, 12),
                                    vertical: rs(context, 8),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      rs(context, 10),
                                    ),
                                  ),
                                  minimumSize: Size(0, rs(context, 36)),
                                ),
                                onPressed: _savingStatus ? null : _saveStatus,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Remitente', 'Sender'),
                                style: TextStyle(
                                  fontSize: fs(context, 15),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: rs(context, 6)),
                              _kv(
                                L('Nombre', 'First name'),
                                '${_res!['r_sender_name'] ?? '-'}',
                                bold: true,
                              ),
                              _kv(
                                L('Apellido', 'Last name'),
                                '${_res!['r_sender_last_name'] ?? '-'}',
                              ),
                              _kv('Email', '${_res!['r_sender_email'] ?? '-'}'),
                              _kv(
                                L('Teléfono', 'Phone'),
                                '${_res!['r_sender_phone_number'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: rs(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Destinatario', 'Recipient'),
                                style: TextStyle(
                                  fontSize: fs(context, 15),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: rs(context, 6)),
                              _kv(
                                L('Nombre', 'First name'),
                                '${_res!['r_recipient_first_name'] ?? '-'}',
                                bold: true,
                              ),
                              _kv(
                                L('Apellido', 'Last name'),
                                '${_res!['r_recipient_last_name'] ?? '-'}',
                              ),
                              _kv(
                                'Email',
                                '${_res!['r_recipient_email'] ?? '-'}',
                              ),
                              _kv(
                                L('Teléfono', 'Phone'),
                                '${_res!['r_recipient_phone_number'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: rs(context, 14)),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Paquete', 'Package'),
                                style: TextStyle(
                                  fontSize: fs(context, 15),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: rs(context, 6)),
                              _kv(
                                L('Descripción', 'Description'),
                                '${_res!['r_package_description'] ?? '-'}',
                              ),
                              _kv(
                                L('Dimensiones', 'Dimensions'),
                                '${_res!['r_length'] ?? '-'} × ${_res!['r_width'] ?? '-'} × ${_res!['r_height'] ?? '-'}',
                              ),
                              _kv(
                                L('Peso', 'Weight'),
                                '${_res!['r_weight'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: rs(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Concepto', 'Concept'),
                                style: TextStyle(
                                  fontSize: fs(context, 15),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: rs(context, 6)),
                              _kv(
                                L('Tipo', 'Type'),
                                '${_res!['r_concept'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: rs(context, 14)),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L('Precio', 'Price'),
                                style: TextStyle(
                                  fontSize: fs(context, 15),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: rs(context, 4)),
                              _kv(
                                L('Precio por paquete', 'Unit price'),
                                '\$${(_res!['r_price_per_package'] ?? '-').toString()}',
                              ),
                              SizedBox(height: rs(context, 2)),
                              Text(
                                L('Total', 'Total price'),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: fs(context, 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(_res!['r_total_price'] ?? '-').toString()}',
                          style: TextStyle(
                            fontSize: fs(context, 17),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: rs(context, 12)),
                    Divider(color: cs.outlineVariant),
                    SizedBox(height: rs(context, 10)),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              rs(context, 12),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: rs(context, 12),
                          ),
                          textStyle: TextStyle(
                            fontSize: fs(context, 14),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () {
                          final pkgs =
                              (_res!['r_packages'] as List?) ?? const [];
                          if (pkgs.isEmpty) {
                            _showSnack(
                              L('Sin paquetes para mostrar.', 'No packages.'),
                            );
                          } else {
                            _showPackagesSheet(pkgs);
                          }
                        },
                        child: Text(
                          L('Ver todos los paquetes', 'View All Packages'),
                        ),
                      ),
                    ),

                    SizedBox(height: rs(context, 10)),

                    if ((_res!['r_derivations'] as List?)?.isNotEmpty ??
                        false) ...[
                      SizedBox(height: rs(context, 4)),
                      Text(
                        L('Derivaciones de pago', 'Payment derivations'),
                        style: TextStyle(
                          fontSize: fs(context, 15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: rs(context, 6)),
                      ...List<Map<String, dynamic>>.from(
                        (_res!['r_derivations'] as List),
                      ).map(
                        (d) => Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: rs(context, 4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${d['payment_method'] ?? '-'} • ${d['concepto'] ?? '-'}',
                                  style: TextStyle(fontSize: fs(context, 13)),
                                ),
                              ),
                              Text(
                                '\$${(d['cash_amount'] ?? 0)} / \$${(d['card_amount'] ?? 0)} / \$${(d['transfer_amount'] ?? 0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: fs(context, 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
