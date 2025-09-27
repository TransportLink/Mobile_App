class Helpers {
  static bool isPointNearCoordinates(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    double tolerance = 0.005,
  }) {
    print("Comparing ($lat1, $lon1) to ($lat2, $lon2)");
    return (lat1 - lat2).abs() < tolerance && (lon1 - lon2).abs() < tolerance;
  }
}