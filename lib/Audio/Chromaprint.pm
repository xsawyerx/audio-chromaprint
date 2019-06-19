package Audio::Chromaprint;

use Moose;
use Carp qw< croak >;
use FFI::Platypus;
use FFI::CheckLib;
use Moose::Util::TypeConstraints;

use constant {
    'MIN_SILENCE_THRESHOLD' => 0,
    'MAX_SILENCE_THRESHOLD' => 32_767,
};

our $HAS_SUBS;
our %SUBS = (
    'chromaprint_new'         => [ ['int']                       => 'opaque' ],
    'chromaprint_get_version' => [ []                            => 'string' ],
    'chromaprint_free'        => [ ['opaque']                    => 'void'   ],
    'chromaprint_set_option'  => [ [ 'opaque', 'string', 'int' ] => 'int'    ],
    'chromaprint_start'       => [ [ 'opaque', 'int', 'int' ]    => 'int'    ],
    'chromaprint_finish'      => [ ['opaque']                    => 'int'    ],
    'chromaprint_feed'        => [ ['opaque', 'string', 'int' ]  => 'int'    ],

    'chromaprint_get_fingerprint_hash' => [ [ 'opaque', 'uint32*' ], 'int' ],
);

sub BUILD {
    $HAS_SUBS++
        and return;

    my $ffi = FFI::Platypus->new;

    $ffi->lib( find_lib_or_exit( 'lib' => 'chromaprint' ) );

    $ffi->attach( $_, @{ $SUBS{$_} } )
        for keys %SUBS;
}

subtype 'ChromaprintAlgorithm',
    as 'Int',
    where { /^[0123]$/xms },
    message { 'algorithm must be 0, 1, 2, or 3' };

subtype 'ChromaprintSilenceThreshold',
    as 'Int',
    where { $_ >= MIN_SILENCE_THRESHOLD() && $_ <= MAX_SILENCE_THRESHOLD() },
    message { 'silence_threshold option must be between 0 and 32767' };

has 'algorithm' => (
    'is'      => 'ro',
    'isa'     => 'ChromaprintAlgorithm',
    'default' => sub {1},
);

has 'cp' => (
    'is'      => 'ro',
    'lazy'    => 1,
    'default' => sub {
        my $self = shift;
        my $cp   = chromaprint_new( $self->algorithm );

        if ( $self->has_silence_threshold ) {
            chromaprint_set_option(
                $cp, 'silence_threshold' => $self->silence_threshold,
            );
        }

        return $cp;
    }
);

has 'silence_threshold' => (
    'is'        => 'ro',
    'isa'       => 'ChromaprintSilenceThreshold',
    'predicate' => 'has_silence_threshold',
);

sub get_version { chromaprint_get_version() }

sub start {
    my ( $self, $sample_rate, $num_channels ) = @_;

    $sample_rate =~ /^[0-9]+$/xms
        or croak 'sample_rate must be an integer';

    $num_channels =~ /^[12]$/xms
        or croak 'num_channels must be 1 or 2';

    return chromaprint_start( $self->cp, $sample_rate, $num_channels );
}

sub set_option {
    my ( $self, $name, $value ) = @_;

    $name && $value
        or croak('set_option( name, value )');

    length $name
        or croak('set_option requires a "name" string');

    $value =~ /^[0-9]+$/xms
        or croak('set_option requires a "value" integer');

    if ( $name eq 'silence_threshold' ) {
        $value >= MIN_SILENCE_THRESHOLD() && $value <= MAX_SILENCE_THRESHOLD()
            or croak('silence_threshold option must be between 0 and 32767');
    }

    return chromaprint_set_option( $self->cp, $name => $value );
}

sub finish {
    my $self = shift;
    return chromaprint_finish( $self->cp );
}

sub get_fingerprint_hash {
    my $self = shift;
    my $hash;
    chromaprint_get_fingerprint_hash( $self->cp, \$hash );
    return $hash;
}

sub feed {
    my($self, $data) = @_;
    chromaprint_feed($self->cp, $data, length($data)/2);
}

sub DEMOLISH {
    my $self = shift;
    chromaprint_free( $self->cp );
}

1;
