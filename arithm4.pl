#!/usr/local/bin/perl5
# 
# - Suppress use of $singleline and read
# 
$debug = 1;
$| = 1;
BEGIN {		
    @INC = ('.', @INC);
}
use Rule;
use Tracer;
$trace = 0;

# Grammar of Arithmetic Expressions
# 
#   EXPR ::= TERM { ADDOP TERM }
#   ADDOP ::= '+' | '-'
#   TERM ::= FACTOR { MULOP FACTOR }
#   MULOP ::= '*' | '/'
#   FACTOR ::= NUMBER | '(' EXPR ')'
# 

# Parser
# 
# Token definitions
$ADDOP = Token->new('[-+]');
$MULOP = Token->new('[*\/]');
$LEFTP = Token->new('[\(]');
$RIGHTP = Token->new('[\)]');
$NUMBER = Token->new('[-+]?(\d+([.]\d*)?|[.]\d+)([Ee][+-]?\d+)?');
$EOE = Token->new('\n');

# Rule definitions
$EXPR = And->new([\(
		  $TERM, Any->new([\$ADDOP, \$TERM])
		  )], 
sub {
    Trace("ADDTERM \@_: @_");
    my $result = shift;
    while ($#_ > 0) {
	if ($_[0] eq '+')  {
	    $result += $_[1];
	} else {
	    $result -= $_[1];
	}
	shift; shift;
    }
    $result;
});
$TERM = And->new([\$FACTOR, \${\Any->new([\$MULOP, \$FACTOR])}],
sub { 
    Trace("TERM \@_: @_");
    my $result = shift;
    while ($#_ > 0) {
	if ($_[0] eq '*')  {
	    $result *= $_[1];
	} else {
	    $result /= $_[1] || warn "division by zero\n";
	}
	shift; shift;
    }
    $result;
});
$FACTOR = Or->new([\$NUMBER, \${\And->new([\$LEFTP, \$EXPR, \$RIGHTP])}],
    sub { 
	Trace("FACTOR \@_: @_");
	if ($#_ > 0) {
	    $_[1];
	} else {
	    $_[0];
	}
    });

# 
# Interaction Loop
# 
$trace = 0;
Trace("test OK");
$Token::singleline = 1;
$result = '';

if (-t STDIN && -t STDERR) {
    $| = 1;
    print STDERR "A very simple interpreter for arithmetic expressions\n";
    print STDERR "P. Verdret & L. Humphreys, 1995\n";
    $prompt = '=> ';
} else {
    $prompt = '';
}
#$Token::chomp = 1;
EXPR:while (1) {
    print STDERR "$prompt" if $prompt;
    $result = $EXPR->next;
    if (!$EXPR->status && $Token::buffer ne '') {
	warn "unanalyzed text: $Token::buffer\n";
    } elsif ($Token::eof) {
	print STDERR "\n";
	exit;
    } elsif ($result ne '') {
	print STDERR "$result\n";
    }
    $Token::buffer = '';
    $Token::read = 0;  # if you want read a new expression
}
1;
__END__






