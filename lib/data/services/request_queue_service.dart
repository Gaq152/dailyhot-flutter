import 'dart:async';
import 'dart:collection';

/// 请求队列服务，用于控制并发请求数量
/// 防止首次启动时大量请求同时发出导致超时
class RequestQueueService {
  /// 最大并发请求数
  final int maxConcurrent;

  /// 当前正在执行的请求数
  int _currentRequests = 0;

  /// 等待执行的请求队列
  final Queue<_QueuedRequest> _queue = Queue();

  RequestQueueService({this.maxConcurrent = 5});

  /// 将请求加入队列并执行
  Future<T> enqueue<T>(Future<T> Function() request) async {
    final completer = Completer<T>();
    final queuedRequest = _QueuedRequest<T>(request, completer);

    _queue.add(queuedRequest);
    _processQueue();

    return completer.future;
  }

  /// 处理队列中的请求
  void _processQueue() {
    // 如果已达到最大并发数，或队列为空，则不处理
    if (_currentRequests >= maxConcurrent || _queue.isEmpty) {
      return;
    }

    // 取出队列头部的请求
    final queuedRequest = _queue.removeFirst();
    _currentRequests++;

    // 执行请求
    queuedRequest.request().then((result) {
      // 请求成功，返回结果
      queuedRequest.completer.complete(result);
    }).catchError((error, stackTrace) {
      // 请求失败，返回错误
      queuedRequest.completer.completeError(error, stackTrace);
    }).whenComplete(() {
      // 请求完成，减少计数并处理下一个请求
      _currentRequests--;
      _processQueue();
    });

    // 继续处理队列中的其他请求（如果还有空闲位置）
    _processQueue();
  }

  /// 清空队列
  void clear() {
    _queue.clear();
  }

  /// 获取队列长度
  int get queueLength => _queue.length;

  /// 获取当前正在执行的请求数
  int get currentRequests => _currentRequests;
}

/// 队列中的请求
class _QueuedRequest<T> {
  final Future<T> Function() request;
  final Completer<T> completer;

  _QueuedRequest(this.request, this.completer);
}
