import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/farmer/farmer_model.dart';
import '../utils/demo_data.dart';

// ─── Reactive local store ────────────────────────────────────────────────────
// Behaves like a BehaviorSubject: new subscribers immediately get the current
// value, then receive every subsequent update.
class _LocalStore {
  List<FarmerModel> _data;
  final StreamController<List<FarmerModel>> _ctrl =
      StreamController<List<FarmerModel>>.broadcast();

  _LocalStore(List<FarmerModel> initial) : _data = List.from(initial);

  Stream<List<FarmerModel>> get stream async* {
    yield List.from(_data);
    yield* _ctrl.stream;
  }

  void _emit() => _ctrl.add(List.from(_data));

  List<FarmerModel> get all => List.from(_data);

  void add(FarmerModel f) {
    _data = [f, ..._data];
    _emit();
  }

  void update(FarmerModel f) {
    _data = _data.map((e) => e.id == f.id ? f : e).toList();
    _emit();
  }

  void remove(String id) {
    _data = _data.where((e) => e.id != id).toList();
    _emit();
  }

  void dispose() => _ctrl.close();
}

// ─── FirestoreService ───────────────────────────────────────────────────────
// Now uses local in-memory store. Will be replaced with API-based CRUD
// when backend endpoints are ready.

class FirestoreService extends ChangeNotifier {
  final _uuid = const Uuid();
  late final _LocalStore _store;

  FirestoreService() {
    _store = _LocalStore(demoFarmers);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<FarmerModel>> getFarmers() => _store.stream;

  Stream<List<FarmerModel>> getFarmersByCategory(String category) {
    return _store.stream
        .map((list) => list.where((f) => f.category == category).toList());
  }

  Stream<List<FarmerModel>> getFarmersByCategoryAndSub(
      String category, String subcategory) {
    return _store.stream.map((list) => list
        .where((f) => f.category == category && f.subcategory == subcategory)
        .toList());
  }

  Stream<int> getTotalCount() => _store.stream.map((l) => l.length);

  Stream<int> getActiveCount() {
    return _store.stream
        .map((l) => l.where((f) => f.status == 'Active').length);
  }

  Stream<List<FarmerModel>> searchFarmers(String query) {
    if (query.isEmpty) return getFarmers();
    final lower = query.toLowerCase();
    return getFarmers().map((list) => list
        .where((f) =>
            (f.name ?? '').toLowerCase().contains(lower) ||
            (f.phone ?? '').contains(query) ||
            f.village.toLowerCase().contains(lower))
        .toList());
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<String> addFarmer(FarmerModel farmer) async {
    final id = _uuid.v4();
    _store.add(farmer.copyWith(id: id));
    notifyListeners();
    return id;
  }

  Future<void> updateFarmer(FarmerModel farmer) async {
    if (farmer.id == null) return;
    _store.update(farmer);
    notifyListeners();
  }

  Future<void> deleteFarmer(String id) async {
    _store.remove(id);
    notifyListeners();
  }

  Future<FarmerModel?> getFarmerById(String id) async {
    try {
      return _store.all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
