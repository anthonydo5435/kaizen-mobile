import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';
import '../providers/seat_profile_detail_controller.dart';
import 'seat_profile_detail_screen.dart';

class SharedSeatProfileScreen extends StatelessWidget {
  const SharedSeatProfileScreen({
    super.key,
    required this.publicId,
    this.getSeatProfilesUseCase,
  });

  final String publicId;
  final GetSeatProfilesUseCase? getSeatProfilesUseCase;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SeatProfileRemoteDataSource>(
          create: (_) => SeatProfileRemoteDataSource(),
        ),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createSeatProfileDetailRepository(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) =>
              createGetSeatProfileDetailUseCase(repository),
        ),
        ChangeNotifierProvider<SeatProfileDetailController>(
          create: (context) => SeatProfileDetailController(
            getSeatProfilesUseCase ?? context.read<GetSeatProfilesUseCase>(),
          )..initializeShared(publicId),
        ),
      ],
      child: const SeatProfileDetailView(isShared: true),
    );
  }
}
