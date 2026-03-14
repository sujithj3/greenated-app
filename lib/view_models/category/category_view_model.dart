import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';

class CategoryViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;

  CategoryViewModel(this._firestoreService);

  Stream<Map<String, int>> get categoryCounts =>
      _firestoreService.getCategoryCounts();
}
