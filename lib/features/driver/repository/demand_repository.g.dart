// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demand_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(DemandRepository)
final demandRepositoryProvider = DemandRepositoryProvider._();

class DemandRepositoryProvider extends Provider<DemandRepository> {
  DemandRepositoryProvider._()
      : super(
          (ref) {
            final dio = ref.watch(dioProvider);
            return DemandRepository(dio);
          },
        );
}
