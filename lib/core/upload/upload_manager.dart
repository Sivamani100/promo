import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the state of a single file upload.
class UploadTask {
  final String id;
  final String fileName;
  final String bucket;
  final String storagePath;
  double progress;
  UploadStatus status;
  String? errorMessage;
  String? publicUrl;

  UploadTask({
    required this.id,
    required this.fileName,
    required this.bucket,
    required this.storagePath,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
    this.errorMessage,
    this.publicUrl,
  });
}

enum UploadStatus { pending, uploading, success, failed, retrying }

/// Manages all file uploads with progress tracking, retry logic,
/// and persistent status indicators.
///
/// Usage:
/// ```dart
/// final manager = ref.read(uploadManagerProvider);
/// final task = await manager.uploadFile(
///   bucket: 'avatars',
///   storagePath: 'user123/avatar.jpg',
///   fileBytes: bytes,
///   fileName: 'avatar.jpg',
/// );
/// ```
class UploadManager extends ChangeNotifier {
  final Map<String, UploadTask> _tasks = {};

  /// All current upload tasks.
  List<UploadTask> get tasks => _tasks.values.toList();

  /// Active (non-completed) upload tasks.
  List<UploadTask> get activeTasks =>
      _tasks.values.where((t) => t.status != UploadStatus.success).toList();

  /// Whether any uploads are currently in progress.
  bool get hasActiveUploads =>
      _tasks.values.any((t) => t.status == UploadStatus.uploading || t.status == UploadStatus.retrying);

  /// Start a new upload task.
  UploadTask createTask({
    required String id,
    required String fileName,
    required String bucket,
    required String storagePath,
  }) {
    final task = UploadTask(
      id: id,
      fileName: fileName,
      bucket: bucket,
      storagePath: storagePath,
    );
    _tasks[id] = task;
    notifyListeners();
    return task;
  }

  /// Update an upload task's progress (0.0 to 1.0).
  void updateProgress(String taskId, double progress) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.progress = progress.clamp(0.0, 1.0);
    task.status = UploadStatus.uploading;
    notifyListeners();
  }

  /// Mark an upload as completed.
  void markSuccess(String taskId, {String? publicUrl}) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.progress = 1.0;
    task.status = UploadStatus.success;
    task.publicUrl = publicUrl;
    notifyListeners();

    // Auto-remove completed tasks after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _tasks.remove(taskId);
      notifyListeners();
    });
  }

  /// Mark an upload as failed.
  void markFailed(String taskId, String error) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.status = UploadStatus.failed;
    task.errorMessage = error;
    notifyListeners();
  }

  /// Mark an upload as retrying.
  void markRetrying(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.status = UploadStatus.retrying;
    task.errorMessage = null;
    notifyListeners();
  }

  /// Remove a task (for dismissing failed uploads).
  void removeTask(String taskId) {
    _tasks.remove(taskId);
    notifyListeners();
  }

  /// Clear all completed and failed tasks.
  void clearCompleted() {
    _tasks.removeWhere((_, t) =>
        t.status == UploadStatus.success || t.status == UploadStatus.failed);
    notifyListeners();
  }
}

/// Global upload manager provider.
final uploadManagerProvider = ChangeNotifierProvider<UploadManager>(
  (ref) => UploadManager(),
);
