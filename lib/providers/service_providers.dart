import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/account_service.dart';
import '../services/category_service.dart';
import '../services/deuda_service.dart';
import '../services/meta_service.dart';
import '../services/transaction_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(ref.read(supabaseClientProvider)),
);

final categoryServiceProvider = Provider<CategoryService>(
  (ref) => CategoryService(ref.read(supabaseClientProvider)),
);

final transactionServiceProvider = Provider<TransactionService>(
  (ref) => TransactionService(ref.read(supabaseClientProvider)),
);

final metaServiceProvider = Provider<MetaService>(
  (ref) => MetaService(ref.read(supabaseClientProvider)),
);

final deudaServiceProvider = Provider<DeudaService>(
  (ref) => DeudaService(ref.read(supabaseClientProvider)),
);
