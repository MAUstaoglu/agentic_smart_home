import 'dart:async';
import 'dart:io';

/// Information about the current download progress.
class DownloadProgressInfo {
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final double speedMbBytesPerSec;
  final Duration estimatedTimeRemaining;
  final String status; // 'downloading', 'paused', 'failed', 'completed', 'idle'
  final String? errorMessage;

  DownloadProgressInfo({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedMbBytesPerSec,
    required this.estimatedTimeRemaining,
    required this.status,
    this.errorMessage,
  });

  factory DownloadProgressInfo.idle() {
    return DownloadProgressInfo(
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: -1,
      speedMbBytesPerSec: 0.0,
      estimatedTimeRemaining: Duration.zero,
      status: 'idle',
    );
  }
}

/// A downloader that downloads files using HTTP Range requests for resumption.
class ResumableDownloader {
  final String url;
  final String savePath;

  HttpClient? _client;
  HttpClientRequest? _request;
  StreamSubscription<List<int>>? _subscription;
  File? _file;
  IOSink? _sink;

  final _progressController = StreamController<DownloadProgressInfo>.broadcast();
  Stream<DownloadProgressInfo> get progressStream => _progressController.stream;

  int _downloadedBytes = 0;
  int _totalBytes = -1;
  String _status = 'idle';

  ResumableDownloader({required this.url, required this.savePath}) {
    _file = File(savePath);
  }

  /// Start or resume the download
  Future<void> start() async {
    if (_status == 'downloading') return;
    _status = 'downloading';
    _emitProgress(0.0, _downloadedBytes, _totalBytes, 0.0, Duration.zero, 'downloading');

    try {
      // 1. Get existing file size
      if (await _file!.exists()) {
        _downloadedBytes = await _file!.length();
      } else {
        await _file!.create(recursive: true);
        _downloadedBytes = 0;
      }

      // 2. Perform a HEAD or GET request to check the server capabilities and length
      _client = HttpClient();
      
      // We will perform a HEAD request to check file size and range support
      final headUri = Uri.parse(url);
      final headRequest = await _client!.headUrl(headUri);
      final headResponse = await headRequest.close();
      
      _totalBytes = headResponse.contentLength;
      final acceptRanges = headResponse.headers.value('accept-ranges');
      final supportsRanges = acceptRanges == 'bytes' || 
          headResponse.headers.value('content-range') != null ||
          headResponse.statusCode == 206;

      // Close HEAD connection
      _client!.close(force: true);
      _client = HttpClient();

      // If server doesn't support ranges or we downloaded more than total, reset
      if (!supportsRanges || (_totalBytes > 0 && _downloadedBytes >= _totalBytes)) {
        _downloadedBytes = 0;
        await _file!.writeAsBytes([], mode: FileMode.write);
      }

      // 3. Initiate GET request
      final getUri = Uri.parse(url);
      _request = await _client!.getUrl(getUri);

      // Add Range header if we have partially downloaded data
      if (_downloadedBytes > 0 && _totalBytes > 0 && _downloadedBytes < _totalBytes) {
        _request!.headers.set('Range', 'bytes=$_downloadedBytes-');
      }

      final response = await _request!.close();

      // Check status code
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Server returned status code ${response.statusCode}');
      }

      // If we get 200 but expected 206, server ignored Range header; reset file
      if (response.statusCode == 200) {
        _downloadedBytes = 0;
        _sink = _file!.openWrite(mode: FileMode.write);
      } else {
        _sink = _file!.openWrite(mode: FileMode.append);
      }

      if (_totalBytes <= 0) {
        _totalBytes = response.contentLength;
      }

      final startTime = DateTime.now();
      int bytesDownloadedInSession = 0;

      _subscription = response.listen(
        (chunk) {
          _sink!.add(chunk);
          _downloadedBytes += chunk.length;
          bytesDownloadedInSession += chunk.length;

          final elapsed = DateTime.now().difference(startTime);
          final speed = elapsed.inMilliseconds > 0
              ? (bytesDownloadedInSession / (elapsed.inMilliseconds / 1000.0))
              : 0.0;

          final remainingBytes = _totalBytes > _downloadedBytes ? (_totalBytes - _downloadedBytes) : 0;
          final timeRemaining = speed > 0
              ? Duration(seconds: (remainingBytes / speed).round())
              : Duration.zero;

          final progressPercent = _totalBytes > 0 ? (_downloadedBytes / _totalBytes) : 0.0;

          _emitProgress(
            progressPercent,
            _downloadedBytes,
            _totalBytes,
            speed / (1024 * 1024), // MB/s
            timeRemaining,
            'downloading',
          );
        },
        onError: (err) {
          _status = 'failed';
          _cleanup();
          _emitProgress(
            _totalBytes > 0 ? (_downloadedBytes / _totalBytes) : 0.0,
            _downloadedBytes,
            _totalBytes,
            0.0,
            Duration.zero,
            'failed',
            errorMessage: err.toString(),
          );
        },
        onDone: () async {
          _status = 'completed';
          await _sink?.flush();
          await _sink?.close();
          _cleanup();

          _emitProgress(
            1.0,
            _totalBytes > 0 ? _totalBytes : _downloadedBytes,
            _totalBytes > 0 ? _totalBytes : _downloadedBytes,
            0.0,
            Duration.zero,
            'completed',
          );
        },
        cancelOnError: true,
      );

    } catch (e) {
      _status = 'failed';
      _cleanup();
      _emitProgress(
        _totalBytes > 0 ? (_downloadedBytes / _totalBytes) : 0.0,
        _downloadedBytes,
        _totalBytes > 0 ? _totalBytes : 0,
        0.0,
        Duration.zero,
        'failed',
        errorMessage: e.toString(),
      );
    }
  }

  /// Pause the download
  void pause() {
    if (_status != 'downloading') return;
    _status = 'paused';

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    _sink?.flush();
    _sink?.close();
    _sink = null;

    _request?.abort();
    _request = null;

    _client?.close(force: true);
    _client = null;

    _emitProgress(
      _totalBytes > 0 ? (_downloadedBytes / _totalBytes) : 0.0,
      _downloadedBytes,
      _totalBytes,
      0.0,
      Duration.zero,
      'paused',
    );
  }

  /// Reset the downloader (delete partial file and start over)
  Future<void> reset() async {
    pause();
    if (await _file!.exists()) {
      await _file!.delete();
    }
    _downloadedBytes = 0;
    _totalBytes = -1;
    _status = 'idle';
    _emitProgress(0.0, 0, -1, 0.0, Duration.zero, 'idle');
  }

  void _cleanup() {
    _subscription = null;
    _sink = null;
    _request = null;
    _client = null;
  }

  void _emitProgress(
    double progress,
    int downloaded,
    int total,
    double speed,
    Duration remaining,
    String status, {
    String? errorMessage,
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(DownloadProgressInfo(
        progress: progress,
        downloadedBytes: downloaded,
        totalBytes: total,
        speedMbBytesPerSec: speed,
        estimatedTimeRemaining: remaining,
        status: status,
        errorMessage: errorMessage,
      ));
    }
  }

  void dispose() {
    pause();
    _progressController.close();
  }
}
