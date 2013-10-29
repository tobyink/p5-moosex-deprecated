=pod

=encoding utf-8

=head1 PURPOSE

Test that MooseX::Deprecated works.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=cut

use strict;
use warnings;
use Test::More;
use Test::Moose;
use Test::Warnings qw( warning warnings );
use Test::Fatal;

{
	package FeatherSet;
	use Moose;
	sub ruffle { return 42; }
}

{
	package Goose;
	use Moose;
	has feathers => (
		is        => 'ro',
		isa       => 'FeatherSet',
		default   => sub { 'FeatherSet'->new },
		writer    => '_set_feathers',
		clearer   => '_clear_feathers',
		predicate => 'has_feathers',
		handles   => {
			ruffle_feathers => 'ruffle',
		},
	);
	sub talk { 'honk!' }
	
	with 'MooseX::Deprecated' => {
		attributes => ['feathers'],
		methods    => ['talk'],
	};
}

my $imm = '';

with_immutable
{
	like(
		warning { 'Goose'->new(feathers => 'FeatherSet'->new) },
		qr/\Afeathers is a deprecated argument/,
		"warning when passing deprecated attribute to the constructor$imm",
	);
	
	my $g = 'Goose'->new;
	
	like(
		warning { ok($g->feathers->isa('FeatherSet'), "reader works") },
		qr{\Afeathers is a deprecated reader},
		"warning when using reader$imm",
	);
	
	like(
		warning { ok($g->has_feathers, "predicate works") },
		qr{\Ahas_feathers is a deprecated predicate},
		"warning when using predicate$imm",
	);
	
	like(
		warning { $g->_clear_feathers; no warnings; ok(!$g->has_feathers, "clearer works") },
		qr{\A_clear_feathers is a deprecated clearer},
		"warning when using clearer$imm",
	);
	
	like(
		warning { $g->_set_feathers('FeatherSet'->new); no warnings; ok($g->has_feathers, "writer works") },
		qr{\A_set_feathers is a deprecated writer},
		"warning when using writer$imm",
	);
	
	my @w_ruffle = warnings { is($g->ruffle_feathers, 42, 'delegated method works'); };
	like(
		$w_ruffle[0],
		qr{\Aruffle_feathers is a deprecated method},
		"warning when using deprecated delegated method$imm",
	);
	
	like(
		$w_ruffle[1],
		qr{\Afeathers is a deprecated reader},
		"tag-along warning from reader when using deprecated delegated method$imm",
	);
	
	like(
		warning { is($g->talk, 'honk!', 'method works') },
		qr{\Atalk is a deprecated method},
		"warning from deprecated method$imm",
	);
	
	my @w_stuff = warnings {
		no warnings "deprecated";
		my $g2 = 'Goose'->new;
		$g2->_set_feathers( $g->feathers );
		$g2->talk;
	};
	
	is_deeply(\@w_stuff, [], 'warnings can be disabled');
	
	my $e_construct;
	warning {
		$e_construct = exception {
			use warnings FATAL => "deprecated";
			'Goose'->new(feathers => 'FeatherSet'->new);
		};
	};
	
	{
		local $TODO = $imm ? undef : "cannot figure out warnings categories at real call site for mutable class";
		like($e_construct||'', qr{\Afeathers is a deprecated argument}, 'warning from constructor can be fatalized');
	}
	
	my $e_access = exception {
		use warnings FATAL => "deprecated";
		$g->feathers;
	};
	like($e_access, qr{\Afeathers is a deprecated reader}, 'warning from accessor can be fatalized');
	
	my $e_method = exception {
		use warnings FATAL => "deprecated";
		$g->talk;
	};
	like($e_method, qr{\Atalk is a deprecated method}, 'warning from method can be fatalized');
	
	$imm = " (immutable class)";
} qw( FeatherSet Goose );

done_testing;
