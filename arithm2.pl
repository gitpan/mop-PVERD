#!/usr/local/bin/perl
# todo:
# - "(1+2" no error message
# - RC rien ne se passe

$| = 1;
BEGIN {		
  push(@INC,  ('.', "$ENV{'HOME'}/perl/lib"));
}

use Rule;
use Lex;
use Tracer;

#$Lex::debug = 1;
#$Token::debug = 1;
#$BufferList::debug = 1;

# A Small Grammar
# 
#   EXPR ::= TERM { ADDOP TERM }
#   ADDOP ::= '+' | '-'
#   TERM ::= FACTOR { MULOP FACTOR }
#   MULOP ::= '*' | '/'
#   FACTOR ::= NUMBER | '(' EXPR ')'
# 

# 
# Parser
# 
# Tokens
@tokens = qw(
	   ADDOP [+-]
	   MULOP [\*\/] 
	   LEFTP [(]
	   RIGHTP [)]
	   NUMBER (?:\d+([.]\d*)?|[.]\d+)(?:[Ee][+-]?\d+)?
	  );
$reader = Lex->new(@tokens);
$reader->singleline;
$reader->chomp;

# Rules
$EXPR = And->new(\($TERM,  Any->new(\$ADDOP, \$TERM)), 
		    sub {
		      shift;
		      my $result = shift;
		      while ($#_ >= 0) {
			if ($_[0] eq '+')  {
			  $result += $_[1];
			} else {
			  $result -= $_[1];
			}
			shift; shift;
		      }
		      $result;
		    });
$TERM = And->new(\($FACTOR, Any->new(\$MULOP, \$FACTOR)),
		    sub {
		      shift;
		      my $result = shift;
		      while ($#_ >= 0) {
			if ($_[0] eq '*')  {
			  $result *= $_[1];
			} else {
			  $result /= $_[1] or
			    warn "Illegal division by zero\n";
			}
			shift; shift;
		      }
		      $result;
		    });
$FACTOR = Or->new(\$NUMBER, \$PAREXP,
		  sub { $_[1] });
$PAREXP = And->new(\$LEFTP, \$EXPR, \$RIGHTP,
		   sub { $_[2] });

# 
# Interaction Loop
# 
$trace = 0;
$prompt = '=> ';
EXPR:while (1) {
    print STDERR "$prompt";
    print STDERR $EXPR->next;
    last EXPR if $reader->eof;
    if (not $EXPR->status) {
      print STDERR "invalid expression: $_\n";
      print STDERR "unanalyzed text: ", 
      $reader->token->get, $reader->buffer, "\n";
    } else {
      print "\n";
    }
    $reader->reset;
}
print "\n";
1;

__END__




