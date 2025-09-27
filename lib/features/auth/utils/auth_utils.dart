import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/home/view/pages/auth_page.dart';

Future logOut(WidgetRef ref, BuildContext context) async {
  bool? isLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Log out"),
          backgroundColor: Colors.white,
          content: Text("Do you really want to leave?"),
          actions: [
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text("Cancel")),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text("Logout"))
          ],
        );
      });

  if (isLogout == true && context.mounted) {
    ref.read(authLocalRepositoryProvider)
      ..removeToken('access_token')
      ..removeToken('refresh_token');

    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthPage()));
  }
}

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
