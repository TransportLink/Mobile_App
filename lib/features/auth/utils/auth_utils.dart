  String extractErrorMessage(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      if (data["message"] != null) return data["message"].toString();
      if (data["error"] != null) return data["error"].toString();
      if (data["errors"] is Map) {
        return (data["errors"] as Map)
            .values
            .expand((e) => e is List ? e : [e])
            .join(", ");
      }
    } else if (data is List && data.isNotEmpty) {
      return data.join(", ");
    } else if (data is String && data.isNotEmpty) {
      return data;
    }

    switch (statusCode) {
      case 400:
        return "Bad request. Please check your input.";
      case 401:
        return "Unauthorized. Please log in again.";
      case 403:
        return "Forbidden. You don’t have permission.";
      case 404:
        return "Not found. Please try again.";
      case 500:
        return "Server error. Please try later.";
      default:
        return "An unknown error occurred (code $statusCode).";
    }
  }