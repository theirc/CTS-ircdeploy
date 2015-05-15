# Make sure server_names_hash_bucket_size is big enough

nginx_server_names_hash_bucket_size:
  file.replace:
    - name: /etc/nginx/nginx.conf
    - pattern: "server_names_hash_bucket_size 64;"
    - repl: "server_names_hash_bucket_size 128;"


# Make sure we compress the usual static files
nginx_gzip_types:
  file.replace:
    - name: /etc/nginx/nginx.conf
    - pattern: "# gzip_types "
    - repl: "gzip_types "
