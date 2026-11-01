import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cuota/core/errors/failures.dart';
import 'package:cuota/core/platform/file_permissions.dart';
import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:cuota/features/proxy/data/cntlm_config.dart';
import 'package:cuota/features/proxy/domain/proxy.dart';

/// Runs cntlm as a child process.
class CntlmProxyGateway implements ProxyGateway {
  CntlmProxyGateway({
    required this.tempDir,
    String? executable,
    this.startTimeout = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 2),
  }) : executable = executable ?? _defaultExecutable();

  final String tempDir;
  final String executable;
  final Duration startTimeout;
  final Duration stopTimeout;

  final _exits = StreamController<String>.broadcast();
  final _output = <String>[];
  Process? _process;
  Future<int>? _exitCode;
  bool _stopping = false;

  String get _sep => Platform.pathSeparator;
  String get _configPath => '$tempDir${_sep}cntlm.conf';
  String get _pidPath => '$tempDir${_sep}cntlm.pid';

  static String _defaultExecutable() {
    if (!Platform.isWindows) return 'cntlm';
    final dir = File(Platform.resolvedExecutable).parent.path;
    return '$dir\\data\\flutter_assets\\cntlm\\cntlm.exe';
  }

  @override
  Stream<String> get unexpectedExits => _exits.stream;

  /// Removes what a previous run could not clean up after being killed: its
  /// cntlm process and its configuration file, plaintext in older versions.
  Future<void> recover() async {
    await _killOrphan();
    await _deleteIfExists(_configPath);
  }

  @override
  Future<void> start(Profile profile) async {
    if (_process != null) {
      throw const ProxyStartFailure('El proxy ya está en ejecución');
    }
    final port = int.parse(profile.localPort);
    try {
      await _killOrphan();
      await _ensurePortFree(profile.localAddress, port);
      await ensurePrivateDirectory(tempDir);
      final hashes = await _computeHashes(profile);
      await writePrivateFile(_configPath, buildCntlmConfig(profile, hashes));
      await _launch();
      await _waitUntilListening(profile.localAddress, port);
    } on FileSystemException catch (e) {
      await stop();
      throw ProxyStartFailure('No se pudo preparar cntlm: ${e.message}');
    } on ProxyStartFailure {
      await stop();
      rethrow;
    } finally {
      await _deleteIfExists(_configPath);
    }
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _stopping = true;
    process.kill();
    try {
      await _exitCode!.timeout(stopTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await _exitCode;
    }
    _process = null;
    _exitCode = null;
    _stopping = false;
    await _deleteIfExists(_pidPath);
  }

  Future<void> _ensurePortFree(String address, int port) async {
    try {
      final socket = await ServerSocket.bind(address, port);
      await socket.close();
    } on SocketException {
      throw ProxyStartFailure(
          'El puerto $address:$port no está disponible, otro programa lo usa');
    }
  }

  /// The password goes through stdin so it never shows up in the process list.
  Future<CntlmHashes> _computeHashes(Profile profile) async {
    final emptyConfig = '$tempDir${_sep}empty.conf';
    await File(emptyConfig).writeAsString('');
    final Process process;
    try {
      process = await Process.start(executable, [
        '-c',
        emptyConfig,
        '-H',
        '-u',
        profile.username,
        '-d',
        profile.domain,
      ]);
    } on ProcessException {
      throw _notFound();
    }
    process.stdin.writeln(profile.password);
    await process.stdin.close();
    final stderrDone = process.stderr.drain<void>();
    final output = await process.stdout.transform(utf8.decoder).join();
    await stderrDone;
    await process.exitCode;
    await _deleteIfExists(emptyConfig);

    final hashes = CntlmHashes.parse(output);
    if (!hashes.isComplete) {
      throw const ProxyStartFailure(
          'cntlm no pudo calcular los hashes de la contraseña');
    }
    return hashes;
  }

  Future<void> _launch() async {
    final Process process;
    try {
      process = await Process.start(executable, ['-c', _configPath, '-f']);
    } on ProcessException {
      throw _notFound();
    }
    _output.clear();
    _process = process;
    // Reading both pipes also keeps cntlm from blocking when they fill up.
    process.stdout.transform(utf8.decoder).listen(_remember);
    process.stderr.transform(utf8.decoder).listen(_remember);
    await File(_pidPath).writeAsString('${process.pid}');

    _exitCode = process.exitCode;
    unawaited(_exitCode!.then((code) {
      if (_stopping || !identical(_process, process)) return;
      _process = null;
      _exitCode = null;
      unawaited(_deleteIfExists(_pidPath));
      _exits.add(_describeExit(code));
    }));
  }

  void _remember(String chunk) {
    _output.addAll(const LineSplitter().convert(chunk));
    if (_output.length > 20) _output.removeRange(0, _output.length - 20);
  }

  String _describeExit(int code) {
    final detail = _output.isEmpty ? '' : ': ${_output.last}';
    return 'cntlm terminó inesperadamente (código $code)$detail';
  }

  Future<void> _waitUntilListening(String address, int port) async {
    final deadline = DateTime.now().add(startTimeout);
    final process = _process!;
    while (DateTime.now().isBefore(deadline)) {
      if (!identical(_process, process)) {
        throw ProxyStartFailure(_output.isEmpty
            ? 'cntlm terminó al iniciar'
            : 'cntlm terminó al iniciar: ${_output.last}');
      }
      try {
        final socket = await Socket.connect(
          address,
          port,
          timeout: const Duration(milliseconds: 200),
        );
        socket.destroy();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw const ProxyStartFailure('cntlm no empezó a escuchar a tiempo');
  }

  /// Only kills the recorded process if it is really a cntlm started by this
  /// app, the pid could have been reused.
  Future<void> _killOrphan() async {
    if (!Platform.isLinux || _process != null) return;
    final pidFile = File(_pidPath);
    if (!await pidFile.exists()) return;
    final pid = int.tryParse((await pidFile.readAsString()).trim());
    if (pid != null) {
      try {
        final cmdline = await File('/proc/$pid/cmdline').readAsString();
        if (cmdline.contains(_configPath)) {
          Process.killPid(pid);
          await _waitForExit(pid);
        }
      } on FileSystemException {
        // The process is already gone.
      }
    }
    await _deleteIfExists(_pidPath);
  }

  Future<void> _waitForExit(int pid) async {
    final deadline = DateTime.now().add(stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await Directory('/proc/$pid').exists()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    Process.killPid(pid, ProcessSignal.sigkill);
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Nothing to clean up.
    }
  }

  ProxyStartFailure _notFound() => ProxyStartFailure(
      'No se encontró cntlm ($executable). Instálelo o agréguelo al PATH');
}
