# $Header: /home/fergal/my/cvs/Exporter-Easy/lib/Exporter/Easy.pm,v 1.3 2003/02/11 23:54:39 fergal Exp $
# Be lean.
use strict;
no strict 'refs';

package Exporter::Easy;

require 5.006;

require Exporter;

our $VERSION = '0.1';

sub import
{
	my $pkg = shift;

	my $callpkg = caller(0);

	return set_export_vars($callpkg, @_);
}

sub set_export_vars
{
	# this handles setting up all of the EXPORT variables in the callers
	# package. It gives a nice way of creating tags, allows you to use tags
	# when defining @EXPORT, @EXPORT_FAIL and other in tags. It also takes
	# care of @EXPORT_OK.
	
	my $callpkg = shift;
	my %args = @_;

	push(@{"$callpkg\::ISA"}, "Exporter");

	my @ok; # this will be a list of all the symbols mentioned
	my @export; # this will be a list symbols to be exported by default
	my @fail; # this will be a list symbols that should not be exported
	my %tags; # will contain a ref hash of all tags

	if (my $tag_data = delete $args{'TAGS'})
	{
		die "TAGS must be a reference to an array" unless ref($tag_data) eq 'ARRAY';

		add_tags($tag_data, \%tags);

		push(@ok, map {@$_} values %tags);
	}

	if (my $export = delete $args{'EXPORT'})
	{
		die "EXPORT must be a reference to an array"
			unless ref($export) eq 'ARRAY';

		@export = eval { expand_tags($export, \%tags) };
		die "$@while building the EXPORT list in $callpkg" if $@;

		push(@ok, @export);
	}

	if (my $fail = delete $args{'FAIL'})
	{
		die "FAIL must be a reference to an array" unless ref($fail) eq 'ARRAY';

		@fail = eval { expand_tags($fail, \%tags) };
		die "$@while building the FAIL list in $callpkg" if $@;
	}

	if (my $ok = delete $args{'OK'})
	{
		die "OK must be a reference to a array" unless ref($ok) eq 'ARRAY';

		push(@ok, @$ok);
	}

	# uniquify the OK symbols and take out any fails
	@ok = do
	{
		my %o;
		@{o}{@ok} = ();
		delete @o{@fail};
		keys %o
	};

	if (my $all = delete $args{'ALL'})
	{
		die "No name supplied for ALL" unless length($all);

		die "Cannot use '$all' for ALL, already exists" if exists $tags{$all};
		my @all = (@ok, @export);
		# uniquify 
		@all = do { my %o; @{o}{@all} = (); keys %o };

		$tags{$all} = \@all;
	}

	if (%args)
	{
		die "Attempt to use unknown keys: ", join(", ", keys %args);
	}

	@{"$callpkg\::EXPORT"} = @export;
	%{"$callpkg\::EXPORT_TAGS"} = %tags;
	@{"$callpkg\::EXPORT_OK"} = @ok;
	@{"$callpkg\::EXPORT_FAIL"} = @fail;
}

sub add_tags($;$)
{
	# this takes a reference to tag data and an optional reference to a hash
	# of already exiting tags. If no hash ref is supplied then it creates an
	# empty one
	
	# It adds the tags from the tag data to the hash ref.

	my $tag_data = shift;
	my $tags = shift || {};

	my @tag_data = @$tag_data;
	while (@tag_data)
	{
		my $tag_name = shift @tag_data || die "No name for tag";
		die "Tag name cannot be a reference, maybe you left out a comma"
			if (ref $tag_name);

		die "Tried to redefine tag '$tag_name'"
			if (exists $tags->{$tag_name});

		my $tag_list = shift @tag_data || die "No values for tag '$tag_name'";

		die "Tag values for '$tag_name' is not a reference to an array"
			unless ref($tag_list) eq 'ARRAY';

		my @symbols = eval { expand_tags($tag_list, $tags) };

		die "$@while building tag '$tag_name'" if $@;

		$tags->{$tag_name} = \@symbols;
	}

	return $tags;
}

sub expand_tags($$)
{
	# this takes a list of strings. Each string can be a symbol, or a tag and
	# each may start with a ! to signify deletion.
	
	# We return a list of symbols where all the tag have been expanded and
	# some symbols may have been deleted

	# we die if we hit an unknown tag

	my ($string_list, $so_far) = @_;

	my %this_tag;

	foreach my $sym (@$string_list)
	{
		my @symbols; # list of symbols to add or delete
		my $remove = 0;

		if ($sym =~ s/^!//)
		{
			$remove = 1;
		}

		if ($sym =~ s/://)
		{
			my $sub_tag = $so_far->{$sym};
			die "Tried to use an unknown tag '$sym'" unless defined($sub_tag);

			@symbols = @{$sub_tag};
		}
		else
		{
			@symbols = ($sym);
		}

		if ($remove)
		{
			delete @this_tag{@symbols};
		}
		else
		{
			@this_tag{@symbols} = ();
		}
	}

	return keys %this_tag;
}

1;
__END__

=head1 NAME

Exporter::Easy - Takes the drudgery out of Exporting symbols

=head1 SYNOPSIS

In module YourModule.pm:

  package YourModule;
  use Exporter::Easy (
    OK => [ 'munge', 'frobnicate' ] # symbols to export on request
  );

In other files which wish to use YourModule:

  use ModuleName qw(frobnicate);      # import listed symbols
  frobnicate ($left, $right)          # calls YourModule::frobnicate

=head1 DESCRIPTION

The Exporter::Easy module is a wrapper around Exporter. In it's simplest
case it allows you to drop the boilerplate code that comes with using
Exporter, so

  require Exporter;
  use base qw( Exporter );
  use vars qw( @EXPORT );
  @EXPORT = ( 'init' );

becomes

  use Exporter::Easy ( EXPORT => [ 'init' ] );

and more complicated situations where you use tags to build lists and more
tags become easy, like this

  use Exporter (
  	EXPORT => [qw( init :base )],
  	TAGS => [
  		base => [qw( open close )],
  		read => [qw( read sysread readline )],
  		write => [qw( print write writeline )],
  		misc => [qw( select flush )],
  		all => [qw( :base :read :write :misc)],
  		no_misc => [qw( :all !:misc )],
  	],
  	OK => [qw( some other stuff )],
  );

All it does is set up C<@EXPORT>, C<@EXPORT_OK>, C<@EXPORT_FAIL> and
C<%EXPORT_TAGS> in the current package and add Exporter to that packages
C<@ISA>. The rest is handled as normal by Exporter.

=head1 HOW TO USE IT

Put

	use Exporter::Easy ( KEY => value, ...);

In your package. Arguments are passes as key-value pairs, the following keys
are available

=over 4

=item EXPORT

The value should be a reference to a list of symbol names and tags. Any tags
will be expanded and the resulting list of symbol names will be placed in
the C<@EXPORT> array in your package.

=item FAIL

The value should be a reference to a list of symbol names and tags. The tags
will be expanded and the resulting list of symbol names will be placed in
the C<@EXPORT_FAIL> array in your package. They will also be removed from
the C<@EXPORT_OK> list.

=item TAGS

The value should be a reference to a list that goes like (TAG_NAME,
TAG_VALUE, TAG_NAME, TAG_VALUE, ...), where TAG_NAME is a string and
TAG_VALUE is a reference to an array of symbols and tags. For example

  TAGS => [
    file => [ 'open', 'close', 'read', 'write'],
    string => [ 'length', 'substr', 'chomp' ],
    hash => [ 'keys', 'values', 'each' ],
    all => [ ':file', ':string', ':hash' ],
    some => [':all', '!open', ':hash'],
  ]

This is used to fill the C<%EXPORT_TAGS> in your package. You can build tags
from other tags - in the example above the tag C<all> will contain all the
symbols from C<file>, C<string> and C<hash>. You can also subtract symbols
and tags - in the example above, C<some> contains the symbols from all but
with C<open> removed and all the symbols from C<hash> removed.

The rule is that any symbol starting with a ':' is taken to be a tag which
has been defined previously (if it's not defined you'll get an error). If a
symbol is preceded by a '!' it will be subtracted from the list, otherwise
it is added.

If you try to redefine a tag you will also get an error.

All the symbols which occur while building the tags are automatically added
your package's C<@EXPORT_OK> array.

=item OK

The value should be a reference to a list of symbols names. These symbols
will be added to the C<@EXPORT_OK> array in your package.

=item ALL

The value should be the name of tag that doesn't yet exist. This tag will
contain a list of all symbols which can be exported.

=back

=head1 SEE ALSO

For details on what all these arrays and hashes actually do, see the
Exporter documentation.

=head1 AUTHOR

Written by Fergal Daly <fergal@esatclear.ie>.

=head1 LICENSE

Under the same license as Perl itself

=cut
