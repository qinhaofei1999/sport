import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/analysis_result.dart';

class ResultScreen extends StatefulWidget {
  final AnalysisResult? result;

  const ResultScreen({super.key, this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<AnalysisResult> _history = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.result == null) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = Directory(dir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      _history = [];
      for (final f in files.take(20)) {
        try {
          final json = jsonDecode(await f.readAsString());
          _history.add(AnalysisResult.fromJson(json));
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result != null) {
      return _buildResultPage(widget.result!);
    }
    return _buildHistoryPage();
  }

  Widget _buildHistoryPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        backgroundColor: const Color(0xFF0F2027),
      ),
      backgroundColor: const Color(0xFF0F2027),
      body: _loadingHistory
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Text('暂无记录',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
                ),
    );
  }

  Widget _buildHistoryCard(AnalysisResult result) {
    final isRunning = result.sportType == 'running';
    return Card(
      color: Colors.white.withAlpha(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(
          isRunning ? Icons.directions_run : Icons.pool,
          color: isRunning ? Colors.orangeAccent : Colors.lightBlueAccent,
        ),
        title: Text(
          '${isRunning ? '跑步' : '游泳'} · ${result.videoMeta.durationSec.toStringAsFixed(1)}s',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          isRunning
              ? '${result.summary.totalSteps} 步 · ${result.summary.cadenceSpm} spm'
              : '${result.summary.totalSteps} 次划水 · ${result.summary.cadenceSpm} spm',
          style: TextStyle(color: Colors.white.withAlpha(150)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ResultScreen(result: result)),
        ),
      ),
    );
  }

  Widget _buildResultPage(AnalysisResult result) {
    final isRunning = result.sportType == 'running';
    return Scaffold(
      appBar: AppBar(
        title: Text(isRunning ? '跑步分析结果' : '游泳分析结果'),
        backgroundColor: const Color(0xFF0F2027),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _exportJson(result),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F2027),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(result),
            const SizedBox(height: 16),
            _buildAnglesCard(result),
            const SizedBox(height: 16),
            _buildEventsCard(result),
            if (result.cycles.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCyclesCard(result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AnalysisResult result) {
    final s = result.summary;
    return _card(
      children: [
        const Text('总览',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _statRow('时长', '${s.durationSec.toStringAsFixed(1)} 秒'),
        _statRow(result.sportType == 'running' ? '步数' : '划水次数',
            '${s.totalSteps}'),
        _statRow(
            result.sportType == 'running' ? '步频' : '划频',
            '${s.cadenceSpm} ${result.sportType == 'running' ? 'spm' : 'spm'}'),
        _statRow('检测率',
            '${(result.stats.detectionRate * 100).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildAnglesCard(AnalysisResult result) {
    final s = result.summary;
    return _card(
      children: [
        const Text('关节角度平均值',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (s.avgHipAngleLeft != null)
          _angleRow('左髋', s.avgHipAngleLeft!, s.avgHipAngleRight),
        if (s.avgKneeAngleLeft != null)
          _angleRow('左膝', s.avgKneeAngleLeft!, s.avgKneeAngleRight),
        if (s.avgAnkleAngleLeft != null)
          _angleRow('左踝', s.avgAnkleAngleLeft!, s.avgAnkleAngleRight),
      ],
    );
  }

  Widget _buildEventsCard(AnalysisResult result) {
    return _card(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('事件',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text('共 ${result.events.length} 个',
                style: TextStyle(color: Colors.white.withAlpha(150))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            itemCount: result.events.length.clamp(0, 50),
            itemBuilder: (_, i) {
              final e = result.events[i];
              final label = '${e.eventType} · ${e.side}';
              final time = e.timestamp.toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: e.side == 'left'
                            ? Colors.lightGreen
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Text('${time}s',
                        style:
                            const TextStyle(color: Colors.white38)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCyclesCard(AnalysisResult result) {
    return _card(
      children: [
        const Text('步态周期',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...result.cycles.take(10).map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text('周期 ${c.cycleId + 1}',
                      style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Text('${c.durationSec.toStringAsFixed(2)}s',
                      style: const TextStyle(color: Colors.white54)),
                  const SizedBox(width: 12),
                  if (c.cadenceSpm != null)
                    Text('${c.cadenceSpm!.toStringAsFixed(0)} spm',
                        style: TextStyle(
                            color: Colors.cyanAccent.withAlpha(180))),
                ],
              ),
            )),
        if (result.cycles.length > 10)
          Text('... 还有 ${result.cycles.length - 10} 个周期',
              style: TextStyle(color: Colors.white.withAlpha(100))),
      ],
    );
  }

  Future<void> _exportJson(AnalysisResult result) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.json');
      final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
      await file.writeAsString(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(180))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _angleRow(String label, double left, double? right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label  ',
              style: TextStyle(color: Colors.white.withAlpha(180))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.lightGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('左 ${left.toStringAsFixed(1)}°',
                style: const TextStyle(
                    color: Colors.lightGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          if (right != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('右 ${right.toStringAsFixed(1)}°',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
