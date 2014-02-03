#! /usr/bin/perl

package Wordpress;

use LWP::Simple; 
use Digest::MD5 qw/md5_hex/;
use Data::Dumper;
use File::Temp qw/tempfile/;
use Term::ANSIColor;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA    = qw/Exporter/;
@EXPORT = qw/documentRoot checkFiles fullPath catFile cleanFile sqlShellCmd setVersion installWordpress diffFile/;

use constant PHP => "/usr/bin/php";
use constant WPSUMS_WORDPRESSES_URL => "http://wpsums.avi.co/wordpresses/";
use constant MD5SUMS_FILE => "md5sums.txt";
use constant DIFF => "/usr/bin/diff";
use constant DIFF_OPTS => "";

my $wpFiles = {
	version => "wp-includes/version.php",
	config  => "wp-config.php",
};
my $versions = {} ;
my $wp_version;
my $dir;

# Running getVersion sets the $versions and $dir variables
# for the module.
sub documentRoot{
	$dir = shift;
	my $file = $dir."/".$wpFiles->{'version'};
	open(my $fh, "<", $file) or die ("Error opening WP version file $file");
	while(my $line = readline($fh)){
		if($line =~ /^\s*\$(\S+)\s*=\s*('|")?([\d\.]+)('|")?;\s*$/g){
			$versions->{$1} = $3;
		}
	}
	$wp_version = $versions->{'wp_version'};
	return $versions;
}
sub setVersion{
	$wp_version = shift;
	return $wp_version;
}

sub getMd5Sums{
	my $url = _getUrl(MD5SUMS_FILE);
	die('$wp_version not set') unless $wp_version =~ /.+/;
	my $sums = {};
	my $list = get($url);
	foreach my $line (split(/\n+/, $list)){
		chomp $line;
		my($hash,$path) = split(/\s+\.\//, $line);
		$sums->{$path} = $hash;
	}
	return $sums;
}

sub checkFiles{
	my $dir = shift;
	my $sums = getMd5Sums();
	my $differences = {};
	my $absences;
	foreach my $file (keys(%{$sums})){
		my $sum = $sums->{$file};
		my $file_absolute = fullPath($file);
		if(! -f $file_absolute){
			$absences->{$file}++;
			next;
		}
		my @sums = fileHasChanged($file_absolute, $sum);
		if($sums[1]){
			$differences->{$file} = \@sums;
		}
	}
	return $differences, $absences;
}

# this doesn't work yet.
sub installWordpress{
	$dir = shift;
	my $sums = getMd5Sums();
	my $count = 0;
	foreach my $file(keys(%$sums)){
		$count++;
		my $fullPath = fullPath($file);
		my $url = _getUrl($file);
		print "$url -> $fullPath\n";
		my $status = getstore($url, $fullPath);
		if (is_error($status)){
			_warn("Failed to download '$url' ($status)");
		}
	}
	my($differences, $absences) = checkFiles($dir);
	if(defined($differences) || defined ($absences)){
		_error("Something went wrong. Try running a check on the dir");
	}
	return $count;
}

sub fileHasChanged{
	my $file = shift;
	my $checksum= shift;
	my $actualsum = md5sum($file);
	unless($checksum eq $actualsum){
		return $checksum, $actualsum;
	}
	return;
}

sub md5sum{
	my $file = shift;
#	open(my $fh, "<", $file) or return;
#	my $data = <$fh>;
#	close($fh);
#	return md5_hex($data);
	return (split(/\s+/, `md5sum $file`))[0];

}

sub _getUrl{
	my $file = shift;
	return WPSUMS_WORDPRESSES_URL.$wp_version."/".$file;
}


sub catFile{
	my $file = shift;
	open(my $fh, "<", $file) or return $!;
	my @file = <$fh>;
	close($fh);
	return join("", @file);
}

sub fullPath{
	my $relative = shift;
	my $fullPath = $dir."/".$relative;
	$fullPath =~ s#//#/#g;
	$fullPath =~ s#/./#/#;
	return $fullPath;
}

sub downloadFile{
	my $url = shift;
	my $path = shift;
	my $status = getstore($url, $path);
	if(is_error($status)){
		print STDERR "Download failed [$status]\n";
		return;
	}
	return $path;
}

sub diffFile{
	my $file = shift;
	my $fullPath = fullPath($file);
  my $url = _getUrl($file);
	my ($fh_tmp, $f_tmp) = tempfile();
	downloadFile($url, $f_tmp);
	my $cmd = join(" ", DIFF, DIFF_OPTS, $f_tmp, $fullPath);
	my @lines = `$cmd`;
	return @lines;
}

sub cleanFile{
	my $dir = shift;
	my $file = shift;
	my $sum = shift;
	my $url = _getUrl($file);
	my $fullPath = fullPath($file);
	downloadFile($url, $fullPath);
	if(fileHasChanged($fullPath, $sum)){
		_warning("Attempted to replace '$fullPath'; failed");
		return;
	}
	return $sum;
}

sub sqlShellCmd{
	my $vars = parseVariables(fullPath("wp-config.php"));
	my $cmd = "mysql -u $vars->{'DB_USER'} -p$vars->{'DB_PASSWORD'} -h$vars->{'DB_HOST'} $vars->{'DB_NAME'}";
	return $cmd;
}


sub parseVariables{
	my $file = shift;
	open(my $fh, "<", $file) or die "Failed to open config.php : $!";
	my $vars;
	while(my $line = readline($fh)){
		#define lines:
		if($line =~ /^\s*define\s*\(["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)\s*;\s*$/){
			$vars->{$1} = $2;
		# variable assignment:
		}elsif($line =~ /^\s*\$(\S+)\s*=\s*('|")?([\d\.]+)('|")?;\s*$/g){
			$vars->{$1} = $3;
		}
	}
	return $vars;
}


sub _error{
	my $message = shift;
	print STDERR $message, "\n";
	exit 1;
} 



1
