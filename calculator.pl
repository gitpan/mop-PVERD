#!/usr/local/bin/perl

$| = 1;
BEGIN {		
    @INC = ('.', @INC);
}
use Rule;
use Lex;

# A Grammar for a very simple desk calculator
# From Mason and Brown - Lex & Yacc -
# O'Reilly & Associates, 1990

#   LINES ::= { LINE }
#   LINE  ::= '\n' | EXP '\n'
#   EXP   ::= integer 
#             | '+' integer
#             | '-' integer
#             | '=' integer
#             | '=' 
# 

@tokens = (
	   'plus' => '[+]', 
	   'minus' => '[-]',
	   'equal' => '=',
	   'integer' => '[1-9][0-9]*',
	   'newline' => '\n',
	   'error'  => '',
	  );
$reader = Lex->new(@tokens);

$totalSum = 0;
$LINES = Any->new(\$LINE);
$LINE = Or->new(\(
		$newline,
		And->new(\$EXP, \$newline, sub {
		  print STDERR "= $totalSum\n";
		}), 
		Hook->new(\$error, sub { 
		  die "end of session\n";
		}),
	       ));

$EXP = Or->new(\(
	       And->new(\$integer, 
			sub { 
			  $totalSum += $_[1];
			}),
	       And->new(\$plus, \$integer, 
	                sub { 
			  $totalSum += $_[2];
			}),
	       And->new(\$minus, \$integer,
			sub { 
			  $totalSum -= $_[2];
			}),
	       And->new(\$equal, \$integer,
		        sub {
			  $totalSum = $_[2];
			}),
	       And->new(\$equal, 
			sub { 
			  $totalSum = 0;
			}),
	       ));
$LINES->next, "\n";
__END__






