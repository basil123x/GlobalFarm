class ShippingAddressModel {
  final int id;
  final String fullname;
  final String mobile;
  final String email;
  final String country;
  final String city;
  final String zoneNumber;
  final String streetNumber;
  final String buildingNumber;
  final String uid;
  final String oid;

  ShippingAddressModel({
    required this.id,
    required this.fullname,
    required this.mobile,
    required this.email,
    required this.country,
    required this.city,
    required this.zoneNumber,
    required this.streetNumber,
    required this.buildingNumber,
    required this.uid,
    required this.oid,
  });

  factory ShippingAddressModel.fromJson(Map<String, dynamic> json) {
    return ShippingAddressModel(
      id: json['id'] ?? 0,
      fullname: json['fullname']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      zoneNumber: json['zone_number']?.toString() ?? '',
      streetNumber: json['street_number']?.toString() ?? '',
      buildingNumber: json['building_number']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      oid: json['oid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullname': fullname,
      'mobile': mobile,
      'email': email,
      'country': country,
      'city': city,
      'zone_number': zoneNumber,
      'street_number': streetNumber,
      'building_number': buildingNumber,
      'uid': uid,
      'oid': oid,
    };
  }

  String get formattedAddress {
    List<String> parts = [];
    
    if (streetNumber.isNotEmpty) {
      parts.add('شارع $streetNumber');
    }
    
    if (buildingNumber.isNotEmpty) {
      parts.add('مبنى $buildingNumber');
    }
    
    if (zoneNumber.isNotEmpty) {
      parts.add('منطقة $zoneNumber');
    }
    
    parts.add(city);
    parts.add(country);
    
    return parts.join(', ');
  }
}
