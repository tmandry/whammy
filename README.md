# Wammy

Wammy is a clone of the [i3 window manager](https://i3wm.org/) for OS X, built on [Hammerspoon](http://www.hammerspoon.org/). It's currently pre-alpha.

## Installation

### Install Hammerspoon
Wammy requires [Hammerspoon](http://www.hammerspoon.org/), and currently you must install from source. To do so:

```sh
$ git clone https://github.com/Hammerspoon/hammerspoon.git
$ open hammerspoon/Hammerspoon.xcodeproj
```

and run it inside Xcode.

### Install Wammy

```sh
$ cd ~/.hammerspoon
$ git clone https://github.com/tmandry/wammy.git
$ ln -s wammy/wm
```

### Set up your configuration
Copy the [sample config](https://github.com/tmandry/wammy/wiki/Sample-Config) to `~/.hammerspoon/init.lua`.

Finally, click the Hammerspoon icon and "Reload Config", and wammy is running.

## Usage

**Learn how to use i3 ([video](https://www.youtube.com/watch?v=Wx0eNaGzAZU), [user guide](https://i3wm.org/docs/userguide.html)).** The commands in the [sample config](https://github.com/tmandry/wammy/wiki/Sample-Config) are similar to its default commands, with the alt key being used and _actual vim keys (hjkl)_ being used to control direction.

## Development

### Running tests

```sh
$ brew install luarocks
$ luarocks install busted
$ cd path/to/wammy
$ busted
```
