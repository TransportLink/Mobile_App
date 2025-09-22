class AppFailure {
  final String message;

  AppFailure(
      [this.message =
          "An error unexpectedly occurred. Please try again later."]);

  @override
  String toString() {
    return "ApplicationFailure(message: $message)";
  }
}
