class RegisteredFarmersList {
  final int farmerId;
  final String? farmerCode;
  final String fullName;
  final String mobileNumber;
  final String formName;

  RegisteredFarmersList({
    required this.farmerId,
    this.farmerCode,
    required this.fullName,
    required this.mobileNumber,
    required this.formName,
  });

  factory RegisteredFarmersList.fromJson(Map<String, dynamic> json) {
    return RegisteredFarmersList(
      farmerId: json['farmerId'] as int,
      farmerCode: json['farmerCode'] as String?,
      fullName: json['fullName'] as String? ?? 'Unknown',
      mobileNumber: json['mobileNumber'] as String? ?? 'N/A',
      formName: json['formName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'farmerCode': farmerCode,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'formName': formName,
    };
  }
}
