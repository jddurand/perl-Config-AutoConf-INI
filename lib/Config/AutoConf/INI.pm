use strict;
use warnings FATAL => 'all';

package Config::AutoConf::INI;
use Carp                   qw/croak/;
use Config::AutoConf 0.313 qw//;
use Config::INI::Reader    qw//;
use Scalar::Util           qw/looks_like_number/;
use parent                 qw/Config::AutoConf/;
use SUPER;

# ABSTRACT: Drive Config::AutoConf with an INI file

# VERSION

# AUTHORITY

=head1 DESCRIPTION

This module is a extending Config::AutoConf, using a INI-like config file.

=head1 SYNOPSIS

    use Config::AutoConf::INI;

    Config::AutoConf::INI->new()->check('config.ini')->write_config_h;

=head1 SUBROUTINES/METHODS

=head2 check($config_ini)

Performs all checks that are in the INI file C<$config_ini> and that are responsible for configuring Config::AutoConf or defining autoconf I<variables>. The following sections are supported, and executed in the order listed below:

=over

=item Configuration sections

=over

=item Includes

This is an interface to C<Config::AutoConf>'s C<push_includes>.

  [includes]
  ; Anything on the the left-hand side is used if the right-hand side is a true value.
  ; Example:
  . = 1
  /this/path = 0
  C:\Windows\Temp = 1

=item Preprocessor flags

This is an interface to C<Config::AutoConf>'s C<push_preprocess_flags>.

  [preprocess_flags]
  ; Anything on the the left-hand side is used if the right-hand side is a true value.
  ; Example:
  -DCPPFLAG0N = 1
  -DCPPFLAG0FF = 0

=item Compiler flags

This is an interface to C<Config::AutoConf>'s C<push_compiler_flags>.

  [compiler_flags]
  ; Anything on the the left-hand side is used if the right-hand side is a true value.
  ; Example:
  -DCCFLAG0N = 1
  -DCCFLAG0FF = 0

=item Linker flags

This is an interface to C<Config::AutoConf>'s C<push_link_flags>.

  [link_flags]
  ; Anything on the the left-hand side is used if the right-hand side is a true value.
  ; Example:
  --very = 1
  --special = 0

=back

=item Check sections

Config::AutoConf provides bundles that are explicitly supported in a I<bundle> section, i.e.:

  [bundle]
  ; The bundle check on the left-hand side is done when the right-hand side is a true value.
  ; The only supported bundles are stdc_headers, default_headers and dirent_headers.
  ; Example:
  stdc_headers = 1
  default_headers = 1
  dirent_headers = 1


In all the following sections, if the right-hand side is a true value the check is executed. If the right-hand side does not look like a number then a variable is explicitly created with that name (e.g. C<I_HAVE_STDIO_G>). This does not prevent the default variable to be created (i.e.g C<HQVE_STDIO_H>). The wanted variable name can very well be equal to the default name.

=over

=item Files

This is an interface to C<Config::AutoConf>'s C<check_file>.

  [files]
  /etc/passwd = HAVE_ETC_PASSWD
  /tmp/this = 0
  /tmp/that = HAVE_TMP_THAT

=item Programs

This is an interface to C<Config::AutoConf>'s C<check_prog>.

  [progs]
  cc = CC_NAME

=item Headers

This is an interface to C<Config::AutoConf>'s C<check_header>.

  [headers]
  stddef.h = 0
  time.h = 1

=item Declarations

This is an interface to C<Config::AutoConf>'s C<check_decl>.

  [decls]
  read = 1

=item Functions

This is an interface to C<Config::AutoConf>'s C<check_func>.

  [funcs]
  read = 1

=item Types

This is an interface to C<Config::AutoConf>'s C<check_type>.

  [types]
  size_t = 1

=item Types sizeof

This is an interface to C<Config::AutoConf>'s C<check_sizeof_types>.

  [sizeof_types]
  size_t = 1

=item Types offset

This is an interface to C<Config::AutoConf>'s C<check_alignof_types>.

  [alignof_types]
  struct tm.tm_year = 1

=item Aggregate members

This is an interface to C<Config::AutoConf>'s C<check_member>.

  [members]
  struct tm.tm_year = 1

=back

=back

=cut

sub check {
    my ($self, $config_ini) = @_;

    #
    # Internal setup
    #
    $self->{_headers_ok} = {};
    $self->{_config_ini} = $config_ini ? Config::INI::Reader->read_file($config_ini) : {};

    #
    # Setup
    #
    $self->_process_from_config(section    => 'includes',         stub_name  => 'push_includes');
    $self->_process_from_config(section    => 'preprocess_flags', stub_name  => 'push_preprocess_flags');
    $self->_process_from_config(section    => 'compiler_flags',   stub_name  => 'push_compiler_flags');
    $self->_process_from_config(section    => 'link_flags',       stub_name  => 'push_link_flags');

    #
    # Run - the order has been choosen carefully
    #
    $self->_process_from_config(section    => 'files',         stub_name  => 'check_file',
                               force_msg   => 'file %s');
    $self->_process_from_config(section    => 'progs',         stub_name  => 'check_prog',
                                stub_names => {
                                               #
                                               # Specific implementations
                                               #
                                               yacc       => 'check_prog_yacc',
                                               awk        => 'check_prog_awk',
                                               egrep      => 'check_prog_egrep',
                                               lex        => 'check_prog_lex',
                                               sed        => 'check_prog_sed',
                                               pkg_config => 'check_prog_pkg_config',
                                               cc         => 'check_prog_cc'
                                              }
                               );
    $self->_process_from_config(section    => 'bundle',         stub_name  => '_check_bundle');
    $self->_process_from_config(section    => 'headers',        stub_name => 'check_header',       args => \&_args_check_header);
    $self->_process_from_config(section    => 'decls',          stub_name => 'check_decl',         args => \&_args_check);
    $self->_process_from_config(section    => 'funcs',          stub_name => 'check_func',         args => \&_args_check);
    $self->_process_from_config(section    => 'types',          stub_name => 'check_type',         args => \&_args_check);
    $self->_process_from_config(section    => 'sizeof_types',   stub_name => 'check_sizeof_type',  args => \&_args_check);
    $self->_process_from_config(section    => 'alignof_types',  stub_name => 'check_alignof_type', args => \&_args_check);
    $self->_process_from_config(section    => 'members',        stub_name => 'check_member',       args => \&_args_check);

    delete $self->{_config_ini};
    delete $self->{_headers_ok};
    $self;
}

#
# Bundle check
#
sub _check_bundle {
    my ($self, $bundle) = @_;

    my @args = $self->_args_check_headers;

    if ($bundle eq 'stdc_headers') {
        $self->check_stdc_headers(@args)
    } elsif ($bundle eq 'default_headers') {
        $self->check_default_headers(@args)
    } elsif ($bundle eq 'dirent_headers') {
        $self->check_dirent_header(@args)
    }
}

#
# Config::AutoConf does not honor all the found headers, so we generate
# ourself the prologue
#
sub _prologue {
  my ($self) = @_;

  my $prologue = join("\n", map { "#include <$_>" } keys %{$self->{_headers_ok}}) . "\n";

  return $prologue
}

#
# Standard option, containing prologue
#
sub _args_option {
  my ($self) = @_;

  return { prologue => $self->_prologue }
}

#
# Standard list of arguments: the original one and a hash containing the prologue
#
sub _args_check {
  my ($self, $check) = @_;

  return ($check, $self->_args_option())
}

#
# For headers, we want to remember ourself those that are ok for the prologue generation
#
sub _header_ok {
    my ($self, @headers) = @_;

    map { $self->{_headers_ok}->{$_}++ } @headers
}

sub _args_check_header {
  my ($self, $header) = @_;

  my @args_check = $self->_args_check($header);
  $args_check[1]->{action_on_true} = sub { $self->_header_ok($header) };

  return @args_check
}

#
# For check_headers callback, semantic is different
#
sub _args_check_headers {
  my ($self) = @_;

  my @args_check = ($self->_args_option());
  $args_check[1]->{action_on_header_true} = sub { $self->_header_ok(@_) };

  return @args_check
}

sub _process_from_config {
    my ($self, %args) = @_;

    my $section    = $args{section}   || croak 'Internal error, section not set';
    my $stub_name  = $args{stub_name} || croak 'Internal error, stub_name not set';
    my $stub_names = $args{stub_names} // {};
    my $force_msg  = $args{force_msg} // '';
    my $args       = $args{args};

    my $sectionp = $self->{_config_ini}->{$section};
    $sectionp //= {};

    while (my ($key, $rhs) = each(%{$sectionp})) {
        #
        # No check if rhs is not a true value
        #
        next unless $rhs;

        #
        # Get the implementation
        #
        my $stub_realname = $stub_names->{$key} || $stub_name;
        my $stub_code = $self->can($stub_realname);
        if (! $stub_code) {
          #
          # We warn because this should not happen
          #
          warn "$self cannot \"$stub_realname\"";
          next;
        }

        #
        # If there is an explicit implementation it is assumed
        # that it is handling itself any message
        #
        $force_msg = '' if $stub_realname ne $stub_name;

        #
        # Do the work
        #
        $self->msg_checking(sprintf($force_msg, $key)) if $force_msg;
        my @args = $args ? $self->$args($key) : ($key);
        my $value = $self->$stub_code(@args);
        $self->define_var($rhs, $value) unless looks_like_number($rhs);
        $self->msg_result($value ? 'yes' : 'no') if $force_msg;
    }

    $self
}

=head1 EXAMPLE

Here is an example of a .ini file:

  [includes]
  . = 1
  /this/path = 1

  [preprocess_flags]
  -DFLAG01 = 1
  -DFLAG02 = 0

  [compiler_flags]
  -DFLAG01 = 0
  -DFLAG02 = 1

  [link_flags]
  -lm = 1
  -loff = 0

  [bundle]
  stdc_headers = 1
  default_headers = 1
  dirent_headers = 1

  [files]
  /etc/passwd = HAVE_ETC_PASSWD
  /tmp/this = HAVE_THIS
  /tmp/that = HAVE_THAT
  C:\Windows\Temp\foo = HAVE_C_WINDOWS_TEMP_FOO

  [progs]
  cc = CC_NAME

  [headers]
  stdio.h = 1
  stddef.h = HAVE_STDDEF_H
  time.h = 1

  [decls]
  read = 1
  notchecked = 0

  [funcs]
  read = 1

  [types]
  size_t = 1

  [sizeof_types]
  size_t = 1

  [alignof_types]
  struct tm.tm_year = 1

  [members]
  struct tm.tm_year = 1

=head1 SEE ALSO

L<Config::AutoConf>

=cut

1;
