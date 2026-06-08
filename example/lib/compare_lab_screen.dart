import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:handpickd_image_compare/handpickd_image_compare.dart';
import 'package:image_picker/image_picker.dart';

class CompareLabScreen extends StatefulWidget {
  const CompareLabScreen({super.key});

  @override
  State<CompareLabScreen> createState() => _CompareLabScreenState();
}

class _CompareLabScreenState extends State<CompareLabScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _referenceBytes;
  final List<_LabImage> _queryImages = [];

  bool _running = false;
  _MatrixResult? _matrix;
  String? _error;

  Future<void> _pickReference() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _referenceBytes = bytes;
      _matrix = null;
      _error = null;
    });
  }

  Future<void> _addQueries() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;

    final picked = <_LabImage>[];
    final startIndex = _queryImages.length;
    for (var i = 0; i < files.length; i++) {
      picked.add(
        _LabImage(
          id: 'q${startIndex + i + 1}',
          label: 'Image ${startIndex + i + 1}',
          bytes: await files[i].readAsBytes(),
        ),
      );
    }

    setState(() {
      _queryImages.addAll(picked);
      _matrix = null;
      _error = null;
    });
  }

  void _removeQuery(String id) {
    setState(() {
      _queryImages.removeWhere((image) => image.id == id);
      _matrix = null;
    });
  }

  void _clearAll() {
    setState(() {
      _referenceBytes = null;
      _queryImages.clear();
      _matrix = null;
      _error = null;
    });
  }

  Future<void> _runFullMatrix() async {
    final reference = _referenceBytes;
    if (reference == null) {
      setState(() => _error = 'Upload a reference image first.');
      return;
    }
    if (_queryImages.isEmpty) {
      setState(() => _error = 'Upload at least one query image.');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _matrix = null;
    });

    try {
      // ignore: avoid_print
      print(
        '[ImageCompareLab] matrix start | presets=${comparePresets.length} '
        'queries=${_queryImages.length} '
        'total=${comparePresets.length * _queryImages.length}',
      );

      final cells = <String, Map<String, _LabResultCell>>{};
      for (final preset in comparePresets) {
        // ignore: avoid_print
        print('[ImageCompareLab] preset=${preset.id} stage=${preset.stage}');
        final row = <String, _LabResultCell>{};
        final options = preset.options.copyWith(logCompareSteps: true);
        for (final query in _queryImages) {
          // ignore: avoid_print
          print('[ImageCompareLab] compare ${preset.id} × ${query.label}');
          final scores = await compareWithOptions(
            reference,
            query.bytes,
            options,
          );
          row[query.id] = _LabResultCell(
            preset: preset,
            query: query,
            scores: scores,
          );
        }
        cells[preset.id] = row;
      }

      // ignore: avoid_print
      print('[ImageCompareLab] matrix complete');

      setState(() {
        _matrix = _MatrixResult(
          presets: List<ComparePreset>.from(comparePresets),
          queries: List<_LabImage>.from(_queryImages),
          cells: cells,
        );
      });
    } catch (e) {
      setState(() => _error = 'Compare failed: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Compare Lab'),
        actions: [
          if (_referenceBytes != null || _queryImages.isNotEmpty)
            IconButton(
              tooltip: 'Clear all images',
              onPressed: _running ? null : _clearAll,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('1. Reference image'),
          _imagePickerRow(
            bytes: _referenceBytes,
            onPick: _pickReference,
            pickLabel: 'Upload reference',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Query images'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in _queryImages)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _thumb(query.bytes, query.label),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _running ? null : () => _removeQuery(query.id),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _running ? null : _addQueries,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload query images'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Run full matrix'),
          Text(
            'Runs all ${comparePresets.length} presets (${comparePresets.where((p) => p.stage == 'pre-resize').length} pre-resize + '
            '${comparePresets.where((p) => p.stage == 'post-resize').length} post-1024) '
            'against every uploaded query. Logs print in debug console.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _runFullMatrix,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.grid_on),
            label: Text(
              _running
                  ? 'Running ${comparePresets.length} × ${_queryImages.length}...'
                  : _queryImages.isEmpty
                      ? 'Run all combinations'
                      : 'Run ${comparePresets.length} presets × ${_queryImages.length} images',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_matrix != null) ...[
            const SizedBox(height: 24),
            _sectionTitle('4. Result matrix (overall %)'),
            const SizedBox(height: 8),
            _matrixSummary(_matrix!),
            const SizedBox(height: 12),
            _resultMatrix(_matrix!),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _imagePickerRow({
    required Uint8List? bytes,
    required VoidCallback onPick,
    required String pickLabel,
  }) {
    return Row(
      children: [
        if (bytes != null) _thumb(bytes, 'Reference'),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _running ? null : onPick,
          icon: const Icon(Icons.upload_outlined),
          label: Text(pickLabel),
        ),
      ],
    );
  }

  Widget _thumb(Uint8List bytes, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 88,
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _matrixSummary(_MatrixResult matrix) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Best per query image',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final query in matrix.queries) ...[
              Builder(
                builder: (context) {
                  late _LabResultCell best;
                  var hasBest = false;
                  for (final preset in matrix.presets) {
                    final cell = matrix.cells[preset.id]![query.id]!;
                    if (!hasBest ||
                        cell.scores.overallPercent > best.scores.overallPercent) {
                      best = cell;
                      hasBest = true;
                    }
                  }
                  final winner = best;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${query.label}: ${winner.scores.overallPercent.toStringAsFixed(1)}% '
                      '(${winner.preset.label}, ${winner.scores.timings.total.inMilliseconds}ms)',
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultMatrix(_MatrixResult matrix) {
    const presetColumnWidth = 148.0;
    const queryColumnWidth = 108.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: presetColumnWidth,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Preset', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                for (final query in matrix.queries)
                  SizedBox(
                    width: queryColumnWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              query.bytes,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            query.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 1),
            ...() {
              final rows = <Widget>[];
              String? lastStage;
              for (final preset in matrix.presets) {
                if (preset.stage != lastStage) {
                  lastStage = preset.stage;
                  rows.add(
                    Container(
                      width: presetColumnWidth +
                          queryColumnWidth * matrix.queries.length,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        preset.stage == 'pre-resize'
                            ? 'Before resize (original bytes)'
                            : 'After 1024px resize',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
                rows.add(
                  Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: presetColumnWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _optionsSummary(preset.options),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final query in matrix.queries)
                    SizedBox(
                      width: queryColumnWidth,
                      child: _matrixCell(
                        matrix.cells[preset.id]![query.id]!,
                      ),
                    ),
                  ],
                ),
                );
              }
              return rows;
            }(),
          ],
        ),
      ),
    );
  }

  Widget _matrixCell(_LabResultCell cell) {
    final overall = cell.scores.overallPercent;
    final ms = cell.scores.timings.total.inMilliseconds;

    return InkWell(
      onTap: () => _showCellDetails(cell),
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _scoreColor(overall).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _scoreColor(overall).withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              '${overall.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _scoreColor(overall),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text('$ms ms', style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showCellDetails(_LabResultCell cell) {
    final scores = cell.scores;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '${cell.preset.label} × ${cell.query.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Overall ${scores.overallPercent.toStringAsFixed(1)}%'),
              if (scores.inputMeta != null) ...[
                const SizedBox(height: 8),
                Text('Pipeline: ${scores.inputMeta!.stageLabel}'),
                Text('Ref original: ${scores.inputMeta!.referenceOriginal}'),
                Text('Query original: ${scores.inputMeta!.queryOriginal}'),
                Text('Ref prepared: ${scores.inputMeta!.referencePrepared}'),
                Text('Query prepared: ${scores.inputMeta!.queryPrepared}'),
                const Divider(),
              ],
              _metricRow('Visual', scores.visualPercent),
              _metricRow('OpenCV best', scores.openCvBest * 100),
              _metricRow('OpenCV forward', scores.openCvForward * 100),
              _metricRow('OpenCV reverse', scores.openCvReverse * 100),
              _metricRow('Perceptual hash', scores.perceptualHashPercent),
              _metricRow('Difference hash', scores.differenceHashPercent),
              _metricRow('Average hash', scores.averageHashPercent),
              _metricRow('OCR', scores.ocrPercent),
            ],
          ),
        );
      },
    );
  }

  String _optionsSummary(ImageCompareOptions options) {
    final parts = <String>[
      if (options.maxImageDimension != null) '${options.maxImageDimension}px',
      if (!options.openCvBidirectional) 'fwd',
      if (options.openCvReuseInstance) 'reuse',
      if (!options.openCv) 'no-cv',
      if (options.ocr) 'ocr',
    ];
    return parts.isEmpty ? 'legacy' : parts.join(' · ');
  }

  Widget _metricRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text('${value.toStringAsFixed(1)}%', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double percent) {
    if (percent >= 70) return Colors.green.shade700;
    if (percent >= 50) return Colors.orange.shade800;
    return Colors.red.shade700;
  }
}

class _LabImage {
  const _LabImage({
    required this.id,
    required this.label,
    required this.bytes,
  });

  final String id;
  final String label;
  final Uint8List bytes;
}

class _LabResultCell {
  const _LabResultCell({
    required this.preset,
    required this.query,
    required this.scores,
  });

  final ComparePreset preset;
  final _LabImage query;
  final CompareScores scores;
}

class _MatrixResult {
  const _MatrixResult({
    required this.presets,
    required this.queries,
    required this.cells,
  });

  final List<ComparePreset> presets;
  final List<_LabImage> queries;
  final Map<String, Map<String, _LabResultCell>> cells;
}
