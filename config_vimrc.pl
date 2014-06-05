#!/usr/bin/perl

package Vimrc;

use warnings;
use strict;
use Carp;
use Getopt::Long;
use File::Basename;
use File::Copy;
use FindBin qw{ $Bin };

my $VERSION = '1.0';

my %options;
GetOptions(
  'help|h|?'  => \$options{help},
  'version|v' => \$options{version},
  'mod|m'     => \$options{mod},
  'noop|n'    => \$options{noop},
  'file|f:s'  => \$options{vimrc_file},
  'debug|d'   => \$options{debug},
) or usage() && exit 1;

if ( $options{help} ) {
  usage();
  exit;
}

if ( $options{version} ) {
  version();
  exit;
}

# Must specify mod or noop, but not both.
if ( ( ! $options{mod} and ! $options{noop} ) || ( $options{mod} and $options{noop} ) ) {
  usage();
  exit 1;
}

my $vimrc_file = $options{vimrc_file} ? $options{vimrc_file} : "$ENV{HOME}/.vimrc";
my $path       = ( fileparse( $vimrc_file ) )[1];

unless ( caller() ) {
  configure();
  exit;
}

# configure()
#
# Main program loop
#
sub configure {
  my $buffer;

  # NOTE: File & directory creation happens elsewhere
  if ( ( ! -e $vimrc_file ) && ( $options{mod} ) ) {
    print "  There is not a .vimrc file located at $vimrc_file\n";
    print "  Would you like to create one? [Y] > ";
    chomp ( $buffer = <STDIN> );
    if ( $buffer && ( lc( $buffer ) ne 'y' ) && ( lc( $buffer ) ne 'yes' ) ) {
      exit;
    }
  }
  if ( ( ! -d "$path/.vim" ) && ( $options{mod} ) ) {
    print "  A .vim directory will need to be created at ${path}.vim\n";
    print "  Would you like to create the directory [Y] > ";
    chomp ( $buffer = <STDIN> );
    if ( $buffer && ( lc( $buffer ) ne 'y' ) && ( lc( $buffer ) ne 'yes' ) ) {
      exit;
    }
  }

  install_plugins();

  # Did the subs calling subs just for fun. Look at all the memory I'm saving
  # by not storing temporary hash references!
  write_vimrc( update_vimrc( get_file_contents( $vimrc_file ) ) );
}

# install_plugins()
#
# Copies all of the needed vimrc plugins into the .vim directory.
# Will create directories as needed.
#
sub install_plugins {

  create_dirs(
    "${path}.vim",
    "${path}.vim/ftdetect",
    "${path}.vim/ftplugin",
    "${path}.vim/indent",
    "${path}.vim/syntax",
  );

  foreach my $plugin ( 'ftdetect', 'ftplugin', 'indent', 'syntax' ) {
    if ( $options{mod} ) {
      print "DEBUG: copying $Bin/vim/$plugin/puppet.vim to ${path}.vim/$plugin/puppet.vim\n" if $options{debug};
      copy( "$Bin/vim/$plugin/puppet.vim", "${path}.vim/$plugin/puppet.vim" )
        or croak "ERROR: Can't copy $Bin/vim/$plugin/puppet.vim to ${path}.vim/$plugin/puppet.vim: $!";
    }
    else {
      print "INFO: Would have copied $Bin/vim/$plugin/puppet.vim to ${path}.vim/$plugin/puppet.vim\n";
    }
  }
}

# create_dirs()
#
# Creates directories if they don't already exist.
sub create_dirs {
  foreach my $dir ( @_ ) {
    if ( ! -e $dir ) {
      if ( $options{mod} ) {
        print "DEBUG: creating $dir\n" if $options{debug};
        mkdir $dir;
      }
      else {
        print "INFO: Would have created $dir\n";
      }
    }
  }
}

# get_file_contents()
#
# Will return an array reference to the contents of the file. The reference will
# point to an empty array if the file does not exist.
sub get_file_contents {
  my $file = shift;
  my @contents = ();
  if ( -e $file ) {
    open my $fh, '<', $file
      or croak "ERROR: Can't open $file: $!";
    @contents = <$fh>;
    close $fh;
  }
  return \@contents;
}

# update_vimrc()
#
# Takes the contents of an existing, or empty, .vimrc file and inserts the needed
# updates. Returns an array reference to the updated contents.
sub update_vimrc {
  my $vimrc_old_aref = shift;
  my @vimrc_new;

  # NOTE: Prepending letters in front of each key to force the correct sort order
  my %settings = (
    A_syntax => {
      text  => 'syntax on' . "\n",
      regex => qr/^syntax/i,
      set   => 0,
    },
    B_expandtab => {
      text  => 'set expandtab' . "\n",
      regex => qr/^set expandtab/i,
      set   => 0,
    },
    C_softtabstop => {
      text  => 'set softtabstop=2' . "\n",
      regex => qr/^set softtabstop/i,
      set   => 0,
    },
    D_shiftwidth => {
      text  => 'set shiftwidth=2' . "\n",
      regex => qr/^set shiftwidth/i,
      set   => 0,
    },
    E_highlight_literaltabs => {
      text  => 'highlight LiteralTabs ctermbg=darkgreen guibg=darkgreen' . "\n",
      regex => qr/^highlight LiteralTabs/i,
      set   => 0,
    },
    F_match_literaltabs => {
      text  => "match LiteralTabs /\\s\\\t/\n",
      regex => qr/^match LiteralTabs/i,
      set   => 0,
    },
    G_highlight_whitespace => {
      text  => 'highlight ExtraWhitespace ctermbg=darkgreen guibg=darkgreen' . "\n",
      regex => qr/^highlight ExtraWhitespace/i,
      set   => 0,
    },
    H_match_whitespace => {
      text  => 'match ExtraWhitespace /\s\+$/' . "\n",
      regex => qr/^match ExtraWhitespace/i,
      set   => 0,
    },
    I_indent_plugin => {
      text  => 'filetype plugin indent on' . "\n",
      regex => qr/^filetype plugin indent/i,
      set   => 0,
    },
    J_au_bufread_pp => {
      text  => 'au BufRead,BufNewFile *.pp set filetype=puppet' . "\n",
      regex => qr/^au BufRead.*?BufNewFile.*?\.pp/i,
      set   => 0,
    },
    K_au_bufread_spec => {
      text  => 'au BufRead,BufNewFile *_spec.rb nmap <F8> :!rspec --color %<CR>' . "\n",
      regex => qr/^au BufRead.*?BufNewFile.*?_spec.rb/i,
      set   => 0,
    },
    # The au_ settings need special handling. Our previous examples spanned
    # multiple lines. I'll use the remove_ settings below to whack the extra lines.
    remove_buffread_pp_extra_line => {
      text  => '',
      regex => qr/\\ set filetype=puppet/i,
      set   => 1,
    },
    remove_buffread_spec_extra_line => {
      text  => '',
      regex => qr/\\ nmap.*?F8.*?rspec.*?color/i,
      set   => 1,
    },
  );

  foreach my $line ( @{ $vimrc_old_aref } ) {
    my $replaced_line = 0;
    foreach my $setting ( keys %settings ) {
      if ( $line =~ $settings{$setting}{regex} ) {
        push( @vimrc_new, $settings{$setting}{text} );
        $settings{$setting}{set} = 'true';
        $replaced_line = 'true';
        chomp( my $line_to_print = $line );
        chomp( my $text_to_print = $settings{$setting}{text} );
        if ( $setting =~ /^remove_/ ) {
          print "DEBUG: Removing $line_to_print\n" if $options{debug};
        }
        else {
          print "DEBUG: Replacing $line_to_print with $text_to_print\n" if $options{debug};
        }
        last;
      }
    }
    if ( ! $replaced_line ) {
      push( @vimrc_new, $line );
    }
  }

  foreach my $setting ( sort keys %settings ) {
    if ( ! $settings{$setting}{set} ) {
      push( @vimrc_new, $settings{$setting}{text} );
      chomp( my $text_to_print = $settings{$setting}{text} );
      print "DEBUG: Appending $text_to_print\n" if $options{debug};
    }
  }

  return \@vimrc_new;
}

sub write_vimrc {
  my $vimrc_aref = shift;

  if ( $options{noop} ) {
    print "INFO: Would have written the following to $vimrc_file:\n";
    foreach ( @{ $vimrc_aref } ) {
      print $_;
    }
  }
  else {
    open my $fh, '>', $vimrc_file
      or croak "ERROR: Can't open $vimrc_file: $!";
    foreach ( @{ $vimrc_aref } ) {
      print $fh $_;
    }
    close $fh;
    print "DEBUG: Wrote updated .vimrc settings to $vimrc_file\n" if $options{debug};
  }
}

sub version {
  print "$VERSION\n";
}

sub usage {
  print "\nUsage:\n\n";
  print "  $0 [-h] [-v] [-m | -n] [-f filename] [-d]\n\n";
  print "    -h | --help | -?      -  Prints this usage message.\n";
  print "    -v | --version        -  Prints the version number.\n";
  print "    -m | --mod            -  Modify your .vimrc file. Required for changes to take effect.\n";
  print "    -n | --noop           -  Print changes that would have been made if -m was specified.\n";
  print "    -f filename\n";
  print "       | --file filename  -  Specify an alternate .vimrc file location.\n";
  print "    -d | --debug          -  Print debug info.\n\n";
}
