import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerModel {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final String village;
  final String district;
  final String state;
  final double? latitude;
  final double? longitude;
  final String category;
  final String subcategory;
  final int? subcategoryId;
  final double landArea;
  final String landUnit;
  final List<Map<String, double>> landCoordinates;
  final Map<String, String> dynamicFields; // category-specific answers
  final DateTime registrationDate;
  final String? photoUrl;
  final String status;
  final String? registeredBy;

  FarmerModel({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.village = '',
    this.district = '',
    this.state = '',
    this.latitude,
    this.longitude,
    required this.category,
    required this.subcategory,
    this.subcategoryId,
    required this.landArea,
    this.landUnit = 'Acres',
    this.landCoordinates = const [],
    this.dynamicFields = const {},
    DateTime? registrationDate,
    this.photoUrl,
    this.status = 'Active',
    this.registeredBy,
  }) : registrationDate = registrationDate ?? DateTime.now();

  factory FarmerModel.fromMap(Map<String, dynamic> map, String id) {
    List<Map<String, double>> coords = [];
    if (map['landCoordinates'] != null) {
      coords = (map['landCoordinates'] as List<dynamic>)
          .map((e) => Map<String, double>.from(
              (e as Map).map((k, v) =>
                  MapEntry(k.toString(), (v as num).toDouble()))))
          .toList();
    }

    Map<String, String> dynFields = {};
    if (map['dynamicFields'] != null) {
      dynFields = Map<String, String>.from(
          (map['dynamicFields'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString())));
    }

    return FarmerModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      village: map['village'] ?? '',
      district: map['district'] ?? '',
      state: map['state'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      subcategoryId: map['subcategoryId'] as int?,
      landArea: (map['landArea'] ?? 0.0).toDouble(),
      landUnit: map['landUnit'] ?? 'Acres',
      landCoordinates: coords,
      dynamicFields: dynFields,
      registrationDate:
          (map['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: map['photoUrl'],
      status: map['status'] ?? 'Active',
      registeredBy: map['registeredBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'village': village,
      'district': district,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'subcategory': subcategory,
      'subcategoryId': subcategoryId,
      'landArea': landArea,
      'landUnit': landUnit,
      'landCoordinates': landCoordinates,
      'dynamicFields': dynamicFields,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'photoUrl': photoUrl,
      'status': status,
      'registeredBy': registeredBy,
    };
  }

  FarmerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? village,
    String? district,
    String? state,
    double? latitude,
    double? longitude,
    String? category,
    String? subcategory,
    int? subcategoryId,
    double? landArea,
    String? landUnit,
    List<Map<String, double>>? landCoordinates,
    Map<String, String>? dynamicFields,
    DateTime? registrationDate,
    String? photoUrl,
    String? status,
    String? registeredBy,
  }) {
    return FarmerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      landArea: landArea ?? this.landArea,
      landUnit: landUnit ?? this.landUnit,
      landCoordinates: landCoordinates ?? this.landCoordinates,
      dynamicFields: dynamicFields ?? this.dynamicFields,
      registrationDate: registrationDate ?? this.registrationDate,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      registeredBy: registeredBy ?? this.registeredBy,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'F';
  }
}
