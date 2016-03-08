#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::Log;

#use File::Spec::Functions qw(catdir);

use CoGe::Accessory::Web qw(get_defaults);
print STDERR '=' x 80, "\n== CoGe API\n", '=' x 80, "\n";
print STDERR "Home path: ", get_defaults->{_HOME_PATH}, "\n";
print STDERR "Config file: ", get_defaults->{_CONFIG_PATH}, "\n";
print STDERR "Include paths: ", qq(@INC), "\n";

# Set port -- each sandbox should be set to a unique port in Apache config and coge.conf
my $port = get_defaults->{MOJOLICIOUS_PORT} || 3303;
print STDERR "Port: $port\n";

# Setup Hypnotoad
app->config(
    hypnotoad => {
        listen => ["http://localhost:$port/"],
        pid_file => get_defaults->{_HOME_PATH},
        proxy => 1,
        heartbeat_timeout => 15, # number of seconds before restarting unresponsive worker (needed for large JBrowse requests)
    }
);
#app->log( Mojo::Log->new( path => catdir(get_defaults->{_HOME_PATH}, 'mojo.log'), level => 'debug' ) ); # log in sandbox top-level directory
app->log( Mojo::Log->new( ) ); # log to STDERR

# mdb added 8/27/15 -- prevent "Your secret passphrase needs to be changed" message
app->secrets('coge'); # it's okay to have this secret in the code (rather the config file) because we don't use signed cookies

# Instantiate router
my $r = app->routes->namespaces(["CoGe::Services::API::JBrowse", "CoGe::Services::API"]);

# TODO: Authenticate user here instead of redundantly in each submodule
#    my $app = $self;
#    $self->hook(before_dispatch => sub {
#        my $c = shift;
#        # Authenticate user and connect to the database
#        my ($db, $user, $conf) = CoGe::Services::Auth::init($app);
#        $c->stash(db => $db, user => $user, conf => $conf);
#    });
    
# Global Search routes
$r->get("/global/search/#term")
    ->name("global-search")
    ->to("search#search", term => undef);

# Organism routes
$r->get("/organisms/search/#term")
    ->name("organisms-search")
    ->to("organism#search", term => undef);

$r->get("/organisms/:id" => [id => qr/\d+/])
    ->name("organisms-fetch")
    ->to("organism#fetch", id => undef);

$r->put("/organisms")
    ->name("organisms-add")
    ->to("organism#add");

# Genome routes
$r->get("/genomes/search/#term")
    ->name("genomes-search")
    ->to("genome#search", namespace => 'CoGe::Services::API', term => undef);

$r->get("/genomes/:id" => [id => qr/\d+/])
    ->name("genomes-fetch")
    ->to("genome#fetch", namespace => 'CoGe::Services::API', id => undef);
    
$r->get("/genomes/:id/sequence" => [id => qr/\d+/])
    ->name("genomes-sequence")
    ->to("genome#sequence", namespace => 'CoGe::Services::API', id => undef);
    
$r->get("/genomes/:id/sequence/:chr" => { id => qr/\d+/, chr => qr/\w+/ }) # can this be merged with above using regex?
    ->name("genomes-sequence-chr")
    ->to("genome#sequence", namespace => 'CoGe::Services::API', id => undef, chr => undef);   
    
$r->put("/genomes")
    ->name("genomes-add")
    ->to("genome#add", namespace => 'CoGe::Services::API');

# Dataset routes
#$r->get("/genomes/search/#term")
#    ->name("genomes-search")
#    ->to("genome#search", term => undef);

$r->get("/datasets/:id" => [id => qr/\d+/])
    ->name("datasets-fetch")
    ->to("dataset#fetch", id => undef);

$r->get("/datasets/:id/genomes" => [id => qr/\d+/])
    ->name("datasets-genomes")
    ->to("dataset#genomes", id => undef);

# Feature routes
$r->get("/features/search/#term")
    ->name("features-search")
    ->to("feature#search", term => undef);
    
$r->get("/features/:id" => [id => qr/\d+/])
    ->name("features-fetch")
    ->to("feature#fetch", id => undef);
    
$r->get("/features/sequence/:id" => [id => qr/\d+/])
    ->name("features-sequence")
    ->to("feature#sequence", id => undef);

# Experiment routes
$r->get("/experiments/search/#term")
    ->name("experiments-search")
    ->to("experiment#search", namespace => 'CoGe::Services::API', term => undef);

$r->get("/experiments/:id" => [id => qr/\d+/])
    ->name("experiments-fetch")
    ->to("experiment#fetch", namespace => 'CoGe::Services::API', id => undef);

$r->put("/experiments")
    ->name("experiments-add")
    ->to("experiment#add", namespace => 'CoGe::Services::API');

# Notebook routes
$r->get("/notebooks/search/#term")
    ->name("notebooks-search")
    ->to("notebook#search", term => undef);

$r->get("/notebooks/:id" => [id => qr/\d+/])
    ->name("notebooks-fetch")
    ->to("notebook#fetch", id => undef);
    
$r->put("/notebooks")
    ->name("notebooks-add")
    ->to("notebook#add");
    
$r->delete("/notebooks/:id" => [id => qr/\d+/])
    ->name("notebooks-remove")
    ->to("notebook#remove");

# User routes -- not documented, only for internal use
$r->get("/users/search/#term")
    ->name("users-search")
    ->to("user#search", term => undef);

#$r->get("/users/:id" => [id => qr/\w+/])
#    ->name("users-fetch")
#    ->to("user#fetch", id => undef);

$r->get("/users/:id/items" => [id => qr/\w+/])
    ->name("users-items")
    ->to("user#items", id => undef);

# User group routes
$r->get("/groups/search/#term")
    ->name("groups-search")
    ->to("group#search", term => undef);

$r->get("/groups/:id" => [id => qr/\d+/])
    ->name("groups-fetch")
    ->to("group#fetch", id => undef);

$r->get("/groups/:id/items" => [id => qr/\d+/])
    ->name("groups-items")
    ->to("group#items", id => undef);

# Job routes
$r->put("/jobs")
    ->name("jobs-add")
    ->to("job#add");

$r->get("/jobs/:id" => [id => qr/\d+/])
    ->name("jobs-fetch")
    ->to("job#fetch", id => undef);

$r->get("/jobs/:id/results/:name" => { id => qr/\d+/, name => qr/\w+/ })
    ->name("jobs-results")
    ->to("job#results", id => undef, name => undef);

# Log routes -- not documented, only for internal use
#$r->get("/logs/search/#term")
#    ->name("logs-search")
#    ->to("log#search", term => undef);
        
$r->get("/logs/:type/:id" => [type => qr/\w+/, id => qr/\d+/])
    ->name("logs-fetch")
    ->to("log#fetch", id => undef, type => undef);

# IRODS routes
$r->get("/irods/list/")
    ->name("irods-list")
    ->to("IRODS#list");
    
$r->get("/irods/list/(*path)")
    ->name("irods-list")
    ->to("IRODS#list");
        
# mdb removed 8/24/15 -- not used
#$r->get("/irods/fetch/(*path)")
#    ->name("irods-fetch")
#    ->to("IRODS#fetch");

# FTP routes
$r->get("/ftp/list/")
    ->name("ftp-list")
    ->to("FTP#list");

# JBrowse configuration routes
$r->get("/jbrowse/config/refseq")
    ->name("jbrowse-configuration-refseq")
    ->to("configuration#refseq_config");
    
$r->get("/jbrowse/config/tracks")
    ->name("jbrowse-configuration-tracks")
    ->to("configuration#track_config");    

# JBrowse sequence route
$r->get("/jbrowse/sequence/:id/features/:chr" => { id => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-sequence")
    ->to("sequence#features", id => undef, chr => undef);

# JBrowse annotation routes
$r->get("/jbrowse/track/annotation/:gid/stats/global/" => [gid => qr/\d+/])
    ->name("jbrowse-annotation-stats-global")
    ->to("annotation#stats_global", gid => undef); 

$r->get("/jbrowse/track/annotation/:gid/features/:chr" => { gid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-annotation-features")
    ->to("annotation#features", gid => undef, chr => undef);
    
$r->get("/jbrowse/track/annotation/:gid/types/:type/stats/global/" => { gid => qr/\d+/, type => qr/\w+/ }) # can this be combined with overall using regex?
    ->name("jbrowse-annotation-types-stats-global")
    ->to("annotation#stats_global", gid => undef, type => undef);     
    
$r->get("/jbrowse/track/annotation/:gid/types/:type/features/:chr" => { gid => qr/\d+/, chr => qr/\w+/, type => qr/\w+/ }) # can this be combined with overall using regex?
    ->name("jbrowse-annotation-types-features")
    ->to("annotation#features", gid => undef, chr => undef, type => undef); 

$r->get("/jbrowse/track/gc/:gid/stats/global/" => [gid => qr/\d+/])
    ->name("jbrowse-gccontent-stats-global")
    ->to("GCcontent#stats_global", gid => undef); 

$r->get("/jbrowse/track/gc/:id/features/:chr" => { id => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-gccontent-features")
    ->to("GCcontent#features", id => undef, chr => undef);  

# JBrowse experiment routes
$r->get("/jbrowse/experiment/:eid/stats/global/" => [eid => qr/\d+/])
    ->name("jbrowse-experiment-stats-global")
    ->to("experiment#stats_global", eid => undef);
    
$r->get("/jbrowse/experiment/:eid/stats/regionFeatureDensities/:chr" => { eid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-experiment-regionFeatureDensitites")
    ->to("experiment#stats_regionFeatureDensities", eid => undef, chr => undef);

$r->get("/jbrowse/experiment/:eid/features/:chr"  => { eid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-experiment-features")
    ->to("experiment#features", eid => undef, chr => undef);

$r->get("/jbrowse/experiment/:eid/snps/:chr"  => { eid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-experiment-snps")
    ->to("experiment#snps", eid => undef, chr => undef);

# Is there a way to combine these 3 notebook routes with the 3 experiment routes above using regex?
$r->get("/jbrowse/experiment/notebook/:nid/stats/global/" => [nid => qr/\d+/])
    ->name("jbrowse-experiment-stats-global")
    ->to("experiment#stats_global", nid => undef);
    
$r->get("/jbrowse/experiment/notebook/:nid/stats/regionFeatureDensities/:chr" => { nid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-experiment-regionFeatureDensitites")
    ->to("experiment#stats_regionFeatureDensities", nid => undef, chr => undef);

$r->get("/jbrowse/experiment/notebook/:nid/features/:chr"  => { nid => qr/\d+/, chr => qr/\w+/ })
    ->name("jbrowse-experiment-features")
    ->to("experiment#features", nid => undef, chr => undef);

# JBrowse genome routes
$r->get("/jbrowse/genome/:gid/genes/"  => [gid => qr/\d+/])
    ->name("jbrowse-genome-genes")
    ->to("genome#genes", gid => undef);

$r->get("/jbrowse/genome/:gid/features/"  => [gid => qr/\d+/])
    ->name("jbrowse-genome-features")
    ->to("genome#features", gid => undef);

# Not found
$r->any("*" => sub {
    my $c = shift;
    $c->render(status => 404, json => { error => {Error => "Resource not found" }});
});

app->start;