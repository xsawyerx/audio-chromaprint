package Audio::Chromaprint;

use Moose;
use Carp qw< croak >;
use FFI::Platypus 0.88;
use FFI::CheckLib;
use Moose::Util::TypeConstraints;

use constant {
    'MIN_SILENCE_THRESHOLD' => 0,
    'MAX_SILENCE_THRESHOLD' => 32_767,
};

our $HAS_SUBS;
our %SUBS = (
    '_new'         => [ ['int']                       => 'opaque' ],
    '_get_version' => [ []                            => 'string' ],
    '_free'        => [ ['opaque']                    => 'void'   ],
    '_set_option'  => [ [ 'opaque', 'string', 'int' ] => 'int'    ],
    '_start'       => [ [ 'opaque', 'int', 'int' ]    => 'int'    ],
    '_finish'      => [ ['opaque']                    => 'int'    ],
    '_feed'        => [ ['opaque', 'string', 'int' ]  => 'int'    ],

    '_get_fingerprint_hash' => [ [ 'opaque', 'uint32*' ], 'int' ],
    '_get_fingerprint'      => [ [ 'opaque', 'opaque*' ], 'int' ],
    '_get_raw_fingerprint'  => [ [ 'opaque', 'opaque*', 'int*' ], 'int' ],

    '_dealloc' => [ [ 'opaque' ] => 'void' ],
);

sub BUILD {
    $HAS_SUBS++
        and return;

    my $ffi = FFI::Platypus->new;

    # Setting this mangler lets is omit the chromaprint_ prefix
    # from the attach call below, and the function names used
    # by perl
    $ffi->mangler(sub {
        my $name = shift;
        $name =~ s/^_/chromaprint_/;
        return $name;
    });

    $ffi->lib( find_lib_or_exit( 'lib' => 'chromaprint' ) );

    $ffi->attach( $_, @{ $SUBS{$_} } )
        for keys %SUBS;

    $ffi->attach_cast('opaque_to_string' => opaque => 'string');
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
        my $cp   = _new( $self->algorithm );

        if ( $self->has_silence_threshold ) {
            _set_option(
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

sub get_version { _get_version() }

sub start {
    my ( $self, $sample_rate, $num_channels ) = @_;

    $sample_rate =~ /^[0-9]+$/xms
        or croak 'sample_rate must be an integer';

    $num_channels =~ /^[12]$/xms
        or croak 'num_channels must be 1 or 2';

    return _start( $self->cp, $sample_rate, $num_channels );
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

    return _set_option( $self->cp, $name => $value );
}

sub finish {
    my $self = shift;
    return _finish( $self->cp );
}

sub get_fingerprint_hash {
    my $self = shift;
    my $hash;
    _get_fingerprint_hash( $self->cp, \$hash );
    return $hash;
}

sub get_fingerprint {
    my $self = shift;
    my $ptr;
    _get_fingerprint($self->cp, \$ptr);
    my $str = opaque_to_string($ptr);
    _dealloc($ptr);
    return $ptr;
}

sub get_raw_fingerprint {
    my $self = shift;
    my $ptr;
    my $size;
    _get_raw_fingerprint($self->cp, \$ptr, \$size);
    # not espeically fast, but need a cast with a variable length array
    my $fp = FFI::Platypus->new->cast('opaque' => "uint32[$size]", $ptr);
    _dealloc($ptr);
    return $fp;
}

sub feed {
    my($self, $data) = @_;
    _feed($self->cp, $data, length($data)/2);
}

sub DEMOLISH {
    my $self = shift;
    _free( $self->cp );
}

1;
