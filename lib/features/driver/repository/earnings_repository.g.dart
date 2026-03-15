// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(EarningsRepository)
final earningsRepositoryProvider = EarningsRepositoryProvider._();

class EarningsRepositoryProvider extends Provider<EarningsRepository> {
  EarningsRepositoryProvider._()
      : super(
          (ref) {
            final dio = ref.watch(dioProvider);
            return EarningsRepository(dio);
          },
        );
}
