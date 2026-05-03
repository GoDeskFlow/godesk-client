// Transfer queue model + mock data + simulated progress.
// Direct port of TRANSFER_QUEUE / COMPLETED + setInterval animator from
// godesk-skeuo-files.jsx.

import 'dart:async';

import 'package:flutter/foundation.dart';

enum TransferDir { send, receive }

class TransferItem {
  TransferItem({
    required this.id,
    required this.name,
    required this.size,
    required this.sent,
    required this.dir,
    required this.speed,
    required this.eta,
    this.done = false,
    this.queued = false,
    this.isFolder = false,
  });

  final int id;
  final String name;
  final int size;
  int sent;
  final TransferDir dir;
  final int speed;
  int eta;
  bool done;
  bool queued;

  /// Whether [name] designates a directory rather than a file. Drives folder-first
  /// ordering in the queue (RuDesktop 2.8.1532 parity).
  final bool isFolder;

  double get progress => done ? 1.0 : queued ? 0.0 : sent / size;

  /// Filename extension without the dot, lowercased. Empty for folders or
  /// extensionless names. Used by the Ext column on FilesScreen.
  String get extension {
    if (isFolder) return '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

class CompletedItem {
  const CompletedItem({
    required this.name,
    required this.size,
    required this.time,
    required this.dir,
  });
  final String name;
  final int size;
  final String time;
  final TransferDir dir;
}

const completedItems = <CompletedItem>[
  CompletedItem(name: 'Documents/', size: 88402000, time: '2 min ago', dir: TransferDir.send),
  CompletedItem(name: 'config.yml', size: 4240, time: '8 min ago', dir: TransferDir.receive),
  CompletedItem(name: 'photos.zip', size: 2140000000, time: '1 hr ago', dir: TransferDir.send),
];

List<TransferItem> initialQueue() => <TransferItem>[
      TransferItem(id: 1, name: 'build-2026.05.03.tar.gz', size: 482311220, sent: 312104820, dir: TransferDir.send, speed: 18400000, eta: 9),
      TransferItem(id: 2, name: 'design-system-export.zip', size: 156009400, sent: 156009400, dir: TransferDir.send, speed: 0, eta: 0, done: true),
      TransferItem(id: 3, name: 'kernel.log', size: 12400000, sent: 4200000, dir: TransferDir.receive, speed: 1900000, eta: 4),
      TransferItem(id: 4, name: 'screenshot-monitor-2.png', size: 4120000, sent: 0, dir: TransferDir.send, speed: 0, eta: 0, queued: true),
      TransferItem(id: 5, name: 'patch-firmware.bin', size: 28700000, sent: 0, dir: TransferDir.send, speed: 0, eta: 0, queued: true),
      TransferItem(id: 6, name: 'project-assets', size: 612000000, sent: 0, dir: TransferDir.send, speed: 0, eta: 0, queued: true, isFolder: true),
    ];

class TransferController extends ChangeNotifier {
  TransferController() : queue = initialQueue();

  final List<TransferItem> queue;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    var changed = false;
    for (final item in queue) {
      if (item.done || item.queued) continue;
      final newSent = (item.sent + (item.speed * 0.4).round()).clamp(0, item.size);
      final isDone = newSent >= item.size;
      if (newSent != item.sent || isDone) {
        item.sent = newSent;
        item.done = isDone;
        item.eta = item.speed > 0 ? ((item.size - newSent) / item.speed).round().clamp(0, 99999) : 0;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
