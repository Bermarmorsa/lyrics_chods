// lib/screens/concerts/concert_detail_screen.dart

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/concert_recording.dart';
import '../../services/concert_service.dart';

class ConcertDetailScreen extends StatelessWidget {
  final ConcertRecording recording;

  const ConcertDetailScreen({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: Text(
          recording.name,
          style: const TextStyle(
              color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar',
            onPressed: () => ConcertService.exportAndShare(recording),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ConcertChart(recording: recording),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final duration = _formatDuration(recording.durationMs);
    final date = _formatDate(recording.startTime);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _InfoChip(icon: Icons.queue_music, label: recording.setlistName),
          _InfoChip(icon: Icons.calendar_today, label: date),
          _InfoChip(icon: Icons.timer_outlined, label: duration),
          _InfoChip(
            icon: Icons.music_note,
            label: '${recording.songTitles.length} canciones',
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ViewerColors.artist),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: ViewerColors.artist, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gráfica
// ---------------------------------------------------------------------------

class _ConcertChart extends StatelessWidget {
  final ConcertRecording recording;
  const _ConcertChart({required this.recording});

  @override
  Widget build(BuildContext context) {
    if (recording.events.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos de grabación',
          style: TextStyle(color: ViewerColors.artist),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _ChartPainter(recording: recording),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final ConcertRecording recording;

  // Márgenes del área de gráfica dentro del canvas
  static const double _left = 52.0;
  static const double _right = 16.0;
  static const double _top = 16.0;
  static const double _bottom = 48.0;

  _ChartPainter({required this.recording});

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _left - _right;
    final chartH = size.height - _top - _bottom;
    final totalSongs = recording.songTitles.length;
    final maxT = recording.durationMs > 0 ? recording.durationMs : 1;

    // Punto de inicio implícito (t=0, canción 0, scroll 0)
    final allEvents = [
      ConcertEvent(
        elapsedMs: 0,
        type: ConcertEventType.songChange,
        songIndex: 0,
        scrollFraction: 0.0,
      ),
      ...recording.events,
    ];

    // ---------------------------------------------------------------------------
    // Helpers de conversión coordenadas
    // ---------------------------------------------------------------------------
    double toX(int ms) => _left + (ms / maxT) * chartW;
    double toY(int songIndex, double frac) {
      final progress =
          totalSongs > 0 ? (songIndex + frac) / totalSongs : 0.0;
      return _top + chartH - progress.clamp(0.0, 1.0) * chartH;
    }

    // ---------------------------------------------------------------------------
    // Fondo del área de gráfica
    // ---------------------------------------------------------------------------
    final bgPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(
        Rect.fromLTWH(_left, _top, chartW, chartH), bgPaint);

    // ---------------------------------------------------------------------------
    // Líneas de cuadrícula Y (0%, 25%, 50%, 75%, 100%)
    // ---------------------------------------------------------------------------
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(
        color: ViewerColors.separator, fontSize: 10);

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = _top + chartH - (pct / 100) * chartH;
      canvas.drawLine(
          Offset(_left, y), Offset(_left + chartW, y), gridPaint);
      _drawText(canvas, '$pct%', Offset(_left - 6, y - 5),
          style: labelStyle, align: TextAlign.right, maxWidth: 40);
    }

    // ---------------------------------------------------------------------------
    // Etiqueta eje Y
    // ---------------------------------------------------------------------------
    _drawRotatedText(
      canvas,
      'avance setlist',
      Offset(10, _top + chartH / 2),
      style: const TextStyle(color: ViewerColors.separator, fontSize: 10),
    );

    // ---------------------------------------------------------------------------
    // Líneas verticales en cambios de canción + etiquetas
    // ---------------------------------------------------------------------------
    final songChangePaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 2;

    final songChangeEvents = allEvents
        .where((e) => e.type == ConcertEventType.songChange)
        .toList();

    for (final event in songChangeEvents) {
      final x = toX(event.elapsedMs);
      canvas.drawLine(
        Offset(x, _top),
        Offset(x, _top + chartH),
        songChangePaint,
      );
      // Etiqueta del nombre de la canción
      final title = event.songIndex < recording.songTitles.length
          ? recording.songTitles[event.songIndex]
          : 'canción ${event.songIndex + 1}';
      _drawText(
        canvas,
        title,
        Offset(x + 3, _top + 2),
        style: const TextStyle(color: ViewerColors.artist, fontSize: 9),
        maxWidth: 70,
      );
    }

    // ---------------------------------------------------------------------------
    // Curva de progreso
    // ---------------------------------------------------------------------------
    final linePaint = Paint()
      ..color = ViewerColors.chord
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool first = true;
    for (final event in allEvents) {
      final x = toX(event.elapsedMs);
      final y = toY(event.songIndex, event.scrollFraction);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Puntos en cada evento
    final dotPaint = Paint()
      ..color = ViewerColors.chord
      ..style = PaintingStyle.fill;
    for (final event in allEvents) {
      if (event.type == ConcertEventType.songChange) continue;
      canvas.drawCircle(
        Offset(toX(event.elapsedMs),
            toY(event.songIndex, event.scrollFraction)),
        3,
        dotPaint,
      );
    }

    // ---------------------------------------------------------------------------
    // Eje X — marcas de tiempo
    // ---------------------------------------------------------------------------
    final totalMinutes = maxT / 60000;
    final tickInterval = _niceTickInterval(totalMinutes);
    final axisPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(_left, _top + chartH),
        Offset(_left + chartW, _top + chartH),
        axisPaint);

    double t = 0;
    while (t <= totalMinutes + 0.001) {
      final x = _left + (t / totalMinutes) * chartW;
      final y = _top + chartH;
      canvas.drawLine(Offset(x, y), Offset(x, y + 5), axisPaint);
      _drawText(
        canvas,
        t == 0 ? '0 min' : '${t.toStringAsFixed(0)} min',
        Offset(x - 14, y + 8),
        style: const TextStyle(color: ViewerColors.separator, fontSize: 9),
        maxWidth: 40,
      );
      t += tickInterval;
    }

    // ---------------------------------------------------------------------------
    // Eje Y — borde izquierdo
    // ---------------------------------------------------------------------------
    canvas.drawLine(
      Offset(_left, _top),
      Offset(_left, _top + chartH),
      axisPaint,
    );
  }

  // Calcula un intervalo de marcas agradable para el eje X
  double _niceTickInterval(double totalMinutes) {
    if (totalMinutes <= 5) return 1;
    if (totalMinutes <= 15) return 2;
    if (totalMinutes <= 30) return 5;
    if (totalMinutes <= 60) return 10;
    return 15;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required TextStyle style,
    TextAlign align = TextAlign.left,
    double maxWidth = 120,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  void _drawRotatedText(Canvas canvas, String text, Offset center,
      {required TextStyle style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-3.14159 / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.recording != recording;
}
