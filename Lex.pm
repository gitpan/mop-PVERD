#!/usr/local/bin/perl -w
# todo :
# - Bufferlist must be rewrited

require 5.001;
package Lex;
use Carp;
@ISA= qw(Carp);
$buffers = BufferList->new;

$skip = '[ \t]+';		# characters to skip
$chomp = 0;			# remove newline at end of line
$singleline = 0;		# reading of singleline expressions
$FH = "STDIN";			# Filehandle name on which to read
$read = 0;			# read or don't read
$buffer = '';			# string to tokenize
$eof = 0;			# if eof is met
$pendingToken = 0;		# if 1 there is a pending token
$defaultToken = Token->new('default token'); # default token
$debug = 0;

sub eof { $eof } 
sub less { 
  if (defined $_[1]) {
    $buffer = $_[1] . $buffer;
  }
}
sub token { $pendingToken or $defaultToken } # always return a Token object
sub buffer { defined($_[1]) ? $buffer = $_[1] : $buffer } 
sub reset { 
  $read = 0; 
  $buffer = ''; 
  if ($pendingToken) {
      $pendingToken->set();
      $pendingToken = 0;
  }
}
# Tokenizer and reader configuration
sub skip { defined($_[1]) ? $skip = $_[1] : $skip }
				# switches
sub chomp { $chomp = $chomp ? 0 : 1 }
sub singleline { $singleline = $singleline ? 0 : 1 }
sub debug { 
  if ($debug) {
    $debug = 0;
    print STDERR "debug: off in ", ref($_[0]), "\n";
  } else {
    $debug = 1;
    print STDERR "debug: on in ", ref($_[0]), "\n";
  }
}
sub new {			# Generation of the nextToken routine
  shift;
  if (not defined($_[0])) {
    croak("no parameters for the new method");
    return;
  }
  my $reader = bless [$FH, $skip, @_]; # not used for the moment
  my $body = q!{		# beginning of generated code
    my $skipped;
    if (not $eof and $buffer eq '') { # $buffer is empty
      do {
	$buffer = $_[0]->readline;
	$buffer =~ s/^$skip//o;
	$skipped .= $&;
      } while (not $eof and $buffer eq '');
      $read = 1 if $singleline == 1; 
    } else {
      $buffer =~ s/^$skip//o;
      $skipped = $&;		
    }
    my $consumed = $content = '';
  SWITCH:{
!;
  my $package = (caller(0))[0];
  my ($id, $regExp, $sub);
  while ($#_ > -1) {
    ($id, $regexp) = (shift, shift);
    $id = "$package" . "::" . "$id";
    if (ref($_[0]) eq 'CODE') {	# is next arg a sub reference?
      $sub = shift;
    } else {
      $sub = undef;
    }
    $regexp =~ s{
	(
	 (?:[^\\]|^)(?:\\{2,2})*        (?# before context)
	)([/!\"])	         	(?# Delimiters)
    }{$1\\$2}xg;
    ${$id} = Token->new($id, $regexp, $sub, $reader);
    $body .= qq!  \$buffer =~ s/^$regexp//o and do {
      print STDERR "Token consumed($regexp): ", \$$id->name, " \$&\\n" if \$debug;
      \$content = \$&;
      \$pendingToken = \$consumed = \$$id;
      my \$mean = \$$id->mean;   
      if (defined(\$mean)) {
	\$content = \&{\$mean}(\$_[0], \$content);
	\$$id->set(\$content);
      } else {
	\$$id->set(\$content);
      }
      last SWITCH;
    };\n!;
  }
  # End of generated code 
  $body .= q! }
  if ($consumed or $skipped ne '') {
    $buffers->save($skipped . $content);
  }
  return $pendingToken;
}!;
  eval qq!sub nextToken $body!;
  if ($@ or $debug)		# can be usefull
  {
    print STDERR "$body\n";
    print STDERR "$@\n";
    die "\n" unless $debug;
  }
  $reader;			# reader identity
}
sub readline {
  $_ = <$FH>;
  $eof = 1 unless defined($_);
  chomp($_) if $chomp;
  $_;
}
sub from {
  my $self = shift;
  if (ref($_[0]) eq 'GLOB' and 
      defined fileno($_[0])) {	# Read data from a filehandle
    $FH = $_[0];
  } elsif ($_[0]) {		# Data in a variable or a list
    $FH = "";
    $buffer = join($", @_);	# Data in a table
				# would be nice to have a 
				# specific readline
  } else {
    $FH = ARGV;
  }
  $FH;
}
1;

package Token;
$debug = 0;
sub new {
  bless [0,			# object status
	 '',			# string
	 $_[1],			# name
	 $_[2],			# regexp
	 $_[3],			# sub
	 $_[4],			# reader identity
	 ];
}
sub status { defined($_[1]) ? $_[0]->[0] = $_[1] : $_[0]->[0] } 
sub set {    $_[0]->[1] = $_[1] } # hold string
sub get {    $_[0]->[1] }	# return recognized string 
sub name {   $_[0]->[2] }	# name of the token
sub regexp { $_[0]->[3] }	# regexp
sub mean {   $_[0]->[4] }	# anonymous fonction
sub reader { $_[0]->[5] }	# id of the reader

sub debug { 
  if ($debug) {
    $debug = 0;
    print STDERR "debug: off in ", ref($_[0]), "\n";
  } else {
    $debug = 1;
    print STDERR "debug: on in ", ref($_[0]), "\n";
  }
}
sub next {
  my $self = shift;
  if ($Lex::read and		# expression is already readed
      $Lex::buffer eq '' and 
      not $Lex::pendingToken) {
    $self->status(0);
    return;
  }
  if (not $Lex::pendingToken) {
    $self->[5]->nextToken();
  }
  print STDERR "Try to find: ", $self->[2], "\n" if $debug;
  my $content = $self->get;
  if ($content ne '') {		# token isn't empty
    print STDERR "Token found: ", $self->[2], " $content\n" if $debug;
    $Lex::pendingToken = 0;	# now no pending token
    $self->set();		
    $self->status(1);
    $content;			# return token string
  } else {
    $self->status(0);
    undef;
  }
}
1;

package BufferList;
$debug = 0;
$buffers = 0;			# reference to a buffer list
sub new {
    if ($buffers) {		# only one BufferList object
	return $buffers;
    } else {
	$buffers = bless [];
	$buffers;
    }
}
sub restore {
    my $num = $#{$buffers};
    return unless $num >= 0 and ${$buffers}[$num] ne '';
				# not very elegant
    $Lex::buffer = ${$buffers}[$num] . $Lex::buffer;
    print STDERR ("restored content (buf num: $num):->", $Lex::buffer, "<- ") if $debug;
				# use $reader->reset
    if ($Lex::pendingToken) {
      $Lex::pendingToken->set;
      $Lex::pendingToken = 0;	
    }
    ${$buffers}[$num] = '';
}
sub save {			# save in buffers
    my $num = $#{$buffers};
    return unless $num >= 0;
    print STDERR ("content saved (buf num: $num):->$_[1]<-\n") if $debug;
    ${$buffers}[$num] .= $_[1];
}
sub last {
    my $num = $#{$_[0]};
    defined($_[1]) ? ${$_[0]}[$num] = $_[1] : ${$_[0]}[$num];
}
sub push {			# add a new buffer
    print STDERR ("push (buffer num. $#{$buffers})\n") if $debug;
    push(@{$_[0]}, "");
}
sub pop {			# pop the last buffer
  print STDERR ("pop buffer num. $#{$buffers}\n") if $debug;
  pop(@{$_[0]});
}
sub purge { @{$_[0]} = () }
1;
__END__
