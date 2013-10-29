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

sub w_qr {
	my $str = quotemeta($_[0]);
	
	$str .= sprintf(" at 01basic\.t line (%d|%d|%d)", $_[1]-1 .. $_[1]+1 )  # allow off-by-one
		if defined($_[1]);
	
	return qr/$str/;
}

#line 70 "01basic.t"
with_immutable
{
	like(
		warning { 'Goose'->new(feathers => 'FeatherSet'->new) },
		w_qr('feathers is a deprecated argument', 73),
		"warning when passing deprecated attribute to the constructor$imm",
	);
	
	my $g = 'Goose'->new;
	
	like(
		warning { ok($g->feathers->isa('FeatherSet'), "reader works$imm") },
		w_qr('feathers is a deprecated reader', 81),
		"warning when using reader$imm",
	);
	
	like(
		warning { ok($g->has_feathers, "predicate works$imm") },
		w_qr('has_feathers is a deprecated predicate', 87),
		"warning when using predicate$imm",
	);
	
	like(
		warning { $g->_clear_feathers; no warnings; ok(!$g->has_feathers, "clearer works$imm") },
		w_qr('_clear_feathers is a deprecated clearer', 93),
		"warning when using clearer$imm",
	);
	
	like(
		warning { $g->_set_feathers('FeatherSet'->new); no warnings; ok($g->has_feathers, "writer works$imm") },
		w_qr('_set_feathers is a deprecated writer', 99),
		"warning when using writer$imm",
	);
	
	my @w_ruffle = warnings { is($g->ruffle_feathers, 42, "delegated method works$imm"); };
	like(
		$w_ruffle[0],
		w_qr('ruffle_feathers is a deprecated method', 104),
		"warning when using deprecated delegated method$imm",
	);
	
	like(
		$w_ruffle[1],
		w_qr('feathers is a deprecated reader', 104),
		"tag-along warning from reader when using deprecated delegated method$imm",
	);
	
	like(
		warning { is($g->talk, 'honk!', "method works$imm") },
		w_qr('talk is a deprecated method', 118),
		"warning from deprecated method$imm",
	);
	
	my @w_stuff = warnings {
		no warnings "deprecated";
		my $g2 = 'Goose'->new;
		$g2->_set_feathers( $g->feathers );
		$g2->talk;
	};
	
	is_deeply(\@w_stuff, [], "warnings can be disabled$imm");
	
	my $e_construct;
	warning {
		$e_construct = exception {
			use warnings FATAL => "deprecated";
			'Goose'->new(feathers => 'FeatherSet'->new);
		};
	};
	like($e_construct||'', w_qr('feathers is a deprecated argument', 136), "warning from constructor can be fatalized$imm");
	
	my $e_access = exception {
		use warnings FATAL => "deprecated";
		$g->feathers;
	};
	like($e_access, w_qr('feathers is a deprecated reader', 143), "warning from accessor can be fatalized$imm");
	
	my $e_method = exception {
		use warnings FATAL => "deprecated";
		$g->talk;
	};
	like($e_method, w_qr('talk is a deprecated method', 149), "warning from method can be fatalized$imm");
	
	$imm = " (immutable class)";
} qw( FeatherSet Goose );

done_testing;
