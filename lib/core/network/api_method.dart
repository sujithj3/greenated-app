/// Supported HTTP methods for API requests.
enum ApiMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const ApiMethod(this.value);

  final String value;
}
