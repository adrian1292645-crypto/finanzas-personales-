import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';

class AccountService {
  const AccountService(this._client);

  final SupabaseClient _client;

  Future<List<Account>> fetchAll() async {
    final data = await _client
        .from('cuentas')
        .select()
        .order('nombre', ascending: true);
    return (data as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<Account> updateBalance(int id, double newBalance) async {
    final data = await _client
        .from('cuentas')
        .update({'saldo_actual': newBalance})
        .eq('id', id)
        .select()
        .single();
    return Account.fromJson(data);
  }

  Future<Account> createAccount({
    required String nombre,
    required String divisa,
    required double saldoActual,
  }) async {
    final data = await _client
        .from('cuentas')
        .insert({'nombre': nombre, 'divisa': divisa, 'saldo_actual': saldoActual})
        .select()
        .single();
    return Account.fromJson(data);
  }

  Future<Account> updateAccount({
    required int id,
    required String nombre,
    required String divisa,
    required double saldoActual,
  }) async {
    final data = await _client
        .from('cuentas')
        .update({'nombre': nombre, 'divisa': divisa, 'saldo_actual': saldoActual})
        .eq('id', id)
        .select()
        .single();
    return Account.fromJson(data);
  }

  Future<void> deleteAccount(int id) async {
    await _client.from('cuentas').delete().eq('id', id);
  }
}
