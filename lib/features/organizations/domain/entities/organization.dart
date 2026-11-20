class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.website,
    required this.contactNo,
    required this.address,
    required this.createdAt,
    required this.type,
    required this.logoUrl,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    id: json['uuid']?.toString().trim() ?? '',
    name: json['name']?.toString().trim() ?? '',
    website: _nullableString(json['website']),
    contactNo: _nullableString(json['contact_no']),
    address: _nullableString(json['address']),
    createdAt: json['created_at']?.toString().trim() ?? '',
    type: json['type']?.toString().trim() ?? '',
    logoUrl: _nullableString(json['logo_url']),
  );

  final String id;
  final String name;
  final String? website;
  final String? contactNo;
  final String? address;
  final String createdAt;
  final String type;
  final String? logoUrl;

  Map<String, dynamic> toJson() => {
    'uuid': id,
    'name': name,
    'website': website,
    'contact_no': contactNo,
    'address': address,
    'created_at': createdAt,
    'type': type,
    'logo_url': logoUrl,
  };

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text == 'null' ? null : text;
  }
}
