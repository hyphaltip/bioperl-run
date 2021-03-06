use strict;

BEGIN {
    use Bio::Root::Test;
    test_begin(-tests => 91,
	       -requires_modules => [qw(Bio::Tools::Run::Cap3)]);
    use_ok('Bio::SeqIO');
}


my $assembler;
ok($assembler = Bio::Tools::Run::Cap3->new());
isa_ok($assembler, 'Bio::Tools::Run::Cap3');

ok($assembler->program_name('aaa'));
is($assembler->program_name, 'aaa');

ok($assembler->program_dir('/dir'));
is($assembler->program_dir, '/dir');

my @params = @Bio::Tools::Run::Cap3::program_params;
for my $param (@params) {
  ok($assembler->$param(321));
  is($assembler->$param(), 321);
}

my @switches = @Bio::Tools::Run::Cap3::program_switches;
for my $switch (@switches) {
  ok($assembler->$switch(1));
  is($assembler->$switch(), 1);
}

# test the program itself
my $program_name = $Bio::Tools::Run::Cap3::program_name;
ok($assembler->program_name($program_name));
SKIP: {
    test_skip(-requires_executable => $assembler,
              -tests => 41);

   # Input data
   my $result_file = 'results.ace';
   my $fasta_file = test_input_file('sample_dataset_1.fa');
   my $qual_file  = test_input_file('sample_dataset_1.qual');
   my $io = Bio::SeqIO->new( -file => $fasta_file, -format => 'fasta' );
   my @seq_arr;
   while (my $seq = $io->next_seq) {
      push @seq_arr, $seq;
   }
   $io = Bio::SeqIO->new( -file => $qual_file, -format => 'qual' );
   my @qual_arr;
   while (my $qual = $io->next_seq) {
      push @qual_arr, $qual;
   }

   my $asm;
   ok($assembler = Bio::Tools::Run::Cap3->new());

   # Try FASTA or sequence object input
   ok($asm = $assembler->run($fasta_file));
   isa_ok($asm, 'Bio::Assembly::ScaffoldI');
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 3);

   ok($asm = $assembler->run(\@seq_arr));
   isa_ok($asm, 'Bio::Assembly::ScaffoldI');
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 3);

   # Try optional quality score input as a QUAL file or bioperl objects
   ok($asm = $assembler->run($fasta_file, $qual_file));
   isa_ok($asm, 'Bio::Assembly::ScaffoldI');
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 3);

   ok($asm = $assembler->run(\@seq_arr, \@qual_arr));
   isa_ok($asm, 'Bio::Assembly::ScaffoldI');
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 3);

   # Try the different output types
   ok($assembler->out_type($result_file));
   ok($asm = $assembler->run(\@seq_arr));
   ok($asm eq $result_file);
   is((-f $asm), 1);
   unlink $result_file;

   ok($assembler->out_type('Bio::Assembly::IO'));
   ok($asm = $assembler->run(\@seq_arr));
   isa_ok($asm, 'Bio::Assembly::IO');
   ok($asm->next_assembly);

   ok($assembler->out_type('Bio::Assembly::ScaffoldI'));
   ok($asm = $assembler->run(\@seq_arr));
   isa_ok($asm, 'Bio::Assembly::ScaffoldI');
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 3);

   # Try some Cap3 specific parameters
   ok($assembler->overlap_length_cutoff(1000));
   ok($asm = $assembler->run(\@seq_arr));
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 0);

   ok($assembler->overlap_length_cutoff(21));
   ok($assembler->overlap_identity_cutoff(100));
   ok($asm = $assembler->run(\@seq_arr));
   is($asm->get_nof_singlets, 0);
   is($asm->get_nof_contigs, 0);

   # Function alias
   ok($assembler->minimum_overlap_similarity(100));
   ok($assembler->minimum_overlap_length(20));
}
