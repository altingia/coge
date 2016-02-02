package CoGe::Builder::Protein::ChIPseq;

use v5.14;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use File::Basename;
use File::Spec::Functions qw(catdir catfile);
use CoGe::Accessory::Utils qw(to_filename to_filename_without_extension);
use CoGe::Accessory::Web qw(get_defaults);
use CoGe::Accessory::Workflow;
use CoGe::Core::Storage qw(get_genome_file get_workflow_paths);
use CoGe::Core::Metadata qw(to_annotations);
use CoGe::Builder::CommonTasks;

our $CONF = CoGe::Accessory::Web::get_defaults();

BEGIN {
    use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK);
    require Exporter;

    $VERSION = 0.1;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(build);
}

sub build {
    my $opts = shift;
    my $genome = $opts->{genome};
    my $user = $opts->{user};
    my $input_files = $opts->{input_files}; # path to input bam files
    my $metadata = $opts->{metadata};
    my $additional_metadata = $opts->{additional_metadata};
    my $wid = $opts->{wid};
    my $chipseq_params = $opts->{chipseq_params};
    
    # Require 3 data files (input and two replicates)
    if (@$input_files != 3) {
        print STDERR "CoGe::Builder::Protein::ChIPseq ERROR: 3 input files required\n";
        return;
    }

    # Setup paths
    my ($staging_dir, $result_dir) = get_workflow_paths($user->name, $wid);

    # Set metadata for the pipeline being used
#    my $annotations = generate_additional_metadata($read_params, $methylation_params);
#    my @annotations2 = CoGe::Core::Metadata::to_annotations($additional_metadata);
#    push @$annotations, @annotations2;

    # Determine which bam file corresponds to the input vs. the replicates
    my $input_base = fileparse($chipseq_params->{input}, '\..*');
    my ($input_file, @replicates);
    foreach my $file (@$input_files) {
        my ($basename) = fileparse($file, '\..*');
        if ($basename eq $input_base) {
            $input_file = $file;
        }
        else {
            push @replicates, $file;
        }
    }

    #
    # Build the workflow
    #
    my (@tasks, @done_files);

    foreach my $bam_file (@$input_files) {
        my $bamToBed_task = create_bamToBed_job( 
            bam_file => $bam_file,
            staging_dir => $staging_dir
        );
        push @tasks, $bamToBed_task;
        
        my $makeTagDir_task = create_homer_makeTagDirectory_job(
            bed_file => $bamToBed_task->{outputs}[0],
            gid => $genome->id,
            staging_dir => $staging_dir,
            params => $chipseq_params
        );
        push @tasks, $makeTagDir_task;
    }
    
    foreach my $replicate (@replicates) {
        my ($input_tag) = fileparse($input_file, '\..*');
        my ($replicate_tag) = fileparse($replicate, '\..*');
        
        my $findPeaks_task = create_homer_findPeaks_job(
            input_dir => catdir($staging_dir, $input_tag),
            replicate_dir => catdir($staging_dir, $replicate_tag),
            staging_dir => $staging_dir,
            params => $chipseq_params
        );
        push @tasks, $findPeaks_task;
        
        my $convert_task = create_convert_homer_to_csv_job(
            input_file => $findPeaks_task->{outputs}[0],
            staging_dir => $staging_dir
        );
        push @tasks, $convert_task;
        
        push @tasks, create_load_experiment_job(
            user => $user,
            metadata => $metadata,
            staging_dir => $staging_dir,
            wid => $wid,
            gid => $genome->id,
            input_file => $convert_task->{outputs}[0],
            name => $replicate_tag,
            normalize => 'percentage',
            #annotations => $annotations
        );
    }

    return {
        tasks => \@tasks,
        done_files => \@done_files
    };
}

sub generate_additional_metadata {
#    my $read_params = shift;
#    my $methylation_params = shift;
#    
#    my @annotations;
#    push @annotations, qq{https://genomevolution.org/wiki/index.php/Expression_Analysis_Pipeline||note|Generated by CoGe's RNAseq Analysis Pipeline};
#    
#    if ($methylation_params->{method} eq 'bismark') {
#        if ($methylation_params->{'bismark-deduplicate'}) {
#            if ($read_params->{'read_type'} eq 'paired') {
#                push @annotations, 'note|deduplicate_bismark -p';
#                push @annotations, 'note|bismark_methylation_extractor ' . join(' ', map { $_.' '.$methylation_params->{$_} } ('--ignore', '--ignore_r2', '--ignore_3prime', '--ignore_3prime_r2'));
#            }
#            else {
#                push @annotations, 'note|deduplicate_bismark -s';
#                push @annotations, 'note|bismark_methylation_extractor ' . join(' ', map { $_.' '.$methylation_params->{$_} } ('--ignore', '--ignore_3prime'));
#            }
#        }
#    }
#    elsif ($methylation_params->{method} eq 'bwameth') {
#        push @annotations, 'note|picard MarkDuplicates REMOVE_DUPLICATES=true ' if ($methylation_params->{'bismark-deduplicate'});
#        #push @annotations, 'note|PileOMeth mbias --CHG --CHH' if ($methylation_params->{'bismark-deduplicate'});
#        push @annotations, 'note|PileOMeth extract --CHG --CHH ' . join(' ', map { $_.' '.$methylation_params->{$_} } ('-q', '--OT', '--OB'));
#    }
#    
#    return \@annotations;
}

sub create_bamToBed_job {
    my %opts = @_;
    my $bam_file    = $opts{bam_file};
    my $staging_dir = $opts{staging_dir};
    
    my $cmd = $CONF->{BAMTOBED} || 'bamToBed';
    
    my $name = to_filename_without_extension($bam_file);
    my $bed_file = catfile($staging_dir, $name . '.bed');
    my $done_file = $bed_file . '.done';
    
    return {
        cmd => "$cmd -i $bam_file > $bed_file ; touch $done_file",
        script => undef,
        args => [],
        inputs => [
            $bam_file
        ],
        outputs => [
            $bed_file,
            $done_file
        ],
        description => "Converting $name to BED format..."
    };
}

sub create_homer_makeTagDirectory_job {
    my %opts = @_;
    my $bed_file    = $opts{bed_file};
    my $gid         = $opts{gid};
    my $staging_dir = $opts{staging_dir};
    my $params = $opts{params} // {};
    my $size   = $params->{'-size'} // 250;
    
    die "ERROR: HOMER_DIR is not in the config." unless $CONF->{HOMER_DIR};
    my $cmd = catfile($CONF->{HOMER_DIR}, 'makeTagDirectory');
    
    my ($tag_name) = fileparse($bed_file, '\..*');
    
    my $fasta = catfile($CONF->{CACHEDIR}, $gid, 'fasta', 'genome.faa.reheader.faa'); #TODO move into function in Storage.pm
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['', $tag_name, 0],
            ['', $bed_file, 0],
            ['-fragLength', $size, 0],
            ['-format', 'bed', 0],
            ['-genome', $fasta, 0],
            ['-checkGC', '', 0]
        ],
        inputs => [
            $bed_file,
            $bed_file . '.done',
            $fasta
        ],
        outputs => [
            [catfile($staging_dir, $tag_name), 1]
        ],
        description => "Creating tag directory '$tag_name' using Homer..."
    };
}

sub create_homer_findPeaks_job {
    my %opts = @_;
    my $replicate_dir = $opts{replicate_dir};
    my $input_dir     = $opts{input_dir};
    my $staging_dir   = $opts{staging_dir};
    my $params = $opts{params} // {};
    my $size   = $params->{'-size'} // 250;
    my $gsize  = $params->{'-gsize'} // 3000000000;
    my $norm   = $params->{'-norm'} // 1e8;
    my $fdr    = $params->{'-fdr'} // 0.01;
    my $F      = $params->{'-F'} // 3;
    
    die "ERROR: HOMER_DIR is not in the config." unless $CONF->{HOMER_DIR};
    my $cmd = catfile($CONF->{HOMER_DIR}, 'findPeaks');
    
    my ($replicate_tag) = fileparse($replicate_dir, '\..*');
    
    my $output_file = "homer_peaks_$replicate_tag.txt";
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['', $replicate_dir, 0],
            ['-i', $input_dir, 0],
            ['-style', 'factor', 0],
            ['-o', $output_file, 0],
            ['-size', $size, 0],
            ['-gsize', $gsize, 0],
            ['-norm', $norm, 0],
            ['-fdr', $fdr, 0],
            ['-F', $F, 0]
        ],
        inputs => [
            [$replicate_dir, 1],
            [$input_dir, 1]
        ],
        outputs => [
            catfile($staging_dir, $output_file),
        ],
        description => "Performing ChIP-seq analysis on $replicate_tag using Homer..."
    };
}

sub create_convert_homer_to_csv_job {
    my %opts = @_;
    my $input_file = $opts{input_file};
    my $staging_dir = $opts{staging_dir};
    
    die "ERROR: SCRIPTDIR not specified in config" unless $CONF->{SCRIPTDIR};
    my $cmd = catfile($CONF->{SCRIPTDIR}, 'chipseq', 'homer_peaks_to_csv.pl');
    
    my $name = to_filename_without_extension($input_file);
    my $output_file = catfile($staging_dir, $name . '.csv');
    my $done_file = $output_file . '.done';
    
    return {
        cmd => "$cmd $input_file > $output_file ; touch $done_file",
        script => undef,
        args => [],
        inputs => [
            $input_file
        ],
        outputs => [
            $output_file,
            $done_file
        ],
        description => "Converting $name to CSV format..."
    };
}

1;