class RegisteredFarmer {
  final int submissionId;
  final String fullName;
  final String mobileNumber;
  final String formName;

  RegisteredFarmer({
    required this.submissionId,
    required this.fullName,
    required this.mobileNumber,
    required this.formName,
  });

  factory RegisteredFarmer.fromJson(Map<String, dynamic> json) {
    return RegisteredFarmer(
      submissionId: json['submissionId'] as int,
      fullName: json['fullName'] as String? ?? 'Unknown',
      mobileNumber: json['mobileNumber'] as String? ?? 'N/A',
      formName: json['formName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'submissionId': submissionId,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'formName': formName,
    };
  }
}
