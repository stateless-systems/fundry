backend backend_nginx {
  .host = "localhost";
  .port = "8080";
}

sub vcl_recv {
  if (req.http.host ~ ".com$" || req.http.host ~ ".local:\d+$" || req.http.host ~ ".local$") {
    set req.backend = backend_nginx;
  }
  else {
    error 404 "Unknown virtual host.";
  }

  if (req.url ~ "^/job") {
    error 404 "The document you are looking for has moved and did not leave a forwarding address.";
  }

  if (req.http.X-Forwarded-For ~ "^[1-9]") {
    set req.http.X-Forwarded-For = req.http.X-Forwarded-For "," client.ip;
  }
  else {
    set req.http.X-Forwarded-For = client.ip;
  }

  # don't trust the outside world.
  if (
    req.http.Pragma ~ "no-cache" || req.http.Cache-Control ~ "no-cache" ||
    req.http.Cache-Control ~ "max-age=0" || req.http.Cache-Control ~ "private"
  ) {
    unset req.http.Pragma;
    unset req.http.Cache-Control;
  }

  # only cache GET and HEAD by default;
  if (req.request != "GET" && req.request != "HEAD") {
    return (pass);
  }

  # never cache some pages.
  if (req.url ~ "^/(login|logout|signin|signup|anonymous|search|__status__|recover|profile|admin)") {
    return (pass);
  }

  # we sometimes don't need to cache non-static content ever.
  if ((req.http.X-Forwarded-Proto ~ "https" || req.http.Cookie ~ "nocache") && !req.url ~ "^.+\.(png|jpg|gif|js|css)$") {
    return(pass);
  }

  return (lookup);
}

sub vcl_fetch {
  # prefer cache-control to set-cookie, some apps set-cookie every request.
  if (beresp.http.Cache-Control ~ "max-age") {
    unset beresp.http.Set-Cookie;
  }

  if (beresp.status != 200 || !beresp.cacheable) {
    return(pass);
  }

  # the default vcl is used from here.
}

sub vcl_deliver {
  unset  resp.http.Server;
  set    resp.http.Server = "Thunderbolt 2010.08.20";
  remove resp.http.X-Varnish;
  remove resp.http.X-Cascade;
  remove resp.http.Via;
  remove resp.http.Age;
}

sub vcl_error {
  set    obj.http.Content-Type = "text/html; charset=utf-8";
  unset  obj.http.Server;
  set    obj.http.Server = "Thunderbolt 2010.08.20";
  remove obj.http.X-Varnish;
  remove obj.http.X-Cascade;
  remove obj.http.Via;
  remove obj.http.Age;

  synthetic {"
  <?xml version="1.0" encoding="utf-8"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
  <html>
    <head>
      <title>"} obj.status {"</title>
    </head>
    <body>
    <h1>Error "} obj.status {"</h1>
    <p>"} obj.response {"</p>
    </body>
   </html>
   "};
  return(deliver);
}
