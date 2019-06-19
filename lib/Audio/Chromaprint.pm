package Audio::Chromaprint;

use Moose;
use Carp qw< croak >;
use FFI::Platypus;
use FFI::CheckLib;

our $HAS_SUBS;
our %SUBS = (
    'chromaprint_new'         => [ ['int']                       => 'opaque' ],
    'chromaprint_get_version' => [ []                            => 'string' ],
    'chromaprint_free'        => [ ['opaque']                    => 'void'   ],
    'chromaprint_set_option'  => [ [ 'opaque', 'string', 'int' ] => 'int'    ],
    'chromaprint_start'       => [ [ 'opaque', 'int', 'int' ]    => 'int'    ],
    'chromaprint_finish'      => [ ['opaque']                    => 'int'    ],

    'chromaprint_get_fingerprint_hash' => [ [ 'opaque', 'opaque' ], 'int' ],
);

sub BUILD {
    $HAS_SUBS++
        and return;

    my $ffi = FFI::Platypus->new;

    $ffi->lib( find_lib_or_exit( 'lib' => 'chromaprint' ) );

    foreach my $func ( keys %SUBS ) {
        $ffi->attach( $func, @{ $SUBS{$func} } );
    }
}

has 'cp' => (
    'is'      => 'ro',
    'lazy'    => 1,
    'default' => sub { chromaprint_new(1) }
);

sub get_version {
    my $self = shift;
    return chromaprint_get_version( $self->cp );
}

sub start {
    my ( $self, $sample_rate, $num_channels ) = @_;

    $sample_rate =~ /^[0-9]+$/xms
        or croak 'sample_rate must be an integer';

    $num_channels =~ /^[12]$/xms
        or croak 'num_channels must be 1 or 2';

    return chromaprint_start( $self->cp, $sample_rate, $num_channels );
}

sub finish {
    my $self = shift;
    return chromaprint_finish( $self->cp );
}

sub get_fingerprint_hash {
    my $self = shift;
    my $hash;
    return chromaprint_get_fingerprint_hash( $self->cp, \$hash );
}

sub DEMOLISH {
    my $self = shift;
    chromaprint_free( $self->cp );
}

1;
