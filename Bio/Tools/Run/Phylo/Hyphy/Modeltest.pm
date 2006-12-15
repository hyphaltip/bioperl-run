# $Id$
#
# BioPerl module for Bio::Tools::Run::Phylo::Hyphy::Modeltest
#
# Cared for by Albert Vilella <avilella-at-gmail-dot-com>
#
# Copyright Albert Vilella
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Phylo::Hyphy::Modeltest - Wrapper around the Hyphy Modeltest analysis

=head1 SYNOPSIS

  use Bio::Tools::Run::Phylo::Hyphy::Modeltest;
  use Bio::AlignIO;

  my $alignio = new Bio::AlignIO(-format => 'phylip',
  			         -file   => 't/data/gf-s85.phylip');

  my $aln = $alignio->next_aln;

  my $treeio = Bio::TreeIO->new(
      -format => 'nh', -file => 't/data/tree.nh');

  my $modeltest = new Bio::Tools::Run::Phylo::Hyphy::Modeltest();
  $modeltest->alignment($aln);
  $modeltest->tree($tree);
  my ($rc,$parser) = $modeltest->run();
  my $result = $parser->next_result;
  my $MLmatrix = $result->get_MLmatrix();
  print "Ka = ", $MLmatrix->[0]->[1]->{'dN'},"\n";
  print "Ks = ", $MLmatrix->[0]->[1]->{'dS'},"\n";
  print "Ka/Ks = ", $MLmatrix->[0]->[1]->{'omega'},"\n";

=head1 DESCRIPTION

This is a wrapper around the Modeltest analysis of HyPhy ([Hy]pothesis
Testing Using [Phy]logenies) package of Sergei Kosakowsky Pond,
Spencer V. Muse, Simon D.W. Frost and Art Poon.  See
http://www.hyphy.org for more information.

This module will generate the correct list of options for interfacing
with TemplateBatchFiles/Ghostrides/Modeltestwrapper.bf.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Albert Vilella

Email avilella-at-gmail-dot-com

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Tools::Run::Phylo::Hyphy::Modeltest;
use vars qw(@ISA @VALIDVALUES $PROGRAMNAME $PROGRAM);
use strict;
use Bio::Root::Root;
use Bio::AlignIO;
use Bio::TreeIO;
use Bio::Tools::Run::WrapperBase;

@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);

=head2 Default Values

Valid and default values for Modeltest are listed below.  The default
values are always the first one listed.  These descriptions are
essentially lifted from the python wrapper or provided by the author.

INCOMPLETE DOCUMENTATION OF ALL METHODS

=cut

BEGIN { 
    $PROGRAMNAME = 'HYPHYMP' . ($^O =~ /mswin/i ?'.exe':'');
    if( defined $ENV{'HYPHYDIR'} ) {
	$PROGRAM = Bio::Root::IO->catfile($ENV{'HYPHYDIR'},$PROGRAMNAME). ($^O =~ /mswin/i ?'.exe':'');;
    }

    @VALIDVALUES = 
        (
         {'tempalnfile' => undef }, # aln file goes here
         {'temptreefile' => undef }, # tree file goes here
         {'Number of Rate Classes' => [ '4' ] },
         {'Model Selection Method' => [ 'Both', 
                                        'Hierarchical Test', 
                                        'AIC Test'] },
         {'Model rejection level' => '0.05' },
        );
}

=head2 program_name

 Title   : program_name
 Usage   : $factory->program_name()
 Function: holds the program name
 Returns:  string
 Args    : None

=cut

sub program_name {
        return 'HYPHYMP';
}

=head2 program_dir

 Title   : program_dir
 Usage   : ->program_dir()
 Function: returns the program directory, obtiained from ENV variable.
 Returns:  string
 Args    :

=cut

sub program_dir {
        return Bio::Root::IO->catfile($ENV{HYPHYDIR}) if $ENV{HYPHYDIR};
}


=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::Phylo::Hyphy::Modeltest();
 Function: Builds a new Bio::Tools::Run::Phylo::Hyphy::Modeltest object 
 Returns : Bio::Tools::Run::Phylo::Hyphy::Modeltest
 Args    : -alignment => the Bio::Align::AlignI object
           -save_tempfiles => boolean to save the generated tempfiles and
                              NOT cleanup after onesself (default FALSE)
           -tree => the Bio::Tree::TreeI object
           -params => a hashref of PAML parameters (all passed to set_parameter)
           -executable => where the hyphy executable resides

See also: L<Bio::Tree::TreeI>, L<Bio::Align::AlignI>

=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  my ($aln, $tree, $st, $params, $exe, 
      $ubl) = $self->_rearrange([qw(ALIGNMENT TREE SAVE_TEMPFILES 
				    PARAMS EXECUTABLE)],
				    @args);
  defined $aln && $self->alignment($aln);
  defined $tree && $self->tree($tree);
  defined $st  && $self->save_tempfiles($st);
  defined $exe && $self->executable($exe);

  $self->set_default_parameters();
  if( defined $params ) {
      if( ref($params) !~ /HASH/i ) { 
	  $self->warn("Must provide a valid hash ref for parameter -FLAGS");
      } else {
	  map { $self->set_parameter($_, $$params{$_}) } keys %$params;
      }
  }
  return $self;
}


=head2 prepare

 Title   : prepare
 Usage   : my $rundir = $modeltest->prepare($aln);
 Function: prepare the modeltest analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : value of rundir
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]

=cut

sub prepare {
   my ($self,$aln,$tree) = @_;
   unless ( $self->save_tempfiles ) {
       # brush so we don't get plaque buildup ;)
       $self->cleanup();
   }
   $tree = $self->tree unless $tree;
   $aln  = $self->alignment unless $aln;
   if( ! $aln ) { 
       $self->warn("must have supplied a valid alignment file in order to run hyphy modeltest");
       return 0;
   }
   my ($tempdir) = $self->tempdir();
   my ($tempseqFH,$tempalnfile);
   if( ! ref($aln) && -e $aln ) { 
       $tempalnfile = $aln;
   } else { 
       ($tempseqFH,$tempalnfile) = $self->io->tempfile
	   ('-dir' => $tempdir, 
	    UNLINK => ($self->save_tempfiles ? 0 : 1));
       my $alnout = new Bio::AlignIO('-format'      => 'phylip',
				     '-fh'          => $tempseqFH,
                                     '-interleaved' => 0);

       $alnout->write_aln($aln);
       $alnout->close();
       undef $alnout;
       close($tempseqFH);
   }
   $self->{'_modeltestparams'}{'tempalnfile'} = $tempalnfile;
   my $outfile = $self->outfile_name || "$tempdir/modeltest.tsv";
   $self->{'_modeltestparams'}{'outfile'} = $outfile;

   my ($temptreeFH,$temptreefile);
   if( ! ref($tree) && -e $tree ) { 
       $temptreefile = $tree;
   } else { 
       ($temptreeFH,$temptreefile) = $self->io->tempfile
	   ('-dir' => $tempdir, 
	    UNLINK => ($self->save_tempfiles ? 0 : 1));

       my $treeout = new Bio::TreeIO('-format' => 'newick',
				     '-fh'     => $temptreeFH);
       $treeout->write_tree($tree);
       $treeout->close();
       close($temptreeFH);
   }
   $self->{'_modeltestparams'}{'temptreefile'} = $temptreefile;
   $self->create_wrapper;
   $self->{_prepared} = 1;
   return $tempdir;
}

=head2 run

 Title   : run
 Usage   : my ($rc,$results) = $modeltest->run($aln);
 Function: run the modeltest analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : Return code, L<Bio::Tools::Phylo::PAML>
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]


=cut

sub run {
   my ($self,$aln,$tree) = @_;

   $self->prepare($aln,$tree) unless (defined($self->{'_prepared'}));
   my ($rc,$results) = (1);
   {
       my $commandstring;
       my $exit_status;
       my $tempdir = $self->tempdir;
       my $modeltestexe = $self->executable();
       $self->throw("unable to find or run executable for 'HYPHY'") unless $modeltestexe && -e $modeltestexe && -x _;
       $commandstring = $modeltestexe . " BASEPATH=" . $self->program_dir . " " . $self->{'_modeltestwrapper'};
       open(RUN, "$commandstring |") or $self->throw("Cannot open exe $modeltestexe");
       my @output = <RUN>;
       $exit_status = close(RUN);
       $self->error_string(join('',@output));
       if( (grep { /\berr(or)?: /io } @output)  || !$exit_status) {
	   $self->warn("There was an error - see error_string for the program output");
	   $rc = 0;
       }
       my $outfile = $self->outfile_name;
       eval {
	   open(OUTFILE, ">$outfile") or $self->throw("cannot open $outfile for writing");
           # FIXME -- needs output parsing -- ask hyphy to clean that up into a tsv?
           foreach my $output (@output) {
               print OUTFILE $output;
               $results .= sprintf($output);
           }
           close(OUTFILE);
       };
       if( $@ ) {
	   $self->warn($self->error_string);
       }
   }
   unless ( $self->save_tempfiles ) {
       unlink($self->{'_modeltestwrapper'});
      $self->cleanup();
   }
   return ($rc,$results);
}


=head2 create_wrapper

 Title   : create_wrapper
 Usage   : $self->create_wrapper
 Function: It will create the wrapper file that interfaces with the analysis bf file
 Example :
 Returns : 
 Args    :


=cut

sub create_wrapper {
   my $self = shift;

   my $tempdir = $self->tempdir;
   $self->update_ordered_parameters;
   my $modeltestwrapper = "$tempdir/Modeltestwrapper.bf";
   open(MODELTEST, ">$modeltestwrapper") or $self->throw("cannot open $modeltestwrapper for writing");

   print MODELTEST "stdinRedirect"," = ", "\{", "\};", "\n\n";
   my $counter = sprintf("%02d", 0);
   foreach my $elem (@{ $self->{'_updatedorderedmodeltestparams'} }) {
       my ($param,$val) = each %$elem;
       print MODELTEST 'stdinRedirect ["';
       print MODELTEST "$counter";
       print MODELTEST '"] = "';
       print MODELTEST "$val";
       print MODELTEST '"',";\n";
       $counter = sprintf("%02d",$counter+1);
   }
   print MODELTEST "\n",'ExecuteAFile (HYPHY_BASE_DIRECTORY + "TemplateBatchFiles" + DIRECTORY_SEPARATOR  + "ModelTest.bf", stdinRedirect);', "\n";

   close(MODELTEST);
   $self->{'_modeltestwrapper'} = $modeltestwrapper;
}


=head2 error_string

 Title   : error_string
 Usage   : $obj->error_string($newval)
 Function: Where the output from the last analysus run is stored.
 Returns : value of error_string
 Args    : newvalue (optional)


=cut

sub error_string {
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'error_string'} = $value;
    }
    return $self->{'error_string'};

}

=head2 alignment

 Title   : alignment
 Usage   : $modeltest->align($aln);
 Function: Get/Set the L<Bio::Align::AlignI> object
 Returns : L<Bio::Align::AlignI> object
 Args    : [optional] L<Bio::Align::AlignI>
 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::SimpleAlign>

=cut

sub alignment {
   my ($self,$aln) = @_;

   if( defined $aln ) { 
       if( -e $aln ) { 
	   $self->{'_alignment'} = $aln;
       } elsif( !ref($aln) || ! $aln->isa('Bio::Align::AlignI') ) { 
	   $self->warn("Must specify a valid Bio::Align::AlignI object to the alignment function not $aln");
	   return undef;
       } else {
	   $self->{'_alignment'} = $aln;
       }
   }
   return  $self->{'_alignment'};
}

=head2 tree

 Title   : tree
 Usage   : $modeltest->tree($tree, %params);
 Function: Get/Set the L<Bio::Tree::TreeI> object
 Returns : L<Bio::Tree::TreeI> 
 Args    : [optional] $tree => L<Bio::Tree::TreeI>,
           [optional] %parameters => hash of tree-specific parameters:

 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::Tree::Tree>

=cut

sub tree {
   my ($self, $tree, %params) = @_;
   if( defined $tree ) { 
       if( ! ref($tree) || ! $tree->isa('Bio::Tree::TreeI') ) { 
	   $self->warn("Must specify a valid Bio::Tree::TreeI object to the alignment function");
       }
       $self->{'_tree'} = $tree;
   }
   return $self->{'_tree'};
}

=head2 get_parameters

 Title   : get_parameters
 Usage   : my %params = $self->get_parameters();
 Function: returns the list of parameters as a hash
 Returns : associative array keyed on parameter names
 Args    : none


=cut

sub get_parameters {
   my ($self) = @_;
   # we're returning a copy of this
   return @{ $self->{'_modeltestparams'} };
}


=head2 set_parameter

 Title   : set_parameter
 Usage   : $modeltest->set_parameter($param,$val);
 Function: Sets a modeltest parameter, will be validated against
           the valid values as set in the %VALIDVALUES class variable.  
           The checks can be ignored if one turns off param checks like this:
             $modeltest->no_param_checks(1)
 Returns : boolean if set was success, if verbose is set to -1
           then no warning will be reported
 Args    : $param => name of the parameter
           $value => value to set the parameter to
 See also: L<no_param_checks()>

=cut



sub set_parameter {
   my ($self,$param,$value) = @_;

   # FIXME - add validparams checking
   $self->{'_modeltestparams'}{$param} = $value;
   return 1;
}

=head2 set_default_parameters

 Title   : set_default_parameters
 Usage   : $modeltest->set_default_parameters(0);
 Function: (Re)set the default parameters from the defaults
           (the first value in each array in the 
	    %VALIDVALUES class variable)
 Returns : none
 Args    : boolean: keep existing parameter values


=cut

sub set_default_parameters {
   my ($self,$keepold) = @_;
   $keepold = 0 unless defined $keepold;
   foreach my $elem (@VALIDVALUES) {
       my ($param,$val) = each %$elem;
       # skip if we want to keep old values and it is already set
       if (ref($val)=~/ARRAY/i ) {
           unless (ref($val->[0])=~/HASH/i) {
               push @{ $self->{'_orderedmodeltestparams'} }, {$param, $val->[0]};
           } else {
               $val = $val->[0];
           }
       } 
       if ( ref($val) =~ /HASH/i ) { 
           my $prevparam;
           while (defined($val)) {
               last unless (ref($val) =~ /HASH/i);
               last unless (defined($param));
               $prevparam = $param;
               ($param,$val) = each %{$val};
               push @{ $self->{'_orderedmodeltestparams'} }, {$prevparam, $param};
               push @{ $self->{'_orderedmodeltestparams'} }, {$param, $val} if (defined($val));
           }
       } elsif (ref($val) !~ /HASH/i && ref($val) !~ /ARRAY/i) { 
           push @{ $self->{'_orderedmodeltestparams'} }, {$param, $val};
       }
   }
}


=head2 update_ordered_parameters

 Title   : update_ordered_parameters
 Usage   : $modeltest->update_ordered_parameters(0);
 Function: (Re)set the default parameters from the defaults
           (the first value in each array in the 
	    %VALIDVALUES class variable)
 Returns : none
 Args    : boolean: keep existing parameter values


=cut

sub update_ordered_parameters {
   my ($self,$keepold) = @_;
   $keepold = 0 unless defined $keepold;
   foreach my $elem (@{$self->{'_orderedmodeltestparams'}}) {
       my ($param,$val) = each %$elem;
       my $composite_param = $param;
       # skip if we want to keep old values and it is already set
       if (ref($param) =~ /ARRAY/i ) {
           push @{ $self->{'_updatedorderedmodeltestparams'} }, {$param, $self->{_modeltestparams}{$param} || $val};
       } elsif ( ref($val) =~ /HASH/i ) { 
           while (defined($val)) {
               last unless (ref($val) =~ /HASH/i);
               my ($param,$val) = each %{$val};
               $composite_param .= $param;
           }
           push @{ $self->{'_updatedorderedmodeltestparams'} }, {$param, $self->{_modeltestparams}{$composite_param} || $val};
       } else { 
           push @{ $self->{'_updatedorderedmodeltestparams'} }, {$param, $self->{_modeltestparams}{$param} || $val};
       }
   }
}


=head1 Bio::Tools::Run::WrapperBase methods

=cut

=head2 no_param_checks

 Title   : no_param_checks
 Usage   : $obj->no_param_checks($newval)
 Function: Boolean flag as to whether or not we should
           trust the sanity checks for parameter values  
 Returns : value of no_param_checks
 Args    : newvalue (optional)


=cut

sub no_param_checks {
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'no_param_checks'} = $value;
    }
    return $self->{'no_param_checks'};
}


=head2 save_tempfiles

 Title   : save_tempfiles
 Usage   : $obj->save_tempfiles($newval)
 Function: 
 Returns : value of save_tempfiles
 Args    : newvalue (optional)


=cut

=head2 outfile_name

 Title   : outfile_name
 Usage   : my $outfile = $modeltest->outfile_name();
 Function: Get/Set the name of the output file for this run
           (if you wanted to do something special)
 Returns : string
 Args    : [optional] string to set value to


=cut

sub outfile_name {
    my $self = shift;
    if( @_ ) {
	return $self->{'_modeltestparams'}->{'outfile'} = shift @_;
    }
    return $self->{'_modeltestparams'}->{'outfile'};
}

=head2 tempdir

 Title   : tempdir
 Usage   : my $tmpdir = $self->tempdir();
 Function: Retrieve a temporary directory name (which is created)
 Returns : string which is the name of the temporary directory
 Args    : none


=cut

=head2 cleanup

 Title   : cleanup
 Usage   : $modeltest->cleanup();
 Function: Will cleanup the tempdir directory after a PAML run
 Returns : none
 Args    : none


=cut

=head2 io

 Title   : io
 Usage   : $obj->io($newval)
 Function:  Gets a L<Bio::Root::IO> object
 Returns : L<Bio::Root::IO>
 Args    : none


=cut

sub DESTROY {
    my $self= shift;
    unless ( $self->save_tempfiles ) {
	$self->cleanup();
    }
    $self->SUPER::DESTROY();
}

1;
