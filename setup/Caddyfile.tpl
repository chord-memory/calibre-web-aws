{
    email ${admin_email}
}
${domain_name} {
  reverse_proxy /api/* flask:5000
  reverse_proxy / calibre-web:8083
}