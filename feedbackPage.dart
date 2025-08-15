import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'log_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kGoogleScriptWebhookUrl = 'https://script.google.com/macros/s/AKfycbxT_vQDV177nz-hN7JQSjx1umWUWBVZjP67GTi8Eb8W9nS62AUiT86dFBiQy26k3Y7Gwg/exec';

class FeedbackPage extends StatefulWidget {
  final String idCabang; // kirim dari dashboard
  const FeedbackPage({super.key, required this.idCabang});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _pesanCtrl = TextEditingController();
  final _log = LogService();

  String _kategori = 'Bug';
  int? _rating; // 1..5
  bool _sending = false;

  final _kategoriList = const ['Bug', 'Permintaan Fitur', 'UI/UX', 'Lainnya'];

  @override
  void dispose() {
    _judulCtrl.dispose();
    _pesanCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendToGoogleSheets(Map<String, dynamic> data) async {
    if (kGoogleScriptWebhookUrl.isEmpty) return;

    try {
      // JANGAN PASANG headers: {'Content-Type': 'application/json'}
      // Kirim sebagai form-encoded supaya tidak kena CORS preflight di web.
      final res = await http.post(
        Uri.parse(kGoogleScriptWebhookUrl),
        body: {'payload': jsonEncode(data)}, // <-- form field
      );

      // Optional: cek respons
      if (res.statusCode != 200) {
        // ignore: avoid_print
        print('GAS responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('GAS fetch failed: $e');
      rethrow; // biar snackbar kamu tetap muncul kalau mau
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda belum login')),
      );
      return;
    }

    final payload = {
      'user_id'    : user.id,
      'user_email' : user.email,
      'id_cabang'  : widget.idCabang,
      'kategori'   : _kategori,
      'subject'    : _judulCtrl.text.trim(),
      'message'    : _pesanCtrl.text.trim(),
      'rating'     : _rating,
      'app_version': null,
      'device_info': null,
      'created_at' : DateTime.now().toIso8601String(),
    };

    setState(() => _sending = true);
    try {
      await _supabase.from('feedback').insert(payload);     // simpan di Supabase
      await _sendToGoogleSheets(payload);                   // kirim ke Google Sheets

      await _log.addLog(
        aktivitas: "Kirim Feedback",
        halaman: "Feedback",
        detail: "Kategori: $_kategori • Rating: ${_rating ?? '-'}",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih! Feedback terkirim.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengirim: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _ratingRow() {
    return Row(
      children: List.generate(5, (i) {
        final n = i + 1;
        final active = (_rating ?? 0) >= n;
        return IconButton(
          tooltip: '$n',
          onPressed: () => setState(() => _rating = n),
          icon: Icon(
            active ? Icons.star : Icons.star_border,
            size: 28,
            color: active ? Colors.amber[700] : Colors.grey[500],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirim Feedback'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Kategori
                DropdownButtonFormField<String>(
                  value: _kategori,
                  items: _kategoriList
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategori = v ?? 'Bug'),
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Judul
                TextFormField(
                  controller: _judulCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul / Subjek',
                    hintText: 'Contoh: Perhitungan total hasil tidak sesuai',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                // Pesan
                TextFormField(
                  controller: _pesanCtrl,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi / Saran',
                    hintText:
                    'Ceritakan detailnya: langkah reproduksi, harapan Anda, dsb.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().length < 10)
                      ? 'Minimal 10 karakter'
                      : null,
                ),
                const SizedBox(height: 8),
                // Rating (opsional)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rating (opsional)'),
                      _ratingRow(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tombol submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Kirim Feedback'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
