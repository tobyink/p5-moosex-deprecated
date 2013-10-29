use 5.008003;
use strict;
use warnings;

package MooseX::Deprecated;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Carp;
use MooseX::Role::Parameterized;

our @CARP_NOT = qw(
	Moose::Object
	Moose::Meta::Class
	Class::MOP::Method::Wrapped
);

sub EDEPRECATED () { '%s is a deprecated %s' }
sub ENOOP       () { '%s with no list of attributes or methods' }
sub ENOATTR     () { 'Attribute %s does not exist in %s so cannot be deprecated' }

parameter attributes => (
	is      => 'ro',
	isa     => 'ArrayRef[Str]',
	default => sub { [] },
);

parameter methods => (
	is      => 'ro',
	isa     => 'ArrayRef[Str]',
	default => sub { [] },
);

my %already;
my $deprecated = sub
{
	my $type = shift;
	my $name = shift;
	
	# Don't let the deprecation warning be reported to an
	# inlined constructor; it should be reported to the
	# constructor's caller.
	local $Carp::CarpLevel = $Carp::CarpLevel + 1
		if $type eq 'argument';
	
	croak(sprintf EDEPRECATED, $name, $type)
		if warnings::fatal_enabled("deprecated");
	
	carp(sprintf EDEPRECATED, $name, $type)
		if warnings::enabled("deprecated");
};

role {
	my ($p, %args) = @_;
	
	my @attribs = @{ $p->attributes };
	my @methods = @{ $p->methods };
	my %init_args;
	
	@attribs or @methods or croak(sprintf ENOOP, __PACKAGE__);
	
	my $meta = Moose::Util::find_meta( $args{consumer}->name );
	
	for my $attrib (@attribs)
	{
		my $attr = $meta->find_attribute_by_name($attrib)
			or croak(sprintf ENOATTR, $attrib, $meta->name);
		
		$init_args{ $attr->init_arg } = 1 if $attr->has_init_arg;
		
		for my $method (@{ $attr->associated_methods })
		{
			my $method_name = $method->name;
			my $method_type = $method->can('accessor_type') ? $method->accessor_type : 'method';
			
			before $method_name => sub
			{
				unshift @_, $method_type => $method_name;
				goto $deprecated;
			}
		}
	}
	
	method BUILD => sub { };
	after BUILD => sub
	{
		exists($_[1]{$_}) && $deprecated->(argument => $_, @_)
			for sort keys %init_args;
	};
	
	for my $method (@methods)
	{
		before $method => sub
		{
			unshift @_, method => $method;
			goto $deprecated;
		}
	}
};

1;

__END__

=pod

=encoding utf-8

=for stopwords fatalize fatalizing

=head1 NAME

MooseX::Deprecated - mark attributes and methods as deprecated

=head1 SYNOPSIS

   package Goose
   {
      use Moose;
      
      has feathers => (is => 'ro');
      
      sub honk { say "Honk!" }
      
      with "MooseX::Deprecated" => {
         attributes => [ "feathers" ],
         methods    => [ "honk" ],
      };
   }

=head1 DESCRIPTION

MooseX::Deprecated is a parameterizable role that makes it easy to
deprecate particular attributes and methods in a class.

In the SYNOPSIS above, C<before> method modifiers will be installed on
the C<feathers> accessor and the C<honk> method, issuing a deprecation
warning. Additionally, an C<after> modifier will be installed on the
class' C<BUILD> method which will issue deprecation warnings for any
deprecated attributes passed to the constructor.

The warning text will be something along the lines of:
B<< "%s is a deprecated %s" >>

=begin trustme

=item EDEPRECATED

=end trustme

Warnings are issued in the "deprecated" warnings category, so can be
disabled using:

   no warnings qw( deprecated );

Warnings can be upgraded to fatal errors with:

   use warnings FATAL => qw( deprecated );

When consuming the role you I<must> pass either a list of attributes,
or a list of methods, or both, as parameters to the role. If you forget
to do so, you'll get an error message like:
B<< "%s with no list of attributes or methods" >>.

=begin trustme

=item ENOOP

=end trustme

=head1 CAVEATS

To deprecate an attribute, the attribute must actually exist at the
time you consume this role. In particular, this will not work:

   package Goose
   {
      use Moose;
      
      with "MooseX::Deprecated" => {
         attributes => [ "feathers" ],
      };
      
      has feathers => (is => 'ro');
   }

Because the "feathers" attribute isn't defined until I<after> the role
is consumed. Attempting the above will die with a nasty error message:
B<< "Attribute %s does not exist in %s so cannot be deprecated" >>.

=begin trustme

=item ENOATTR

=end trustme

If a deprecated attribute handles any methods via delegation, then
calling these methods will result in not one, but two warnings. One
warning for calling the delegated method; the other warning for calling
the accessor (reader) to obtain the object to delegate to. This could
theoretically be changed, but I'm comfortable with the existing
situation.

In mutable classes, warnings issued from the constructor will appear
to come from Moose's innards, and not from the constructor's real call
site. This means that disabling them or fatalizing them with
C<< no warnings >> or C<< use warnings FATAL >> will not work.
You should always make classes immutable anyway.

Warnings issued by the accessor (reader) during method delegation will
similarly not be issued from the correct call site, affecting your
ability to disable or fatalize them. Making the class immutable cannot
fix this one I'm afraid.

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=MooseX-Deprecated>.

=head1 SEE ALSO

L<Package::DeprecationManager> provides a more powerful and complicated
set of features. I'm a simple kind of guy, and don't see the need to
allow my caller to pick and choose which deprecations they'd like to
ignore based on some API version.

L<Attribute::Deprecated> is cute, but only deals with methods, and
ironically not (what Moose calls) attributes.

L<Devel::Deprecation> has some pretty nice features, but is more manual
than I'd like, and again only deals with methods.

L<http://en.wikipedia.org/wiki/Self-deprecation>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

