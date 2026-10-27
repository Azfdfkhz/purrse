import 'package:flutter/material.dart';
import '../../utils/formatters.dart';
import '../../services/proof_upload_service.dart';
import '../../services/storage_service.dart';

import '../../services/backup_service.dart';
import '../../services/auto_backup_service.dart';
import '../../services/google_drive_service.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() =>
      _BackupRestorePageState();
}

class _BackupRestorePageState
    extends State<BackupRestorePage> {
  bool _loading = false;
  bool _connected = false;
  DateTime? _lastBackup;
  DateTime? _safetyAt;
  bool _auto = false;

  Future<void> _refreshStatus() async {
    final last = await BackupService.instance.lastBackupAt();
    final safety = await BackupService.instance.safetyBackupAt();
    if (!mounted) return;
    setState(() {
      _lastBackup = last;
      _safetyAt = safety;
    });
  }

  String _fmtDateTime(DateTime d) =>
      '${Formatters.date(d)}, ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    AutoBackupService.instance.isEnabled().then((v) {
      if (mounted) setState(() => _auto = v);
    });

    // Status "terhubung" dibaca dari penyimpanan (bukan dari sesi yang baru
    // dibuka), sehingga tidak meminta login ulang setiap aplikasi dibuka.
    _connected = GoogleDriveService.instance.isLinked ||
        GoogleDriveService.instance.isSignedIn;

    // Sambungkan ulang sesi di latar. Gagal (mis. offline) TIDAK memutus status.
    GoogleDriveService.instance.restoreSession().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _loading = true);

    try {
      final account =
      await GoogleDriveService.instance.signIn();

      if (!mounted) return;

      if (account != null) {
        setState(() {
          _connected = true;
        });
        final user = await StorageService.instance.getCurrentUser();
        if (user != null) {
          ProofUploadService.instance.processPending(user.id);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terhubung sebagai ${account.email}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghubungkan Google Drive: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _backup() async {
    setState(() => _loading = true);

    try {
      await GoogleDriveService.instance.ensureConnected();

      await BackupService.instance
          .backupToGoogleDrive();

      await _refreshStatus();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup berhasil disimpan ke Google Drive.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup gagal: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    BackupPreview? preview;
    try {
      preview = await BackupService.instance.previewGoogleDriveBackup();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    final p = preview!;
    final when = p.createdAt == null ? 'tidak diketahui' : _fmtDateTime(p.createdAt!);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pulihkan dari backup?'),
        content: Text(
          'Backup ditemukan:\n'
          '• Dibuat: $when\n'
          '• ${p.transactionCount} transaksi\n'
          '• ${p.categoryCount} kategori\n\n'
          'Data di perangkat ini akan diganti dengan isi backup. '
          'Salinan data saat ini disimpan otomatis dulu, sehingga kamu bisa '
          'membatalkan restore dari halaman ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await BackupService.instance.restoreWithSafety(p);
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data dipulihkan: ${p.transactionCount} transaksi, ${p.categoryCount} kategori.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore gagal, data semula dikembalikan: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _undoRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Batalkan restore terakhir?'),
        content: Text(
          'Data akan dikembalikan ke kondisi sebelum restore'
          '${_safetyAt == null ? '' : ' (${_fmtDateTime(_safetyAt!)})'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Kembalikan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await BackupService.instance.undoLastRestore();
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data dikembalikan ke kondisi sebelum restore.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan restore: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    await GoogleDriveService.instance.signOut();

    if (!mounted) return;

    setState(() {
      _connected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Backup & Restore'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(20),
            children: [
              // Google Drive
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                            primary.withOpacity(.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_outlined,
                            color: primary,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Drive',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Google Drive digunakan sebagai tempat backup data.',
                                style: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    if (!_connected)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading
                              ? null
                              : _connectGoogleDrive,
                          icon: Icon(
                            Icons.login,
                          ),
                          label: Text(
                            'Hubungkan Google Drive',
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding:
                            EdgeInsets.all(14),
                            decoration:
                            BoxDecoration(
                              color: Colors.green
                                  .withOpacity(.10),
                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    GoogleDriveService.instance.linkedEmail != null
                                        ? 'Terhubung: ${GoogleDriveService.instance.linkedEmail}'
                                        : 'Google Drive terhubung',
                                    style: TextStyle(
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : _disconnect,
                              child: Text(
                                'Putuskan Google Drive',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Backup
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Backup Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Simpan transaksi, kategori, dan pengaturan aplikasi ke Google Drive.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(.7),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _lastBackup == null
                          ? 'Backup terakhir: belum ada dari perangkat ini. '
                            'Terhubung ke Drive belum berarti data sudah dibackup.'
                          : 'Backup terakhir berhasil: ${_fmtDateTime(_lastBackup!)}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _auto,
                      title: Text('Backup otomatis', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Backup ke Drive setelah ada perubahan data, dengan jeda singkat dan coba ulang bila gagal.'),
                      onChanged: (v) async {
                        setState(() => _auto = v);
                        await AutoBackupService.instance.setEnabled(v);
                      },
                    ),
                    if (_auto)
                      AnimatedBuilder(
                        animation: AutoBackupService.instance,
                        builder: (context, _) {
                          final st = AutoBackupService.instance.state;
                          final text = switch (st) {
                            AutoBackupState.idle => 'Tidak ada perubahan yang menunggu backup.',
                            AutoBackupState.waiting => 'Menunggu backup otomatis...',
                            AutoBackupState.running => 'Sedang membackup...',
                            AutoBackupState.needsDrive => 'Hubungkan Google Drive agar backup otomatis berjalan.',
                            AutoBackupState.failed => 'Backup otomatis gagal; akan dicoba lagi.',
                          };
                          return Row(
                            children: [
                              Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                              if (st == AutoBackupState.failed || st == AutoBackupState.needsDrive)
                                TextButton(
                                  onPressed: () => AutoBackupService.instance.retryNow(),
                                  child: Text('Coba lagi'),
                                ),
                            ],
                          );
                        },
                      ),
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                        _loading ? null : _backup,
                        icon: Icon(
                          Icons.backup,
                        ),
                        label: Text(
                          'Backup Sekarang',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Restore
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Restore Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Pilih ini di perangkat baru atau setelah instal ulang. Akun Google yang sama hanya membantu menemukan backup; data kembali setelah kamu menjalankan restore.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(.7),
                      ),
                    ),
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                        _loading ? null : _restore,
                        icon: Icon(
                          Icons.restore,
                        ),
                        label: Text(
                          'Pulihkan dari Backup',
                        ),
                      ),
                    ),
                    if (_safetyAt != null) ...[
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _loading ? null : _undoRestore,
                          icon: Icon(Icons.undo_rounded),
                          label: Text('Batalkan restore terakhir'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 30),

              Text(
                'Data utama tetap tersimpan di perangkat. Google Drive hanya digunakan sebagai backup.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(.6),
                ),
              ),
            ],
          ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(.25),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}