function handler(event) {
  var request = event.request;
  var uri = request.uri;

  // React Router owns extensionless paths; static asset paths retain their names.
  if (uri.endsWith('/') || !uri.split('/').pop().includes('.')) {
    request.uri = '/index.html';
  }

  return request;
}
