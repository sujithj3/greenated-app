class FarmerModel {
  final String? id;
  final String? name; // Can be null if form doesn't request it
  final String? phone; // Can be null if form doesn't request it
  final String address;
  final String village;
  final String district;
  final String state;
  final String category;
  final String subcategory;
  final int? subcategoryId;
  final double landArea;
  final String landUnit;
  final List<Map<String, double>> landCoordinates;
  final Map<String, dynamic> dynamicFields; // category-specific answers
  final List<dynamic> formFields; // The structured list of fields
  final DateTime registrationDate;
  final String? photoUrl;
  final String status;
  final int? userId; // Replaced registeredBy

  FarmerModel({
    this.id,
    this.name,
    this.phone,
    required this.address,
    this.village = '',
    this.district = '',
    this.state = '',
    required this.category,
    required this.subcategory,
    this.subcategoryId,
    required this.landArea,
    this.landUnit = 'Acres',
    this.landCoordinates = const [],
    this.dynamicFields = const {},
    this.formFields = const [],
    DateTime? registrationDate,
    this.photoUrl,
    this.status = 'Active',
    this.userId, // Replaced registeredBy
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

    Map<String, dynamic> dynFields = {};
    if (map['dynamicFields'] != null) {
      if (map['dynamicFields'] is Map) {
         dynFields = Map<String, dynamic>.from(map['dynamicFields'] as Map);
      }
    }

    List<dynamic> fFields = [];
    if (map['formFields'] != null) {
      fFields = List<dynamic>.from(map['formFields']);
    } else if (map['registrationData']?['fields'] != null) {
      fFields = List<dynamic>.from(map['registrationData']['fields']);
    } else if (map['dynamicFields'] is List) {
      fFields = List<dynamic>.from(map['dynamicFields']);
    }

    return FarmerModel(
      id: id,
      name: map['name'],
      phone: map['phone'],
      address: map['address'] ?? '',
      village: map['village'] ?? '',
      district: map['district'] ?? '',
      state: map['state'] ?? '',
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      subcategoryId: map['subcategoryId'] as int?,
      landArea: (map['landArea'] ?? 0.0).toDouble(),
      landUnit: map['landUnit'] ?? 'Acres',
      landCoordinates: coords,
      dynamicFields: dynFields,
      formFields: fFields,
      registrationDate: map['registrationDate'] != null
          ? DateTime.tryParse(map['registrationDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      photoUrl: map['photoUrl'],
      status: map['status'] ?? 'Active',
      userId: map['userId'] is int
          ? map['userId'] as int
          : int.tryParse(map['userId']?.toString() ?? ''),
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
      'subcategoryId': subcategoryId,
      'landArea': landArea,
      'landUnit': landUnit,
      'landCoordinates': landCoordinates,
      'dynamicFields': dynamicFields,
      'formFields': formFields,
      'registrationDate': registrationDate.toIso8601String(),
      'status': status,
      'userId': userId,
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
    String? category,
    String? subcategory,
    int? subcategoryId,
    double? landArea,
    String? landUnit,
    List<Map<String, double>>? landCoordinates,
    Map<String, dynamic>? dynamicFields,
    List<dynamic>? formFields,
    DateTime? registrationDate,
    String? photoUrl,
    String? status,
    int? userId,
  }) {
    return FarmerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      landArea: landArea ?? this.landArea,
      landUnit: landUnit ?? this.landUnit,
      landCoordinates: landCoordinates ?? this.landCoordinates,
      dynamicFields: dynamicFields ?? this.dynamicFields,
      formFields: formFields ?? this.formFields,
      registrationDate: registrationDate ?? this.registrationDate,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      userId: userId ?? this.userId,
    );
  }

  String get initials {
    final safeName = name?.trim() ?? '';
    if (safeName.isEmpty) return 'F';
    
    final parts = safeName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return safeName[0].toUpperCase();
  }
}
