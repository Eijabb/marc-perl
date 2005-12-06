package MARC::Charset::Compiler; 

=head1 NAME

MARC::Charset::Compiler - compile XML mapping rules from LoC

=head1 SYNOPSIS

    $compiler = MARC::Charset::Compiler->new();
    $table = $compiler->compile('codetables.xml');

=head1 DESCRIPTION

MARC::Charset uses mapping rules from the Library of Congress for
generating a MARC::Charset::Table for looking up utf8 values based on the 
source MARC-8 character set and the character.

=head1 METHODS

=cut

use strict;
use warnings;

use base qw( XML::SAX::Base );
use XML::SAX::ParserFactory;
use Unicode::UCD qw(charinfo);
use MARC::Charset::Table;
use MARC::Charset::Code;


=head1 new()

The constructor.

=cut

sub new 
{
    my $self = bless {}, 'MARC::Charset::Compiler';
    $self->{table} = MARC::Charset::Table->new();
    $self->{current_code} = undef;
    $self->{text} = '';
    return $self;
}


=head1 compile()

Pass in the path to an XML file to compile.

=cut

sub compile 
{
    my ($self, $file) = @_;

    # erase the existing table
    $self->{table}->erase();

    my $factory = XML::SAX::ParserFactory->new();
    my $parser = $factory->parser(Handler => $self);
    $parser->parse_uri($file);
}


## SAX event handlers are below

sub start_element 
{
    my ($self, $data) = @_;
    my $name = $data->{Name};
    if ($name eq 'code')
    {
        $self->{current_code} = MARC::Charset::Code->new();
    }
    elsif ($name eq 'characterSet')
    {
        my $charset = $data->{Attributes}{'{}ISOcode'}{Value};
        warn('missing ISOcode in characterSet element') unless $charset;
        $self->{current_charset} = $charset;
    }
}


sub end_element
{
    my ($self, $data) = @_;
    my $name = $data->{Name};

    # normalize some names for method lookup
    $name = 'is_combining' if $name eq 'isCombining';

    # get the existing code if we have one
    my $code = $self->{current_code};

    # if we're ending a code element
    if ($code and $name eq 'code')
    {
        # set the charset code
        $code->charset($self->{current_charset});

        # lookup the name from perl's character db
        my $info = charinfo(hex($code->ucs()));
        $code->name($info->{name}) if $info;

        # add it to the table
        $self->{table}->add_code($code);

        # start with a clean slate
        $self->{current_code} = undef;
    }
   
    # add these elements
    elsif ($code and $name =~ /marc|ucs|is_combining/)
    {
        $code->$name($self->text());
    }

    # ending an element so forget all text
    $self->{text} = '';
}


sub characters 
{
    my ($self, $data) = @_;
    return unless $self->{current_code};
    my $text = $data->{Data};
    $self->{text} .= $data->{Data};
}


sub text 
{
    my $text = shift->{text};
    # collapse whitespace
    $text =~ s/\s\s+/ /g;
    # strip new lines
    $text =~ s/[\r\n]//g;
    # strip leading whitespace
    $text =~ s/^\s+//;
    # strip trailing whitespace
    $text =~ s/\s+$//;
    return $text;
}

1;
