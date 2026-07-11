/// A single farmer row as shown in the registered-farmers list screen.
///
/// This is the lightweight, list-oriented model backing the paginated roster
/// of farmers who have completed registration. The backend returns each entry
/// as JSON; [fromJson] parses it (defaulting a missing name/number to friendly
/// placeholders) and [toJson] serializes it back. It carries only the summary
/// fields the list needs — the full submission detail lives elsewhere. Pages
/// of these are wrapped by [RegisteredListResponse].
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
