package Bio::Tools::Run::JavaRunner;
use strict;
use Bio::Tools::Run::AbstractRunner;
use Bio::Root::AccessorMaker ('$'=>[qw(jar class min_version)]);

our @ISA=qw(Bio::Tools::Run::AbstractRunner);

=head1 new

 Title   : new
 Usage   : $runner = Bio::Tools::Run::JavaRunner->new(-jar => $jar)
 Function: Builds a new Bio::Tools::Run::JavaRunner object
 Returns : Bio::Tools::Run::JavaRunner
 Args    : -jar => $path to jarfile
             OR
           -class => $classfile name        
           -min_version => $versionstring 

=cut


sub _initialize {
    my ($self, @args)=@_;
    $self->SUPER::_initialize(@args);
    my ($jar, $class, $min_version)=
        $self->_rearrange([qw(jar class min_version)], @args);
    defined $jar and $self->jar($jar);
    defined $class and $self->class($class);
    defined $min_version and $self->min_version($min_version);
}

sub _run_file_1in1out {
    my $self=shift;
}

sub _run_java {
    my $self=shift;
    my $program;
    if(defined $self->jar){
        $program = "-jar ". $self->jar;
    } elsif(defined $self->class){
        $program = $self->class;
    }else{
        $self->throw('Neither jar nor class is assigned');
    }
    $program = "java $program";
    $self->_run_program($program);
}

1;

__END__

=pod

=head1 NAME

Bio::Tools::Run::JavaRunner - run java programs

=head1 SYNOPSIS

   my $runner = Bio::Tools::Run::JavaRunner->new(-jar => $jar);
   $runner->run();

=head1 DESCRIPTION

This module is probably incomplete.  It is intended to be a wrapper
for running java programs.

=head1 AUTHOR

Juguang Xiao, juguang at tll.org.sg

=head1 COPYRIGHT

This module is a free software.
You may copy or redistribute it under the same terms as Perl itself.

=cut

