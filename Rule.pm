#!/usr/local/bin/perl -w
require 5.001;
package Rule;
use Lex;
use Carp;
sub new {		
  my $package = shift; 
  my @args = @_;
  my($ref, $pre, $post, $elt);
				# interface management
  ARGS:while (1) {	
      $elt = pop(@args);     
      if (ref($elt) eq 'CODE') { # find anonymous routines
	if ($args[$#args] eq 'post') { # post => sub {...}
	  pop(@args);
	  $post = $elt;
	} elsif ($args[$#args] eq 'pre') { # pre => sub {...}
	  pop(@args);
	  $post = $elt;
	} elsif (not defined($post)) {	# 
	  $post = $elt;
	} elsif ($post) {	# sub {...}, sub {...}
	  $pre = $post;
	  $post = $elt;
	}
      } else {
	push(@args, $elt);
	last ARGS;
      }
    }

    @args = ([ @args ],  ($pre or $post) ? ($post, $pre) : undef);

    # Number of objects
    if ($package eq 'Hook') {
      if ($#{$args[0]} > 0) {
	croak("$package rule must have just one object as argument");
      }
    } elsif ($#{$args[0]} < 0) {
      croak("$package rule must have at least one object as argument");
    }
    # Object type
    foreach (@{$args[0]}) {
	$ref = ref($_);
	if ($ref ne 'REF' and 
	    $ref ne 'SCALAR' and
	    $ref ne 'ARRAY') {
	    croak("$_ isn't an ARRAY or a SCALAR reference");
	}
    }
				# Object Creation
    bless [1, @args], $package 
}
sub pre { $_[0][3] }
sub post { $_[0][2] }
sub probe { print STDERR ref(shift), "\t", @_, "\n" }
sub status { defined($_[1]) ? $_[0]->[0] = $_[1] : $_[0]->[0] } 

package Hook;
@ISA = qw(Rule);

sub next {
    my $self = shift;
    my $obj = ${${$self}[1]}[0];

    # Processing of Herited Attributes 
    # function: "pre" action
    # parameters: herited attributes
    # return: herited attributes
    my @_h = @_;  
    local @{main::_h} = @_h; # @_h must be visible in &$pre
    my $pre = $self->pre;
    if (ref($pre) eq 'CODE') {	
      @{main::h} = @_h = &{$pre}($self, @_);
    }
    # Processing of Sub-objects 
    # function: next
    # parameters: herited attributes
    # return: transformed synthetized attributes
    local @{main::_s} = $$obj->next(@_h);

    # Semantic
    # function: semantic action
    # parameters: synthetized attributes
    # return: synthetized attributes
    if (not ($$obj->status)) {
	$self->status(0);
	();		
    } else {
      $self->status(1);
      my $post = $self->post;
      if (defined($post)) {
	&{$post}($self, @{main::_s});
      } else {
	@{main::_s}; 
      }
    } 
}
package And;
@ISA = qw(Rule);
sub next {
    my $self = shift;
    my @objects = @{${$self}[1]};
    my @return;
    
    my @_h = @_;  
    local @{main::_h} = @_h; # @_h must be visible in &$pre
    my $pre = $self->pre;
    if (ref($pre) eq 'CODE') {	
      @{main::h} = @_h = &{$pre}($self, @_);
    }
    my $status = 1;
    local @main::_s;
  OBJ:foreach $obj (@objects) { # sub-objects
      @return = $$obj->next(@_h);
      if (not $$obj->status) {
	$status = 0;
	last OBJ;
      } else {
	push(@main::_s, @return) if $#return >= 0;
      }
    }
    if ($status) { 
      $self->status(1);
      my $post = $self->post;
      if (defined($post)) {
	&{$post}($self, @main::_s);
      } else {
	@main::_s;
      }
    } else {
      $self->status(0);
      ();
    }
}
package Or;
@ISA= qw(Rule);
$buffers = BufferList->new;

sub next {
    my $self = shift;
    my @objects = @{${$self}[1]};

    # action before
    my @_h = @_;  
    local @{main::_h} = @_h; # @_h must be visible in &$pre
    my $pre = $self->pre;
    if (ref($pre) eq 'CODE') {	
      @{main::h} = @_h = &{$pre}($self, @_);
    }

    local @main::_s;
    my @return;
    $buffers->push;
 OBJ:foreach $obj (@objects) { 
    @return = $$obj->next(@_h);
    if ($$obj->status) {
      @main::_s = @return;
      $self->status(1);
      last OBJ;
    } else {			# failure!
      $buffers->restore;	# backtracking
      $self->status(0);
    }
  } 
    $buffers->pop;
    if ($self->status) {
      my $post = $self->post;
      if (defined($post)) {
	&{$post}($self, @main::_s);
      } else {
	@main::_s;
      }
    } else {
	();
    }
}
package Any;		
@ISA= qw(Rule); 
$buffers = BufferList->new;

sub next {
    my $self = shift;
    my @objects = @{${$self}[1]};

    # action before
    my @_h = @_;  
    local @{main::_h} = @_h; # @_h must be visible in &$pre
    my $pre = $self->pre;
    if (ref($pre) eq 'CODE') {	
      @{main::h} = @_h = &{$pre}($self, @_);
    }

    $self->status(1);
    local @main::_s;
    my @return;
    my @tmpReturn;
    my $post = $self->post;
  OBJ:while (1) {
      $buffers->push;
      foreach $obj (@objects) {
	@return = $$obj->next(@_h);
	if (not $$obj->status) {
	  $buffers->restore;
	  last OBJ;
	} 
	push(@main::_s, @return) if $#return >= 0;
      }
      $buffers->pop;
      push(@tmpReturn, @main::_s);
      @main::_s = ();
  }
    $buffers->pop;
    $self->status(1);
    @main::_s = @tmpReturn;
    if (defined($post)) {
      &{$post}($self, @main::_s);
    } else {
      @main::_s;
    }
}
package Opt;
@ISA= qw(Rule); 
$buffers = BufferList->new;

sub next {
  my $self = shift;
  my @objects = @{${$self}[1]};

  # action before
  my @_h = @_;  
  local @{main::_h} = @_h; # @_h must be visible in &$pre
  my $pre = $self->pre;
  if (ref($pre) eq 'CODE') {	
    @{main::h} = @_h = &{$pre}($self, @_);
  }
  local @main::_s;
  my @return;
  my @tmpReturn;
  my $post = $self->post;
  $buffers->push;
  OBJ:foreach $obj (@objects) {
      @return = $$obj->next(@_h);
      if (not $$obj->status) {
	$buffers->restore;	
	$self->status(1);	# always truth
	@main::_s = ();
	last OBJ;
      } 
      push(@main::_s, @return) if $#return >= 0;
    }
  $buffers->pop;
  $self->status(1);  # always truth
  if (defined($post)) {
    &{$post}($self, @main::_s);
  } else {
    @main::_s;
  }
}
package Do;
@ISA = qw(Rule);
use Carp;
sub new {
  my $package = shift; 
  my $post = $_[0];
  my $pre = $_[1];
  if (not defined($post)) {
    croak("$package rule must have at least one anonymous routine as argument");
  }
  bless [1, [], $post, $pre];
}
sub next {
    my $self = shift;
    my @_h = @_;  
    local @{main::_h} = @_h; 
    my $pre = $self->pre;
    if (defined($pre)) {	
      @{main::h} = @_h = &{$pre}($self, @_);
    }
    $self->status(1);
    my $post = $self->post;
    if (defined($post)) {
       &{$post}($self, @{main::_s});
    } else {
	@{main::_s}; 
    }
}
1;
__END__

