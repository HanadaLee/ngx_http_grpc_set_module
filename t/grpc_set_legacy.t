#!/usr/bin/perl

# Tests for legacy grpc_set predicates without ngx_condition_module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use Test::Nginx qw/ :DEFAULT /;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http grpc rewrite
	ngx_http_grpc_filter_module ngx_http_grpc_set_module/);

plan(skip_all => 'legacy predicate build required')
	if $t->has_module('ngx_condition_module');

$t->plan(8);

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    server {
        listen       127.0.0.1:8081;
        server_name  backend;

        http2 on;
        default_type application/grpc;
        add_trailer grpc-status 0 always;

        add_header X-Source $arg_source always;

        location / {
            return 200 backend;
        }
    }

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        set $inherited initial;
        grpc_set $inherited parent-$upstream_http_x_source;
        add_header X-Inherited $inherited always;

        location = /predicates {
            set $positive initial;
            set $negative initial;
            grpc_set $positive positive if=$arg_apply;
            grpc_set $positive fallback;
            grpc_set $negative negative if!=$arg_skip;
            grpc_set $negative fallback;
            add_header X-Positive $positive always;
            add_header X-Negative $negative always;
            grpc_pass grpc://127.0.0.1:8081;
        }

        location = /inherit {
            grpc_set $inherited child if=$arg_apply;
            grpc_pass grpc://127.0.0.1:8081;
        }
    }
}

EOF

$t->run()->waitforsocket('127.0.0.1:' . port(8080));

###############################################################################

my $hit = response('/predicates?apply=1&skip=0');
is(header_value($hit, 'X-Positive'), 'positive',
	'if= selects its definition for a truthy value');
is(header_value($hit, 'X-Negative'), 'negative',
	'if!= selects its definition for a false value');

my $miss = response('/predicates?apply=0&skip=1');
is(header_value($miss, 'X-Positive'), 'fallback',
	'if= miss selects the next definition');
is(header_value($miss, 'X-Negative'), 'fallback',
	'if!= miss selects the next definition');

is(header_value(response('/inherit?apply=1&source=origin'), 'X-Inherited'),
	'child', 'matching legacy child definition wins');
is(header_value(response('/inherit?apply=0&source=origin'), 'X-Inherited'),
	'parent-origin',
	'parent definition remains when legacy child condition misses');

my $empty = response('/predicates?apply=&skip=');
is(header_value($empty, 'X-Positive'), 'fallback',
	'if= treats an empty value as false');
is(header_value($empty, 'X-Negative'), 'negative',
	'if!= treats an empty value as false');

###############################################################################

sub header_value {
	my ($response, $name) = @_;
	my ($value) = $response =~ /^\Q$name\E:\s*(.*?)\x0d?$/mi;

	return $value;
}


sub response {
	my ($uri) = @_;

	return http("GET $uri HTTP/1.1\x0d\x0a"
		. "Host: localhost\x0d\x0a"
		. "Connection: close\x0d\x0a\x0d\x0a");
}

###############################################################################
