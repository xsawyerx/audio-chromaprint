package MooseX::Role::FFI;
# ABSTRACT: Easily create interfaces to FFI functions with Moose roles

use Moose::Role;

use FFI::Platypus 0.88;
use FFI::CheckLib;

requires qw<
    ffi_subs_data
    ffi_lib
>;

has 'ffi' => (
    'is'       => 'ro',
    'reader'   => '_ffi',
    'init_arg' => undef,
    'builder'  => '_build_ffi',
);

has 'ffi_subs_refs' => (
    'is'       => 'ro',
    'reader'   => '_ffi_subs_refs',
    'init_arg' => undef,
    'builder'  => '_build_ffi_subs_refs',
    'lazy'     => 1,
    'traits'   => ['Hash'],
    'handles'  => { 'get' => 'ffi_sub' },
);

sub _build_ffi {
    my $self     = shift;
    my $ffi_data = $self->ffi_subs_data;
    my $ffi_lib  = $self->ffi_lib;
    my $ffi      = FFI::Platypus->new;

    my $fallback = $self->can('ffi_alien');

    $ffi->lib(
        find_lib_or_exit(
            'lib' => $ffi_lib,
            $fallback ? ( alien => $fallback->() ) : (),
        )
    );

    return $ffi;
}

sub _build_ffi_subs_refs {
    my $self      = shift;
    my $ffi       = $self->_ffi;
    my %subs_data = %{ $self->_ffi_subs_data };

    my %subs_refs = map +(
        $_ => $ffi->function( $_ => $subs_data{$_} )->sub_ref,
    ), keys %subs_data;

    return \%subs_refs;
}

sub BUILD {
    # FFI subs are lazy so they can happen after ffi creation
    # but we still want them created during instantiation
    shift->ffi_subs_refs;
}

no Moose::Role;

1;

__END__

=head
