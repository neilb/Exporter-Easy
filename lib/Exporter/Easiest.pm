# $Header: /home/fergal/my/cvs/Exporter-Easy/lib/Exporter/Easiest.pm,v 1.1 2003/02/11 23:55:07 fergal Exp $
# Be lean.
use strict;
no strict 'refs';

package Exporter::Easiest;

require 5.006;

require Exporter::Easy;

sub import
{
	my $pkg = shift;

	my $callpkg = caller(0);

	my @real_spec = parse_spec(@_);

	&Exporter::Easy::set_export_vars($callpkg, @real_spec);
}

sub parse_spec
{
	# maybe we were passed a string or an array of strings, allow both

	my @spec = grep { /\S/ } map { split(/\s+/) } @_;

	my %spec;

	my $key = "";

	while (@spec)
	{
		my $new_key = shift @spec;
		my $arrow = shift @spec;
		die "Expected => not '$arrow' after $new_key" unless ($arrow eq '=>');


		if ($new_key =~ s/^://)
		{
			# if the new key starts with a : then it and the following list are
			# pushed onto the previous keys's entry

			push(@{$spec{$key}}, $new_key, suck_list(\@spec));
		}
		else
		{
			$key = $new_key;
			$spec{$key} = suck_list(\@spec);
		}
	}

	return %spec;
}

sub suck_list
{
	# takes a ref to a list and removes elements from the front of the list
	# until the list is empty or it's 2 shift away from removing a =>

	# returns a ref to a list of the removed list elements

	my $list = shift;

	my @sucked;

	while (@$list)
	{
		if ($#$list and ($list->[1] eq '=>'))
		{
			last;
		}
		else
		{
			push(@sucked, shift(@$list));
		}
	}

	return \@sucked;
}

=head1 NAME

Exporter::Easiest - Takes even more drudgery out of Exporting symbols

=head1 SYNOPSIS

In module YourModule.pm:

  package YourModule;
  use Exporter::Easiest q(
    OK => munge frobnicate
    TAGS =>
    	:tag1 => a b c 
    	:tag2 => :tag1 d e f
    FAIL => f g h
  );

In other files which wish to use YourModule:

  use ModuleName qw(frobnicate);      # import listed symbols
  frobnicate ($left, $right)          # calls YourModule::frobnicate

=head1 DESCRIPTION

The Exporter::Easiest module is a wrapper around Exporter::Easy. It allows
you to pass the arguments into Exporter::Easy without all those tiresome []s
and qw()s. You pass arguments in as a string or an array of strings. You no
longer need to brack things or take references.

The important thing to remember is that tags should be preceded by :
everywhere, including to the left of the =>, otherwise it'll get confused.
Don't worry I haven't done something horribly pythonesque, whitespace is not
significant.

=head1 SEE ALSO

For the real details on exporting symbols see Exporter and Exporter::Easy

=head1 AUTHOR

Written by Fergal Daly <fergal@esatclear.ie>.

=head1 LICENSE

Under the same license as Perl itself

=cut