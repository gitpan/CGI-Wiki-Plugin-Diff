package CGI::Wiki::Plugin::Diff;

use strict;
use warnings;

our $VERSION = '0.05';

use base 'CGI::Wiki::Plugin';
use Algorithm::Diff;
use VCS::Lite;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub differences {
    my ($self, %args) = @_;
    my ($node, $v1, $v2)  = @args{ qw( node left_version right_version) };
    my $store = $self->datastore;
    my $fmt = $self->formatter;
    
    my %ver1 = $store->retrieve_node( name => $node, version => $v1);
    my %ver2 = $store->retrieve_node( name => $node, version => $v2);

    my $verstring1 = "Version ".$ver1{version};
    my $verstring2 = "Version ".$ver2{version};
    
    my $el1 = VCS::Lite->new($verstring1,undef,
    	_content_escape($ver1{content}).'<BR />'.
	_serialise_metadata($ver1{metadata},
		@args{qw(meta_include meta_exclude)}));
    my $el2 = VCS::Lite->new($verstring2,undef,
    	_content_escape($ver2{content}).'<BR />'.
	_serialise_metadata($ver2{metadata},
		@args{qw(meta_include meta_exclude)}));
    my %pag = %ver1;
    $pag{left_version} = $verstring1;
    $pag{right_version} = $verstring2;
    $pag{content} = $fmt->format($ver1{content});
    my $dlt = $el1->delta($el2)
	or return %pag;

    my @out;
    
    for ($dlt->hunks) {
    	my ($lin1,$lin2,$out1,$out2);
	for (@$_) {
	    my ($ind,$line,$text) = @$_;
	    if ($ind ne '+') {
		$lin1 ||= $line;
		$out1 .= $text;
	    }
	    if ($ind ne '-') {
		$lin2 ||= $line;
		$out2 .= $text;
	    }
	}
    	push @out,{ left => $lin1 ? "== Line $lin1 ==\n" : "", 
		right => $lin2 ? "== Line $lin2 ==\n" : ""};
	my ($text1,$text2) = _intradiff($out1,$out2);
	push @out,{left => $text1,
		right => $text2};
    }

    $pag{diff} = \@out;
    %pag;
}

sub _serialise_metadata {
    my $hr = shift;
    my $include = shift || [keys %$hr];
    my $exclude = shift || [qw(comment username 
    			__categories__checksum __locales__checksum)];
    my %metadata = map {$_,$hr->{$_}} @$include;
    delete $metadata{$_} for @$exclude;

    join "<br />\n", map {"$_='".join (',',sort @{$metadata{$_}})."'"} sort keys %metadata;
}

sub _content_escape {
    my $str = shift;

    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s!\n!<br />\n!gs;

    $str;
}

sub _intradiff {
    my ($str1,$str2) = @_;

    return (qq{<span class="diff1">$str1</span>},"") unless $str2;
    return ("",qq{<span class="diff2">$str2</span>}) unless $str1;
    my $re_wordmatcher = qr(
            &.+?;                   #HTML special characters e.g. &lt;
            |<br\s*/>               #Line breaks
            |\w+\s*       	    #Word with trailing spaces 
            |.                      #Any other single character
    )xsi;
                                             
    my @diffs = Algorithm::Diff::sdiff([$str1 =~ /$re_wordmatcher/sg]
    	,[$str2 =~ /$re_wordmatcher/sg]);
    my $out1 = '';
    my $out2 = '';
    my ($mode1,$mode2);

    for (@diffs) {
    	my ($ind,$c1,$c2) = @$_;

	my $newmode1 = $ind =~ /[c\-]/;
	my $newmode2 = $ind =~ /[c+]/;
	$out1 .= '<span class="diff1">' if $newmode1 && !$mode1;
	$out2 .= '<span class="diff2">' if $newmode2 && !$mode2;
	$out1 .= '</span>' if !$newmode1 && $mode1;
	$out2 .= '</span>' if !$newmode2 && $mode2;
	($mode1,$mode2) = ($newmode1,$newmode2);
	$out1 .= $c1;
	$out2 .= $c2;
    }
    $out1 .= '</span>' if $mode1;
    $out2 .= '</span>' if $mode2;

    ($out1,$out2);
}

1;
__END__

=head1 NAME

CGI::Wiki::Plugin::Diff - format differences between two CGI::Wiki pages

=head1 SYNOPSIS

  use CGI::Wiki::Plugin::Diff;
  my $plugin = CGI::Wiki::Plugin::Diff->new;
  $wiki->register_plugin( plugin => $plugin );   # called before any node reads
  my %diff = $plugin->differences( node => 'Imperial College',
  				left_version => 3,
				right_version => 5);

=head1 DESCRIPTION

A plug-in for CGI::Wiki sites, which provides a nice extract of differences
between two versions of a node. 

=head1 METHODS

=over 4

=item B<differences>

  my %diff_vars = $plugin->differences(
      node          => "Home Page",
      left_version  => 3,
      right_version => 5
  );

Returns a hash with the key-value pairs:

=over 4

=item *

B<left_version> - The node version whose content we're considering canonical.

B<right_version> - The node version that we're showing the differences from.

B<content> - The (formatted) contents of the I<Left> version of the node.

B<meta_include> - Filter the list of metadata fields to only include a certain
list in the diff output. The default is to include all metadata fields.

B<meta_exclude> - Filter the list of metadata fields to exclude certain
fields from the diff output. The default is the following list, to match
previous version (OpenGuides) behaviour:
   username
   comment
   __categories__checksum
   __locales__checksum

Agreed this list is hopelessly inadequate, especially for L<OpenGuides>.
Hopefully, future wiki designers will use the meta_include parameter to
specify exactly what metadata they want to appear on the diff.

B<diff> - An array of hashrefs of C<hunks> of differences between the
versions. It is assumed that the display will be rendered in HTML, and SPAN
tags are inserted with a class of diff1 or diff2, to highlight which
individual words have actually changed. Display the contents of diff using
a E<lt>tableE<gt>, with each member of the array corresponding to a row 
E<lt>TRE<gt>, and keys {left} and {right} being two columns E<lt>TDE<gt>.

Usually you will want to feed this through a templating system, such as
Template Toolkit, which makes iterating the AoH very easy.

=back

=head1 TODO

Write more tests for this module!

Make this module more generic, allow selection of formatting options. Add
the ability to select which metadata fields are diffed.

Improve the OO'ness by making the module subclassable, substituting different
methods for _serialise_metadata and _content_escape.

I am also looking to take the I<intradiff> functionality out of this module
and into its own freestanding module where it belongs.

=head1 BUGS AND ENHANCEMENTS

Please use rt.cpan.org to report any bugs in this module. If you have any
ideas for how this module could be enhanced, please email the author, or
post to the CGI::Wiki list (CGI (hyphen) wiki (hyphen) dev (at) earth (dot) li).

=head1 AUTHOR

I. P. Williams (IVORW [at] CPAN {dot} org)

=head1 COPYRIGHT

     Copyright (C) 2003 I. P. Williams (IVORW [at] CPAN {dot} org).
     All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<VCS::Lite>, L<CGI::Wiki>, L<CGI::Wiki::Plugin>

=cut
