package CoGe::Graphics::Feature::GBox;
use strict;
use base qw(CoGe::Graphics::Feature);


BEGIN {
    use vars qw($VERSION $HEIGHT $WIDTH);
    $VERSION     = '0.1';
    $HEIGHT = 5;
    $WIDTH = 5;
    __PACKAGE__->mk_accessors(
"nt",
"show_label",
"extra",
);
}

sub _initialize
  {
    my $self = shift;
    my %opts = @_;
    my $h = $HEIGHT; #total image height 
    my $w = $WIDTH;
    $self->image_width($w);
    $self->image_height($h);
    $self->bgcolor([255,255,255]) unless $self->bgcolor;
    $self->fill(1);
    $self->order(1);
    $self->stop($self->start + length $self->nt-1) unless $self->stop;
    $self->skip_overlap_search(1); #make sure to skip searching for overlap for these guys.  Search can be slow
    my $gbox = 0;
    my $sum = 0;
    my $seq = $self->nt;
#    print STDERR length ($seq),"\n";
    if (length ($seq) > 5)
      {
	while ($seq=~ /(CACGTG)/ig)
	  {
	    $sum += length $1;
	    $gbox++;
	  }
	while ($seq=~ /(GTGCAC)/ig)
	  {
	    $sum += length $1;
	    $gbox++;
	  }
      }
#     elsif(length ($seq) > 2)
#       {
# 	while ($seq=~ /(g*a*g+a+g*a*)/ig)
# 	  {
# 	    next unless length ($1) > 3;
# 	    $sum += length $1;
# 	    $ga++;
# 	  }
# 	while ($seq =~ /(c*t*c+t+c*t*)/ig)
# 	  {
# 	    next unless length ($1) > 3;
# 	    $sum += length $1;
# 	    $ct++;
# 	  }
#       }
    
    my $p = ($sum)/(length ($seq));
    my @color;
    my $red = 255;
    $red -= ($p*200);
    my $blue = 255;
    my $green = 255;

    @color = ($red, $red, $blue);


    $self->color(\@color);
    $self->label($self->nt) if $self->nt && $self->show_label;
    $self->type('gbox');
  }

sub _post_initialize
  {
    my $self = shift;
    my %opts = @_;
    my $gd = $self->gd;
    $gd->fill(0,0, $self->get_color($self->color));
#    $gd->transparent($gd->colorResolve(255,255,255));
  }

#################### subroutine header begin ####################

=head2 sample_function

 Usage     : How to use this function/method
 Purpose   : What it does
 Returns   : What it returns
 Argument  : What it wants to know
 Throws    : Exceptions and other anomolies
 Comment   : This is a sample subroutine header.
           : It is polite to include more pod and fewer comments.

See Also   : 

=cut

#################### subroutine header end ####################




#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

CoGe::Graphics::Feature::Base

=head1 SYNOPSIS

  use CoGe::Graphics::Feature::Base


=head1 DESCRIPTION

=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

	Eric Lyons
	elyons@nature.berkeley.edu

=head1 COPYRIGHT

This program is free software licensed under the...

	The Artistic License

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


1;
# The preceding line will help the module return a true value

