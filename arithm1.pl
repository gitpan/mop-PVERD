#!/usr/local/bin/perl

$| = 1;
BEGIN {		
  push(@INC,  ('.', "$ENV{'HOME'}/perl/lib"));
}
use Rule;
use Lex;

# A Small Grammar
# 
#   EXPR ::= FACTOR { ADDOP FACTOR }
#   ADDOP ::= '+' | '-'
#   FACTOR ::= INTEGER | '(' EXPR ')'
#   INTEGER ::= '[1-9][0-9]*'

@tokens = (
	   'addop' => '[-+]', 
	   'leftp' => '[(]',
	   'rightp' => '[)]',
	   'integer' => '[-]?[1-9][0-9]*',
	  );
$reader = Lex->new(@tokens);

$EXPR = And->new(\($FACTOR, Any->new(\$addop, \$FACTOR)),
                 sub { 
		   shift(@_);
		   my $result = shift(@_);
		   my ($op, $integer);
		   while ($#_ >= 0) {
		     ($op, $integer) = (shift(@_), shift(@_));
		     if ($op eq '+')  {
		       $result += $integer;
		     } else {
		       $result -= $integer;
		     }
		   }
		   $result;
		 }, sub { 
		   print STDERR "Type your arithmetic expression: ";
		 });
$FACTOR = Or->new(\$integer, \$PAREXP);
$PAREXP = And->new(\$leftp, \$EXPR, \$rightp,
		    sub { $_[2] });
print "Result: ", $EXPR->next, "\n";
1;

__END__
