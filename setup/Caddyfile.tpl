{
    email ${admin_email}
}
${domain_name} {
  handle_path /api/* {
    reverse_proxy flask:5000
  }

  handle {
    reverse_proxy calibre-web:8083
  }
}