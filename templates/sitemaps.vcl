sub vcl_recv {
  if (req.url ~ "\.xml(\.gz)?$") {
   return (pass);
  }
}
