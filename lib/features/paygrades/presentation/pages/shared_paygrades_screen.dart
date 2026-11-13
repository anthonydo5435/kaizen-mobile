import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/datasources/paygrade_remote_data_source.dart';
import '../../data/repositories/paygrade_repository_impl.dart';
import '../../domain/usecases/get_paygrades_usecase.dart';
import '../providers/paygrade_detail_controller.dart';
import 'shared_paygrades_details_screen.dart';

class SharedPaygradesScreen extends StatelessWidget {
  const SharedPaygradesScreen({
    super.key,
    required this.publicId,
    this.getPaygradesUseCase,
  });

  final String publicId;
  final GetPaygradesUseCase? getPaygradesUseCase;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PaygradeRemoteDataSource>(
          create: (_) => createPaygradeRemoteDataSource(),
        ),
        ProxyProvider<PaygradeRemoteDataSource, PaygradeRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createPaygradeDetailRepository(remoteDataSource),
        ),
        ProxyProvider<PaygradeRepositoryImpl, GetPaygradesUseCase>(
          update: (_, repository, __) =>
              createGetPaygradeDetailUseCase(repository),
        ),
        ChangeNotifierProvider<PaygradeDetailController>(
          create: (context) => PaygradeDetailController(
            getPaygradesUseCase ?? context.read<GetPaygradesUseCase>(),
          )..initializeShared(publicId),
        ),
      ],
      child: Builder(
        builder: (context) => SharedPaygradesDetailsScreen(
          controller: context.read<PaygradeDetailController>(),
        ),
      ),
    );
  }
}
