# Wrapper  module for SignalP Bio::Tools::Run::Signalp
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Signalp
# originally written by Marc Sohrmann (ms2@sanger.ac.uk)
# Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 NAME

Bio::Tools::Run::Signalp

=head1 SYNOPSIS

  Build a Signalp factory

  my $factory = Bio::Tools::Run::Signalp->new();
  # Pass the factory a Bio::Seq object
  # @feats is an array of Bio::SeqFeature::Generic objects
  my @feats = $factory->predict_protein_features($seq);

=head1 DESCRIPTION

  wrapper module for Signalp program

=head1 FEEDBACK

=head2 Mailing Lists

 User feedback is an integral part of the evolution of this and other
 Bioperl modules. Send your comments and suggestions preferably to one
 of the Bioperl mailing lists.  Your participation is much appreciated.

 bioperl-l@bioperl.org          - General discussion
 http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

 Report bugs to the Bioperl bug tracking system to help us keep track
 the bugs and their resolution.  Bug reports can be submitted via
 email or the web:

 bioperl-bugs@bioperl.org
 http://bugzilla.bioperl.org/

=head1 AUTHOR

 Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Signalp
 originally written by Marc Sohrmann (ms2@sanger.ac.uk)
 Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
 Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 APPENDIX

 The rest of the documentation details each of the object
 methods. Internal methods are usually preceded with a _

=cut

package Bio::Tools::Run::Signalp;

use vars qw($AUTOLOAD @ISA $PROGRAM  $PROGRAMDIR
            $TMPDIR $PROGRAMNAME @SIGNALP_PARAMS
                         %OK_FIELD);
use strict;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Factory::ApplicationFactoryI;
use Bio::Tools::Signalp;
use Bio::Tools::Run::WrapperBase;

@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);




BEGIN {
       $PROGRAMNAME = 'signalp'  . ($^O =~ /mswin/i ?'.exe':'');

       if (defined $ENV{SIGNALPDIR}) {
          $PROGRAMDIR = $ENV{SIGNALPDIR} || '';
          $PROGRAM = Bio::Root::IO->catfile($PROGRAMDIR,
                                           'signalp'.($^O =~ /mswin/i ?'.exe':''));
       }
       else {
          $PROGRAM = 'signalp';
       }
       @SIGNALP_PARAMS=qw(PROGRAM VERBOSE);
       foreach my $attr ( @SIGNALP_PARAMS)
                        { $OK_FIELD{$attr}++; }
}

sub AUTOLOAD {
       my $self = shift;
       my $attr = $AUTOLOAD;
       $attr =~ s/.*:://;
       $attr = uc $attr;
       $self->throw("Unallowed parameter: $attr !") unless $OK_FIELD{$attr};
       $self->{$attr} = shift if @_;
       return $self->{$attr};
}

=head2 new

 Title   : new
 Usage   : my $factory= Bio::Tools::Run::Signalp->new();
 Function: creates a new Signalp factory
 Returns:  Bio::Tools::Run::Signalp
 Args    :

=cut

sub new {
       my ($class,@args) = @_;
       my $self = $class->SUPER::new(@args);
       $self->io->_initialize_io();
 
       my ($attr, $value);
       while (@args)  {
           $attr =   shift @args;
           $value =  shift @args;
           next if( $attr =~ /^-/ ); # don't want named parameters
           if ($attr =~/PROGRAM/i) {
              $self->executable($value);
              next;
           }
           $self->$attr($value);
       }
       return $self;
}


=head2 executable

 Title   : executable
 Usage   : my $exe = $signalp->executable();
 Function: Finds the full path to the Signalp executable
 Returns : string representing the full path to the exe
 Args    : [optional] name of executable to set path to
          [optional] boolean flag whether or not warn when exe is not found

=cut

sub executable{
    my ($self, $exe,$warn) = @_;

    if( defined $exe ) {
        $self->{'_pathtoexe'} = $exe;
    }

    unless( defined $self->{'_pathtoexe'} ) {
        if( $PROGRAM && -e $PROGRAM && -x $PROGRAM ) {
            $self->{'_pathtoexe'} = $PROGRAM;
        } else {
            my $exe;
            if( ( $exe = $self->io->exists_exe($PROGRAMNAME) ) &&
                -x $exe ) {
                  $self->{'_pathtoexe'} = $exe;
            } else {
              $self->warn("Cannot find executable for $PROGRAMNAME") if $warn;
              $self->{'_pathtoexe'} = undef;
            }
        }
    }
      $self->{'_pathtoexe'};
}

=head2 predict_protein_features

 Title   :   predict_protein_features()
 Usage   :   my $feats = $factory->predict_protein_features($seqFile)
 Function:   Runs Signalp and creates an array of featrues
 Returns :   An array of Bio::SeqFeature::Generic objects
 Args    :   A Bio::PrimarySeqI

=cut

sub predict_protein_features{
    my ($self,$seq) = @_;
    my @feats;
        
     if (ref($seq) ) {

        if (ref($seq) =~ /GLOB/) {
            $self->throw("cannot use filehandle");
        } 
        
       if ($seq->length>50){
           
         my $sub_seq = $seq->subseq(1, 50);
         $seq->seq($sub_seq);
       }
       my $infile1 = $self->_writeSeqFile($seq);
        
       $self->_input($infile1);
        
       @feats = $self->_run();
       unlink $infile1;
       
    }
    else {
        #The clone object is not a seq object but a file.
        #Perhaps should check here or before if this file is fasta format...if not die
        #Here the file does not need to be created or deleted. Its already written and may be used by other runnables.

         my $in  = Bio::SeqIO->new(-file => $seq, '-format' =>'Fasta');
         my $infile1;  

         while ( my $tmpseq = $in->next_seq() ) {
               my $sub_seq = $tmpseq->subseq(1,40);

               $tmpseq->seq($sub_seq);
               $infile1 = $self->_writeSeqFile($tmpseq);  
        
         } 
           
       
         $self->_input($infile1);

         @feats = $self->_run();
        
    }
   
    return @feats;

}

=head2 _input

 Title   :   _input
 Usage   :   $factory->_input($seqFile)
 Function:   get/set for input file
 Returns :
 Args    :

=cut

sub _input() {
     my ($self,$infile1) = @_;
     if(defined $infile1){
    
        $self->{'input'}=$infile1;
     }

     return $self->{'input'};
}

=head2 _run

 Title   :   _run
 Usage   :   $factory->_run()
 Function:   Makes a system call and runs signalp
 Returns :   An array of Bio::SeqFeature::Generic objects
 Args    :

=cut

sub _run {
     my ($self)= @_;
     
     my ($tfh1,$outfile) = $self->io->tempfile(-dir=>$self->tempdir());
      my $str =$self->executable." -t euk ".$self->{'input'}." > ".$outfile;
     my $status = system($str);
     $self->throw( "Signalp call ($str) crashed: $? \n") unless $status==0;
     
     my $filehandle;
     if (ref ($outfile) !~ /GLOB/) {
        open (SIGNALP, "<".$outfile) or $self->throw ("Couldn't open file ".$outfile.": $!\n");
        $filehandle = \*SIGNALP;
     }
     else {
        $filehandle = $outfile;
     }

     my $signalp_parser = Bio::Tools::Signalp->new(-fh=>$filehandle);

     my @signalp_feat;

    while(my $signalp_feat = $signalp_parser->next_result){

        push @signalp_feat, $signalp_feat;
    }
     
     
     $self->cleanup();
     
     unlink $outfile;
     
     return @signalp_feat;

}


=head2 _writeSeqFile

 Title   :   _writeSeqFile
 Usage   :   $factory->_writeSeqFile($seq)
 Function:   Creates a file from the given seq object
 Returns :   A string(filename)
 Args    :   Bio::PrimarySeqI

=cut

sub _writeSeqFile{
    my ($self,$seq) = @_;
    my ($tfh,$inputfile) = $self->io->tempfile(-dir=>$self->tempdir());
    my $in  = Bio::SeqIO->new(-fh => $tfh , '-format' => 'Fasta');
    $in->write_seq($seq);

    return $inputfile;

}
1;