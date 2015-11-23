`groupvpn-config` generates GroupVPN configurations for you. It can
output a zip archive containing the configuration files, and it can
provide the `ejabberdctl` commands needed to set up the Jabber accounts
and relationships.

Usage
-----

Start by viewing the help message:

    $ groupvpn-config --help

A very basic invocation, which just prints `ejabberdctl` commands and
configuration data in a readable format, is:

    $ groupvpn-config testgroup localhost 5

Passwords are randomly generated, so if you need to generate the same
passwords on multiple runs of the tool, you can pass a string to be used
as a random seed using the `--seed` option:

    $ groupvpn-config testgroup localhost 5 --seed asdfghjkl

If you want configuration files in a zip file:

    $ groupvpn-config testgroup localhost 5 --zip >configs.zip

By default, `ejabberdctl` commands are printed but not run. Use the
`--configure` flag to actually run them:

    $ groupvpn-config testgroup localhost 5 --configure --zip >configs.zip

Or maybe you want to save the commands to a file to run later (the
commands are printed to `stderr`):

    $ groupvpn-config testgroup localhost 5 --zip >configs.zip 2>commands.sh

If you want to see only `ejabberdctl` commands or only configuration
data printed, you can redirect one of the output streams to /dev/null:

    $ groupvpn-config testgroup localhost 5 2>/dev/null

Installing dependencies
-----------------------

The only dependency needed by this script is
[`ipaddress`](https://pypi.python.org/pypi/ipaddress/1.0.6) (a
backport of the identically-named module in Python 3.3+).

The easiest way to install dependencies is in using `virtualenv`:

    $ git clone https://github.com/kalgynirae/groupvpn-config.git
    $ cd groupvpn-config
    $ virtualenv env
    $ env/bin/pip install -e .

This will install a wrapper script into `env/bin/groupvpn-config` which
takes care of running the script in the correct environment.
