# Building & Tests

## Building

At this time, this software is not available on the CPAN. To use it, clone the
[GitHub repo](https://github.com/base64tokyo/GoGameTools).

You will need perl 5.20 or newer. GoGameTools only depends on modules that come
with perl, so you don't have to install any dependencies.

To install GoGameTools:

~~~
perl Build.PL
./Build
./Build install
~~~

## Installing site support files

~~~
mkdir -p ~/.local/share/gogametools
ln -s $(pwd)/site ~/.local/share/gogametools/
~~~

## Tests

~~~
prove
~~~

or

~~~
forkprove -Mlib::require::all=lib,t -j8 -lr ./t
~~~
