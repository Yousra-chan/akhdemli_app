import 'package:flutter/material.dart';
import '../Services/provider_service.dart';
import '../models/ProviderModel.dart';

class ProviderViewModel extends ChangeNotifier {
  final ProviderService _providerService = ProviderService();

  List<ProviderModel> providers = [];
  bool isLoading = false;

  Future<void> fetchProviders() async {
    isLoading = true;
    notifyListeners();

    providers = await _providerService.getAllProviders();

    isLoading = false;
    notifyListeners();
  }

  Future<ProviderModel?> getProviderById(String id) async {
    return await _providerService.getProviderById(id);
  }
}
