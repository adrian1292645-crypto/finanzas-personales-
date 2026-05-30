import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deuda.dart';

/// SQL para crear la tabla en Supabase:
/// ```sql
/// CREATE TABLE IF NOT EXISTS deudas (
///   id            BIGSERIAL PRIMARY KEY,
///   nombre        TEXT NOT NULL,
///   monto_total   NUMERIC(12,2) NOT NULL DEFAULT 0,
///   monto_actual  NUMERIC(12,2) NOT NULL DEFAULT 0,
///   tasa_interes  NUMERIC(5,2)  DEFAULT 0,
///   pago_minimo   NUMERIC(12,2) DEFAULT 0,
///   divisa        TEXT          DEFAULT 'MXN',
///   fecha_corte   DATE,
///   icono         TEXT          DEFAULT '💳',
///   created_at    TIMESTAMPTZ   DEFAULT NOW()
/// );
/// ALTER TABLE deudas ENABLE ROW LEVEL SECURITY;
/// CREATE POLICY "Public access" ON deudas FOR ALL USING (true);
/// ```
class DeudaService {
  const DeudaService(this._client);
  final SupabaseClient _client;

  Future<List<Deuda>> fetchAll() async {
    final data = await _client
        .from('deudas')
        .select()
        .order('created_at', ascending: true);
    return (data as List).map((e) => Deuda.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Deuda> create(Deuda deuda) async {
    final data = await _client
        .from('deudas')
        .insert(deuda.toJson())
        .select()
        .single();
    return Deuda.fromJson(data);
  }

  Future<Deuda> update(Deuda deuda) async {
    final data = await _client
        .from('deudas')
        .update(deuda.toJson())
        .eq('id', deuda.id!)
        .select()
        .single();
    return Deuda.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _client.from('deudas').delete().eq('id', id);
  }
}
