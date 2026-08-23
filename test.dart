void main() {
  dynamic data = {"message": "Invalid", "errors": {"phone": ["Required"]}};
  print(data['message'].toString());
}
