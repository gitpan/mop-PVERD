#!/usr/local/bin/perl

BEGIN {		
  push(@INC, ('.'));
}
use Lex;

@tokens = (
	   'ADDOP' => '[-+]', 
	   'LEFTP' => '[(]',
	   'RIGHTP' => '[)]',
	   'INTEGER' => '[1-9][0-9]*',
	   'NEWLINE' => '\n',
	   'ERROR' => '.*',
	  );
$reader = Lex->new(@tokens);
$reader->from(\*DATA);

TOKEN:while (1) {
  $token = $reader->nextToken;
  if (not $reader->eof) {
    print "line $.\t";
    print ref($token), "\t";
    print "Type: ", $token->name, "\t";
    $value = $token->get;
    print "Content:->", $value, "<-\n";
  } else {
    last TOKEN;
  }
}
__END__
1+2*
