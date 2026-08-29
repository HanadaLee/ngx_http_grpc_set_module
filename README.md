# Name

`ngx_http_grpc_set_module` allows setting variables during the gRPC response header phase.

# Table of Content

- [Name](#name)
- [Table of Content](#table-of-content)
- [Status](#status)
- [Synopsis](#synopsis)
- [Installation](#installation)
- [Conditional syntax](#conditional-syntax)
- [Directives](#directives)
  - [grpc\_set](#grpc_set)
- [Author](#author)
- [License](#license)

# Status

This Nginx module is currently considered experimental. Issues and PRs are welcome if you encounter any problems.

# Synopsis

```nginx
server {
    listen 127.0.0.1:80;
    server_name localhost;

    location / {
        set $source "";
        condition has_source is_not_empty $upstream_http_custom_header1;
        when has_source {
            grpc_set $source $upstream_http_custom_header1;
        }
        add_header X-Upstream-Source $source always;
        grpc_pass grpc://example.upstream.com;
    }
}
```

# Installation

This module depends on `ngx_http_grpc_filter_module`; add the grpc filter module first:

```sh
./configure --add-module=/path/to/ngx_http_grpc_filter_module \
            --add-module=/path/to/ngx_http_grpc_set_module
```

To enable named conditions, add `ngx_condition_module` statically in the same nginx configuration.

# Conditional syntax

Conditional syntax is selected at compile time. With `ngx_condition_module`, place `grpc_set` inside an `http`, `server`, or `location` `when` block; `if=` and `if!=` are rejected. Without it, `when` is unavailable and legacy `if=`/`if!=` remain supported.

Definitions are evaluated in configuration order. The first unconditional definition or definition with a matching condition wins for each variable. A definition whose condition does not match is skipped so the next definition of the same variable can be evaluated. A conditional definition at a child configuration level retains an inherited definition as its fallback.

# Directives

## grpc_set

**Syntax:** *grpc_set $variable value;*

**Default:** *-*

**Context:** *http, server, location, http when, server when, location when*

Sets the request variable to the given value during the gRPC response header phase. The value may contain variables from request or response, such as `$upstream_http_*`.
These directives are inherited from the previous configuration level only when there is no directive for the same variable defined at the current level.

# Author

Hanada im@hanada.info

# License

This Nginx module is licensed under [BSD 2-Clause License](LICENSE).
