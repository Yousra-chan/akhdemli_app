import 'package:dzair_data_usage/dzair.dart';
import 'package:dzair_data_usage/wilaya.dart';
import 'package:dzair_data_usage/commune.dart';
import 'package:dzair_data_usage/langs.dart';

class WilayaService {
  static final Dzair _dzair = Dzair();

  // Helper to safely get wilaya name
  static String _getWilayaName(Wilaya wilaya) {
    return wilaya.getWilayaName(Language.FR) ?? 'Unknown';
  }

  // Helper to safely get commune name
  static String _getCommuneName(Commune commune) {
    return commune.getCommuneName(Language.FR) ?? 'Unknown';
  }

  // Get all wilayas
  static List<Wilaya> getAllWilayas() {
    return _dzair.getWilayat()?.whereType<Wilaya>().toList() ?? [];
  }

  // Get all wilaya names (sorted alphabetically)
  static List<String> getAllWilayaNames() {
    final wilayas = getAllWilayas();
    wilayas.sort((a, b) => _getWilayaName(a).compareTo(_getWilayaName(b)));
    return wilayas.map(_getWilayaName).toList();
  }

  // Get communes for a specific wilaya
  static List<String> getCommunesForWilaya(String wilayaName) {
    final wilaya = getAllWilayas().firstWhere(
      (w) => _getWilayaName(w).toLowerCase() == wilayaName.toLowerCase(),
      orElse: () => getAllWilayas().first,
    );

    final communes = wilaya.getCommunes()?.whereType<Commune>().toList() ?? [];
    communes.sort((a, b) => _getCommuneName(a).compareTo(_getCommuneName(b)));
    return communes.map(_getCommuneName).toList();
  }
}
