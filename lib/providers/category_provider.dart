import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'service_providers.dart';

final categoryProvider = FutureProvider<List<Category>>(
  (ref) => ref.read(categoryServiceProvider).fetchAll(),
);

final gastosCategoryProvider = FutureProvider<List<Category>>(
  (ref) => ref.read(categoryServiceProvider).fetchByType('gasto'),
);

final ingresosCategoryProvider = FutureProvider<List<Category>>(
  (ref) => ref.read(categoryServiceProvider).fetchByType('ingreso'),
);
