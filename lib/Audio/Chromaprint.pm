package Audio::Chromaprint {

use Moose;
use FFI::Platypus;
use FFI::CheckLib;

our $HAS_SUBS;

sub BUILD {
    $HAS_SUBS++
        and return;

    my $ffi = FFI::Platypus->new;

    $ffi->lib( find_lib_or_exit( 'lib' => 'chromaprint' ) );

    $ffi->attach( 'chromaprint_new' => ['int'] => 'opaque' );
    $ffi->attach( 'chromaprint_get_version' => [] => 'string' );
    $ffi->attach( 'chromaprint_free' => ['opaque'] => 'void' );
    $ffi->attach(
        'chromaprint_set_option' => [ 'opaque', 'string', 'int' ] => 'int',
    );

    $ffi->attach(
        'chromaprint_start' => [ 'opaque', 'int', 'int' ] => 'int',
    );

    $ffi->attach( 'chromaprint_finish' => [ 'opaque' ] => 'int' );
    $ffi->attach( 'chromaprint_get_fingerprint_hash' => [ 'opaque', 'opaque' ] => 'int' );
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
        chromaprint_start( $self->cp, 1200, 2 );

    }

    sub finish {
        chromaprint_finish( $self->cp );
    }

    sub get_fingerprint_hash {
        my $hash;
        return chromaprint_get_fingerprint_hash($self->cp, \$hash);
    }

    sub DEMOLISH {
        chromaprint_free( $self->cp );
    }

}

my $cp = Audio::Chromaprint->new();
print $cp->get_version(), "\n";

1;
