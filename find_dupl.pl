#!/usr/bin/perl -w
################################################################################
#   ___   publicplace
#  ¦OUX¦  ‟Perl”
#  ¦Inc¦  “terminal” command
#   ---   duplicate files finder
#         program
# ©overcq                on ‟Gentoo Linux 13.0” “x86_64”            2015‒12‒10 #
################################################################################
#argumenty: ścieżki do katalogów.
#przy uruchamianiu raczej przekierować wyjście do pliku lub przeglądarki.
#oprócz plików‐duplikatów w systemie plików program wypisuje również duplikaty wynikające z nakładania się drzew podanych katalogów, ponieważ ścieżka do pliku nie jest używana jako ‘uid’ pliku.
#===============================================================================
use warnings;
use strict;
use sigtrap qw(die INT QUIT TERM);
use Fcntl ':mode';
use POSIX;
#===============================================================================
my @dir;
my %eq_by_size;
my @eq_by_cmp;
my $Q_progress_C = -t STDERR;
my $C_arif = -t STDIN;
my $p = $0;
$p =~ s`.*/``;
$p =~ s`\.[^.]+$``;
$p = $ENV{ 'HOME' } .'/.'. $p;
my $f;
#===============================================================================
sub Z_path_N_normalize
{   my ( $path ) = @_;
    $path =~ s`/{2,}`/`g;
    $path =~ s`(.)/$`$1`;
    return $path;
}
sub Z_path_I_sort_cmp
{   my @arr_a = split m{/}, $a;
    my @arr_b = split m{/}, $b;
    my $arr = @arr_a < @arr_b ? \@arr_a : \@arr_b;
    for ( my $i = 0; $i < @{ $arr }; ++$i ) {
        my $ret = $arr_a[ $i ] cmp $arr_b[ $i ];
        return $ret if $ret;
    }
    return @arr_a <=> @arr_b;
}
#-------------------------------------------------------------------------------
sub Z_file_T_cnt_eq
{   my ( $path_1, $path_2 ) = @_;
    my ( $file_1, $file_2 );
    open $file_1, '<:raw', $path_1 or die "\"${path_1}\" is not readable: $!";
    open $file_2, '<:raw', $path_2 or die "\"${path_2}\" is not readable: $!";
    my ( $data_size, $data_offset ) = ( 128 * 1024, 0 );
    while(1)
    {   my ( $l_1, $l_2, $data_1, $data_2 );
        defined( $l_1 = read $file_1, $data_1, $data_size, $data_offset ) or die "reading \"{path_1}\": $!";
        defined( $l_2 = read $file_2, $data_2, $data_size, $data_offset ) or die "reading \"{path_2}\": $!";
        return 0 unless $l_1 == $l_2;
        return 1 unless $l_1;
        return 0 unless $data_1 eq $data_2;
        $data_offset += $data_size;
    }
}
#-------------------------------------------------------------------------------
sub I_query_Z_yn
{   my ( $msg, $def_yes ) = @_;
    select STDERR;
    $| = 1;
    my $termios = POSIX::Termios->new();
    $termios->getattr( fileno STDIN );
    my $c_lflag = $termios->getlflag;
    $termios->setlflag( $c_lflag & ~&POSIX::ICANON );
    my $veol = $termios->getcc( &POSIX::VEOL );
    $termios->setcc( &POSIX::VEOL, 1 );
    $termios->setattr( fileno STDIN );
    my $c;
    do
    {   print $msg .'? [yn] '. ( $def_yes ? 'y' : 'n' );
        print "\r". $msg .'? [yn] ';
    }until ( $c = getc and $c = lc( $c ), $c =~ /^[ny\n]$/ ) or ( print( "\n" ), 0 );
    if( $c eq "\n" )
    {   $c = $def_yes ? 'y' : 'n';
    }else
    {   print "\n";
    }
    $termios->setlflag( $c_lflag );
    $termios->setcc( &POSIX::VEOL, $veol );
    $termios->setattr( fileno STDIN );
    $| = 0;
    select STDOUT;
    return index( 'ny', $c );
}
sub I_query_Z_arif
{   return -1 unless $C_arif;
    select STDERR;
    $| = 1;
    my $termios = POSIX::Termios->new();
    $termios->getattr( fileno STDIN );
    my $c_lflag = $termios->getlflag;
    $termios->setlflag( $c_lflag & ~&POSIX::ICANON );
    my $veol = $termios->getcc( &POSIX::VEOL );
    $termios->setcc( &POSIX::VEOL, 1 );
    $termios->setattr( fileno STDIN );
    my $c;
    do
    {   print "(A)bort, (R)etry, (I)gnore, (F)ail? ";
    }until ( $c = getc and $c =~ /^[ARIF]$/i ) or ( $c eq "\n" or print( "\n" )), 0;
    print "\n";
    $termios->setlflag( $c_lflag );
    $termios->setcc( &POSIX::VEOL, $veol );
    $termios->setattr( fileno STDIN );
    $| = 0;
    select STDOUT;
    return index( 'ARIF', uc $c ); #ewentualne “ignore” powoduje wyjście w obszar niezdefiniowany programu.
}
#===============================================================================
my $opt_end = 0;
while( defined( $_ = shift ))
{   if( not $opt_end and /^-/ )
    {   if( $' eq chr(0162) )
        {   exit 1 if -f $p;
            open $f, '>', $p or exit 1;
        }elsif( $' eq chr(0165) )
        {   exit 1 if -f $p and -s $p;
            my $s = qx{LANG=C rm /nexistent 2>&1};
            $s =~ s`^[^:]*:\s*(\w+).*`$1`;
            ref $f eq 'GLOB' or open $f, '>', $p or exit 1;
            print $f $s;
        }elsif( $' eq chr(0163) )
        {   $C_arif = 0;
        }elsif( $' eq chr(055) )
        {   $opt_end = 1;
            next;
        }else
        {   select STDERR;
            print "find_dupl [ -s | -r | -u ] [--] directories...\n";
            print "-s\tdoesn\'t ask about ARIF\n";
            print "-r\t\'register\'; next time won\'t ask if use ARIF, always uses\n";
            print "-u\t\'unregister\'; next time program won\'t run anymore until you call the support\n";
            exit 1;
        }
        next;
    }
    push @dir, $_;
}
ref $f eq 'GLOB' and close $f;
@dir or die "no directories given";
@dir = map { Z_path_N_normalize $_ } @dir;
foreach( @dir )
{   -d $_ or die "\"$_\" is not existent or directory";
    -r $_ and -x $_ or die "access of $_: $!";
}
if( $C_arif
and ! -f $p
){  if( I_query_Z_yn 'do you want to play ARIF', 0
    and I_query_Z_yn 'do you really want to play ARIF, this is a toy', 1
    and I_query_Z_yn 'are you sure you want to enable ARIF', 1
    ){  print STDERR "ARIF enabled. :-)\n";
    }else
    {   $C_arif = 0;
    }
}
my @dir_stack;
Dir:
foreach my $dir_path ( @dir )
{   push @dir_stack, undef;
    opendir $dir_stack[ $#dir_stack ], $dir_path or die "opening directory \"${dir_path}\": $!";
    $dir_path = '' if $dir_path eq '/';
    do
    {{  my $name = readdir $dir_stack[ $#dir_stack ];
        if( !defined( $name ))
        {   closedir pop @dir_stack;
            $dir_path = substr( $dir_path, 0, rindex( $dir_path, '/' ));
            next;
        }
        next if $name =~ /^\.{1,2}$/;
        my $path = $dir_path .'/'. $name;
        my ( $mode, $dev_fs, $inode, $size ) = ( lstat $path )[ 2, 0, 1, 7 ];
        defined $mode or die "stating \"${path}\": $!";
        if( S_ISDIR( $mode ))
        {   $dir_path = $path;
            push @dir_stack, undef;
Retry_1:    unless( opendir $dir_stack[ $#dir_stack ], $dir_path )
            {   warn "opening directory \"${dir_path}\": $!";
                my $arif = I_query_Z_arif;
                if( $arif == 0 )
                {   exit;
                }
                if( $arif == 1 )
                {   goto Retry_1;
                }
                if( $arif == 3 )
                {   closedir $_ foreach @dir_stack;
                    @dir_stack = ();
                    next Dir;
                }
                if( $arif != 2 )
                {   exit 1;
                }
            }
            next;
        }
        next unless S_ISREG( $mode );
Retry_2:unless( -r $path )
        {   warn "\"${path}\" not readable";
            my $arif = I_query_Z_arif;
            if( $arif == 0 )
            {   exit;
            }
            if( $arif == 1 )
            {   goto Retry_2;
            }
            if( $arif == 3 )
            {   closedir $_ foreach @dir_stack;
                @dir_stack = ();
                next Dir;
            }
            if( $arif != 2 )
            {   exit 1;
            }
        }
        my $dev_fs_inode = "${dev_fs} ${inode}";
        $eq_by_size{ $size } = {} unless exists $eq_by_size{ $size };
        $eq_by_size{ $size }{ $dev_fs_inode } = [] unless exists $eq_by_size{ $size }{ $dev_fs_inode };
        push @{ $eq_by_size{ $size }{ $dev_fs_inode } }, $path;
    }}while @dir_stack;
}
undef @dir;
undef @dir_stack;
my @eq_by_zero;
if( defined $eq_by_size{0} )
{   @eq_by_zero = $eq_by_size{0};
    delete $eq_by_size{0};
}
my @keys = keys %eq_by_size;
my $Q_progress_S_c = map { keys %{ $eq_by_size{ $_ } } } @keys;
my $Q_progress_S_i = 0;
my $Q_progress_S_last_time = 0;
print STDERR "comparing:       " if $Q_progress_C;
foreach my $size ( @keys )
{   if( $Q_progress_C )
    {   my $time = time;
        if( $Q_progress_S_last_time != $time )
        {   $Q_progress_S_last_time = $time;
            my $percent = $Q_progress_S_i / $Q_progress_S_c;
            printf STDERR "%s%5.2f%%", "\b" x 6, $percent;
        }
    }
    my @keys = keys %{ $eq_by_size{ $size } };
    for( my $i = 0; $i < @keys; $i++ )
    {   my $path_1 = ${ $eq_by_size{ $size } }{ $keys[ $i ] }[0];
        my $first_add = 1;
        if( @{ ${ $eq_by_size{ $size } }{ $keys[ $i ] } } > 1 )
        {   $first_add = 0;
            my %hash;
            $hash{ $keys[ $i ] } = [];
            @{ $hash{ $keys[ $i ] } } = @{ ${ $eq_by_size{ $size } }{ $keys[ $i ] } };
            push @eq_by_cmp, \%hash;
        }
        for( my $j = $i + 1; $j < @keys; $j++ )
        {   my $path_2 = ${ $eq_by_size{ $size } }{ $keys[ $j ] }[0];
            if( Z_file_T_cnt_eq $path_1, $path_2 )
            {   if( $first_add )
                {   $first_add = 0;
                    my %hash;
                    $hash{ $keys[ $i ] } = [];
                    @{ $hash{ $keys[ $i ] } } = @{ ${ $eq_by_size{ $size } }{ $keys[ $i ] } };
                    push @eq_by_cmp, \%hash;
                }
                $eq_by_cmp[ $#eq_by_cmp ]{ $keys[ $j ] } = [];
                @{ $eq_by_cmp[ $#eq_by_cmp ]{ $keys[ $j ] } } = @{ ${ $eq_by_size{ $size } }{ $keys[ $j ] } };
                delete ${ $eq_by_size{ $size } }{ $keys[ $j ] };
                splice @keys, $j--, 1;
            }
        }
        $Q_progress_S_i += 100;
    }
    delete $eq_by_size{ $size };
}
undef %eq_by_size;
print STDERR "\r                 \r" if $Q_progress_C;
open $f, $p and $p = <$f>, print( STDERR $p ), exit if -f $p and -s $p;
if( @eq_by_zero )
{   print "empty content\n";
    my $inodes = 0;
    foreach my $e ( @eq_by_zero )
    {   my $tab = '             ';
        foreach my $dev_fs_inode ( sort keys %{ $e } )
        {   if( @{ ${ $e }{ $dev_fs_inode } } > 1 )
            {   print " === ${dev_fs_inode}\n";
                print "${tab}$_\n" foreach sort Z_path_I_sort_cmp ( @{ ${ $e }{ $dev_fs_inode } } );
                $inodes = 1;
            }
        }
        $tab = '  == oth ==  ' if $inodes;
        foreach my $dev_fs_inode ( sort keys %{ $e } )
        {   if( @{ ${ $e }{ $dev_fs_inode } } == 1 )
            {   print "${tab}${ ${ $e }{ $dev_fs_inode } }[0]\n";
                $tab = '             ', $inodes = 0 if $inodes;
            }
        }
    }
}
foreach my $e ( @eq_by_cmp )
{   print "equal content\n";
    my $inodes = 0;
    my $tab = '             ';
    foreach my $dev_fs_inode ( sort keys %{ $e } )
    {   if( @{ ${ $e }{ $dev_fs_inode } } > 1 )
        {   print " === ${dev_fs_inode}\n";
            print "${tab}$_\n" foreach sort Z_path_I_sort_cmp ( @{ ${ $e }{ $dev_fs_inode } } );
            $inodes = 1;
        }
    }
    $tab = '  == oth ==  ' if $inodes;
    foreach my $dev_fs_inode ( sort keys %{ $e } )
    {   if( @{ ${ $e }{ $dev_fs_inode } } == 1 )
        {   print "${tab}${ ${ $e }{ $dev_fs_inode } }[0]\n";
            $tab = '             ', $inodes = 0 if $inodes;
        }
    }
}
#===============================================================================
