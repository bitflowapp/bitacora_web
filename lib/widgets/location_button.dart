// lib/widgets/location_button.dart
// Botón + sheet de ubicación por fila.
// Usa RowGeoStore para persistir y LocationWebService para abrir/compartir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/location_service.dart';
import '../services/location_web_service.dart';
import '../services/row_geo_store.dart';

/// Debe devolver (sheetId, row) de la fila actualmente enfocada.
/// Si no hay fila seleccionada, retorna null.
typedef RowLocator = (String sheetId, int row)? Function();

class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.getCurrentRow,
  });

  final RowLocator getCurrentRow;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ubicación de la fila',
      icon: const Icon(Icons.my_location),
      onPressed: () => _openSheet(context),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final loc = getCurrentRow();
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccioná una fila para usar ubicación'),
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(
        sheetId: loc.$1,
        row: loc.$2,
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({
    required this.sheetId,
    required this.row,
  });

  final String sheetId;
  final int row;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  bool _busy = false;
  String? _error;
  RowGeo? _geo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await RowGeoStore.I.get(widget.sheetId, widget.row);
    if (!mounted) return;
    setState(() => _geo = g);
  }

  String _fmt(double v) => v.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = 'Ubicación — Fila ${widget.row + 1}';

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Borrar',
                    onPressed: (_geo == null || _busy)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _busy = true);
                            await RowGeoStore.I.clear(
                              widget.sheetId,
                              widget.row,
                            );
                            await _load();
                            if (!mounted) return;
                            setState(() => _busy = false);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Ubicación eliminada'),
                                duration: Duration(milliseconds: 1400),
                              ),
                            );
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: cs.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (_geo == null)
                Opacity(
                  opacity: 0.8,
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 40,
                        color: theme.iconTheme.color?.withValues(alpha: 
                            theme.brightness == Brightness.dark ? 0.7 : 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sin ubicación guardada',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tocá “Obtener/Actualizar” para guardar la posición GPS de esta fila.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: cs.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      '${_fmt(_geo!.lat)}, ${_fmt(_geo!.lng)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Precisión: ${_geo!.accuracyM?.toStringAsFixed(1) ?? '-'} m | ${_geo!.ts}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Abrir en mapa',
                      icon: const Icon(Icons.map_outlined),
                      onPressed: () async {
                        await LocationWebService.I.openInMaps(
                          _geo!.lat,
                          _geo!.lng,
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _onCapture,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Obtener/Actualizar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_geo != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final txt = LocationWebService.I.shareText(
                            LocationFix(
                              latitude: _geo!.lat,
                              longitude: _geo!.lng,
                              accuracyMeters: _geo!.accuracyM,
                              timestamp: _geo!.ts,
                              source: 'stored',
                            ),
                          );
                          Clipboard.setData(ClipboardData(text: txt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ubicación copiada'),
                              duration: Duration(milliseconds: 1300),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copiar'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCapture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fix = await LocationWebService.I.getCurrent();
      final g = RowGeo(
        sheetId: widget.sheetId,
        row: widget.row,
        lat: fix.latitude,
        lng: fix.longitude,
        accuracyM: fix.accuracyMeters,
        ts: fix.timestamp,
      );
      await RowGeoStore.I.save(g);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación actualizada'),
          duration: Duration(milliseconds: 1400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
