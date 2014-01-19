package App::Atombomb;
use XML::Tag::Atom;
use Eirotic;
use IPC::Open2;
use Try::Tiny;
use Text::Unidecode;
use HTML::Entities;
use Exporter 'import';
our @EXPORT = qw<
    parse_entry_header
    piping
    pandoc
    sha1sum
    entry_for
    write_entry
    feed_content
    atom
    md
>;

# ABSTRACT: from simple markdown to atom feed

our $VERSION = '0.0';
our $FOUND_HEADER = qr{
    ^ \#\( (?<created>
          \d{4} - \d{2} - \d{2}
    T     \d{2} : \d{2} : \d{2}
    \+    \d{2} : \d{2} )
    \) \s (?<title> .+?)
    \s* $
}xms;

=head1 internal functions documentation

=head2 parse_entry_header

parse the header or an entry as described in the command documentation .

=cut
sub parse_entry_header (_) {
    my $text = shift;
    return unless $text =~ m{$FOUND_HEADER};
    +{%+}
}

=head1 piping, pandoc and sha1sum

piping is little wrapper around open2, just to pipe text to a command and get
the output.

see pandoc and sha1sum as examples
=cut

sub piping {
    my $input = pop or die;
    @_ or die;

    # TODO: read the doc (https://metacpan.org/pod/IPC::Open2)
    # and test "$? >> 8"
    # waitfor $pid, 0;

    my ( $pid, $in, $out );
    $pid = open2 $out, $in, @_;
    print $in $input; close $in;
    my $html = do { local $/; <$out> };
    map {close $_} $in, $out;
    $html;
}

sub pandoc  { piping qw< pandoc ->, shift }
sub sha1sum {
    ( split ' '
    , piping qw< sha1sum -> 
    , shift )[0]
}

=head1 entry_for ( $header, $md )

build the entry structure from a C<$header> (see parse_entry_header for format
details) and a markdown source $md as content. 

=cut
func entry_for ( $header, $md ) {
    my $e = parse_entry_header $header
        or die "can't parse header";

    map {
        die unless $_;
        $$e{id} ||= join ','
            , 'tag:eiro,news'
            , $$e{created}
            ,  unidecode lc s/[^a-zA-Z0-9]+/_/gr;
    } $$e{title};

    die "can't parse makdown" unless 
        $$e{html} = encode_entities pandoc $md;

    for ($$e{alternates}) {
        $_ or $_ = [], next;
        $_ = [ fold apply {
                    my ( $rel, $spec ) = @$_;
                    +{ ref => $rel, %$spec } 
                } pairs $_ ]
    }

    $e
}

=head1 write_entry

return the atom xml for an the entry structure (as returned by entry_for).

=cut
sub write_entry (_) {
    my $e = shift;
    entry
    { id        {$$e{id}}
    , title     {$$e{title}}
    , content   {+{ type => 'html'},  $$e{html} }
    , published { $$e{created} }
    , updated   { $$e{created} } }
}

=head1 feed_content

return the atom xml of the whole feed content (no root tag). 

=cut
sub feed_content (_) {
    my $v = shift;
    ''
    , updated{$$v{updated} || $$v{entries}[0]{created} || die YAML::Dump $v }
    , id{$$v{id}}
    , author{$$v{author}}
    , title{$$v{title}}
    , map write_entry, @{ $$v{entries} };
}

func atom ( $input ) {
    my ( $header , @chunks ) = 
        map   s/(\s*\n)\z//rxms
        , split /(^\#\(\N+)/xms
        , $input;

    my $v =
        try { YAML::Load "$header\n" }
        catch {
            die
            ( (uc "$_ while parsing")
            , map {s/^/\t/xmsgr} $header )
        };

    $$v{entries} =
        [ fold
            apply { (entry_for @$_) || die}
            chunksOf 2, \@chunks ];

    '<?xml version="1.0" encoding="UTF-8"?><feed xml:lang="en-US" xmlns="http://www.w3.org/2005/Atom">'
    , (feed_content $v)
    , '</feed>';
}

sub md (_) {

    my $_ = shift;

    s{ \A
        .* ^title:  (\N+)
        .*? (?= ^\#\( )
    }{% $1\n\n}xms;

    s{$FOUND_HEADER}
     {# $+{title}\n<p class="date"> $+{created}</p>\n}xmsg;

    $_;
}

1;

