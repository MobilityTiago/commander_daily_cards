class BulkDataResponse {
  final List<BulkDataItem> data;

  BulkDataResponse({required this.data});

  factory BulkDataResponse.fromJson(Map<String, dynamic> json) {
    return BulkDataResponse(
      data: (json['data'] as List)
          .map((item) => BulkDataItem.fromJson(item))
          .toList(),
    );
  }
}

class BulkDataItem {
  final String type;
  final String downloadUri;

  BulkDataItem({
    required this.type,
    required this.downloadUri,
  });

  factory BulkDataItem.fromJson(Map<String, dynamic> json) {
    return BulkDataItem(
      type: json['type'] ?? '',
      downloadUri: json['download_uri'] ?? '',
    );
  }
}