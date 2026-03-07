import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/farmer_model.dart';
import '../config/env_config.dart';
import '../utils/demo_data.dart';

// ─── Demo reactive store ────────────────────────────────────────────────────
// Behaves like a BehaviorSubject: new subscribers immediately get the current
// value, then receive every subsequent update.
class _DemoStore {
  List<FarmerModel> _data;
  final StreamController<List<FarmerModel>> _ctrl =
      StreamController<List<FarmerModel>>.broadcast();

  _DemoStore(List<FarmerModel> initial) : _data = List.from(initial);

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

class FirestoreService extends ChangeNotifier {
  static const String _col = 'farmers';
  final _uuid = const Uuid();

  // Only instantiate Firebase when not in demo mode
  FirebaseFirestore? get _db =>
      EnvConfig.isDemoMode ? null : FirebaseFirestore.instance;

  late final _DemoStore _demo;

  FirestoreService() {
    if (EnvConfig.isDemoMode) {
      _demo = _DemoStore(demoFarmers);
    }
  }

  @override
  void dispose() {
    if (EnvConfig.isDemoMode) _demo.dispose();
    super.dispose();
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<FarmerModel>> getFarmers() {
    if (EnvConfig.isDemoMode) return _demo.stream;
    return _db!
        .collection(_col)
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => FarmerModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<FarmerModel>> getFarmersByCategory(String category) {
    if (EnvConfig.isDemoMode) {
      return _demo.stream
          .map((list) => list.where((f) => f.category == category).toList());
    }
    return _db!
        .collection(_col)
        .where('category', isEqualTo: category)
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => FarmerModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<FarmerModel>> getFarmersByCategoryAndSub(
      String category, String subcategory) {
    if (EnvConfig.isDemoMode) {
      return _demo.stream.map((list) => list
          .where(
              (f) => f.category == category && f.subcategory == subcategory)
          .toList());
    }
    return _db!
        .collection(_col)
        .where('category', isEqualTo: category)
        .where('subcategory', isEqualTo: subcategory)
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => FarmerModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<int> getTotalCount() {
    if (EnvConfig.isDemoMode) return _demo.stream.map((l) => l.length);
    return _db!
        .collection(_col)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> getActiveCount() {
    if (EnvConfig.isDemoMode) {
      return _demo.stream
          .map((l) => l.where((f) => f.status == 'Active').length);
    }
    return _db!
        .collection(_col)
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<Map<String, int>> getCategoryCounts() {
    if (EnvConfig.isDemoMode) {
      return _demo.stream.map((list) {
        final Map<String, int> counts = {};
        for (final f in list) {
          counts[f.category] = (counts[f.category] ?? 0) + 1;
        }
        return counts;
      });
    }
    return _db!.collection(_col).snapshots().map((snap) {
      final Map<String, int> counts = {};
      for (final doc in snap.docs) {
        final cat = doc.data()['category'] as String? ?? 'Unknown';
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    });
  }

  Stream<List<FarmerModel>> searchFarmers(String query) {
    if (query.isEmpty) return getFarmers();
    final lower = query.toLowerCase();
    return getFarmers().map((list) => list
        .where((f) =>
            f.name.toLowerCase().contains(lower) ||
            f.phone.contains(query) ||
            f.village.toLowerCase().contains(lower))
        .toList());
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<String> addFarmer(FarmerModel farmer) async {
    if (EnvConfig.isDemoMode) {
      final id = _uuid.v4();
      _demo.add(farmer.copyWith(id: id));
      notifyListeners();
      return id;
    }
    final doc = await _db!.collection(_col).add(farmer.toMap());
    notifyListeners();
    return doc.id;
  }

  Future<void> updateFarmer(FarmerModel farmer) async {
    if (farmer.id == null) return;
    if (EnvConfig.isDemoMode) {
      _demo.update(farmer);
      notifyListeners();
      return;
    }
    await _db!.collection(_col).doc(farmer.id).update(farmer.toMap());
    notifyListeners();
  }

  Future<void> deleteFarmer(String id) async {
    if (EnvConfig.isDemoMode) {
      _demo.remove(id);
      notifyListeners();
      return;
    }
    await _db!.collection(_col).doc(id).delete();
    notifyListeners();
  }

  Future<FarmerModel?> getFarmerById(String id) async {
    if (EnvConfig.isDemoMode) {
      try {
        return _demo.all.firstWhere((f) => f.id == id);
      } catch (_) {
        return null;
      }
    }
    final doc = await _db!.collection(_col).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return FarmerModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}
