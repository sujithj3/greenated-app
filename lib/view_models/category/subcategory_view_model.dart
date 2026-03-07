import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../models/farmer/farmer_model.dart';

class SubcategoryViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final FormConfigService _formConfigService;

  SubcategoryViewModel(this._firestoreService, this._formConfigService);

  List<String> getSubcategoryNames(String category) =>
      _formConfigService.getSubcategoryNames(category);

  Stream<List<FarmerModel>> getFarmersByCategoryAndSub(
          String category, String subcategory) =>
      _firestoreService.getFarmersByCategoryAndSub(category, subcategory);
}
