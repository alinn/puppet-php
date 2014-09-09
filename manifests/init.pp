# == Class: php
#
# PHP base class
#
# === Parameters
#
# [*ensure*]
#   Specify which version of PHP packages to install, defaults to 'latest'.
#   Please note that 'absent' to remove packages is not supported!
#
# [*manage_repos*]
#   Include repository (dotdeb, ppa, etc.) to install recent PHP from
#
# [*fpm*]
#   Install and configure php-fpm
#
# [*dev*]
#   Install php header files, needed to install pecl modules
#
# [*composer*]
#   Install and auto-update composer
#
# [*pear*]
#   Install PEAR
#
# [*phpunit*]
#   Install phpunit
#
# [*extensions*]
#   Install PHP extensions, this is overwritten by hiera hash `php::extensions`
#
# === Authors
#
# Robin Gloster <robin.gloster@mayflower.de>
# Franz Pletz <franz.pletz@mayflower.de>
#
# === Copyright
#
# See LICENSE file
#
class php (
  $ensure       = 'latest',
  $manage_repos = $php::params::manage_repos,
  $fpm          = true,
  $dev          = true,
  $composer     = true,
  $pear         = true,
  $phpunit      = false,
  $extensions   = {},
  $settings     = {}
) inherits php::params {
  validate_string($ensure)
  validate_bool($manage_repos)
  validate_bool($fpm)
  validate_bool($dev)
  validate_bool($composer)
  validate_bool($pear)
  validate_bool($phpunit)
  validate_hash($extensions)
  validate_hash($settings)

  if $manage_repos {
    anchor{ 'php::repo': } ->
      class { 'php::repo': } ->
    Anchor['php::begin']
  }

  anchor { 'php::begin': } ->
    class { 'php::packages': } ->
    class { 'php::cli':
      settings => $settings
    } ->
  anchor { 'php::end': }

  if $fpm {
    Anchor['php::begin'] ->
      class { 'php::fpm':
        settings => $settings
      } ->
    Anchor['php::end']
  }
  if $dev {
    Anchor['php::begin'] ->
      class { 'php::dev': } ->
    Anchor['php::end']
  }
  if $composer {
    Anchor['php::begin'] ->
      class { 'php::composer': } ->
    Anchor['php::end']
  }
  if $pear {
    Anchor['php::begin'] ->
      class { 'php::pear': } ->
    Anchor['php::end']
  }
  if $phpunit {
    Anchor['php::begin'] ->
      class { 'php::phpunit': } ->
    Anchor['php::end']
  }

  # FIXME: for deep merging support we need a explicit hash lookup instead of automatic parameter lookup
  #        (https://tickets.puppetlabs.com/browse/HI-118)
  $real_settings = hiera_hash('php::settings', $settings)

  $real_extensions = hiera_hash('php::extensions', $extensions)

  if $::osfamily == 'Gentoo' {
    # add the extensions which are in fact USE flags to a package.use definition
    # plus the apache and fpm settings turned into USE flags
    $extension_flags = intersection(keys($real_extensions), $php::params::php_flags)

    if $fpm {
        $flags = concat(['fpm'], $extension_flags)

        package_use { 'app-admin/eselect-php':
            ensure => present,
            use    => ['fpm'],
            target => 'php',
            before => Package_use[$php::params::cli_package]
        }
    } else {
        $flags = $extension_flags
    }
    package_use { $php::params::cli_package:
      ensure => present,
      use    => $flags,
      slot   => $php::params::php_slot,
      target => "php-${php::params::php_slot}",
    }
  }
  create_resources('php::extension', $real_extensions, {
    ensure  => $ensure,
    require => Class['php::cli'],
    before  => Anchor['php::end']
  })
}
