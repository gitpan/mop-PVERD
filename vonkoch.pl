#!/usr/local/bin/perl

BEGIN {
  push(@INC, "$ENV{HOME}/perl/lib");
}
require 5.000;
use Rule;
use Turtle;

# (3, 20), (4, 10), (5, 5), (6, 3), (7, 1)
($order, $step, $factor) = (6, 80, 2);

print ("Nombre de niveaux : ", $order, "\n",
       "Longueur initiale : ", $step, "\n",
       "Facteur de réduction: ", $factor, "\n"
      );

$turtle = Turtle->new(300, 300, 0, 1);
$FLOCON = And->new(\(	       
		      Hook->new(\$BROKEN_LINE,
			       sub { $turtle->right(120) }),
		      Hook->new(\$BROKEN_LINE,
			       sub { $turtle->right(120) }),
                      Hook->new(\$BROKEN_LINE)
                   ));

$BROKEN_LINE =  
    Or->new(\(
	    Hook->new(\$turtle, 
		      sub { $turtle->forward($_h[1]) }
		     ),
	    And->new(\(
		     Hook->new(\$BROKEN_LINE, 
			       sub { $turtle->left(60) },
			       sub { ($_[1] - 1, $_[2]/$_[3], $_[3]) }
			      ),
		     Hook->new(\$BROKEN_LINE, 
			       sub { $turtle->right(120) }, 
			       sub { ($_[1] - 1, $_[2]/$_[3], $_[3]) }
			      ),
		     Hook->new(\$BROKEN_LINE, 
			       sub { $turtle->left(60) }, 
			       sub { ($_[1] - 1, $_[2]/$_[3], $_[3]) }
			      ),
		     Hook->new(\$BROKEN_LINE, 
			       sub { }, 
			       sub { ($_[1] - 1, $_[2]/$_[3], $_[3]) }
			      ),
		    )),
 ));

$FLOCON->next($order, $step, $factor);
$turtle->show;

package Turtle;
$status = 0;
sub status { $status }
sub next { 
  if ($_[1] == 1) {
    $status = 1;
  } else {
    $status = 0;
  }
}

__END__

