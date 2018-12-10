## [fastlane flint](https://docs.fastlane.tools/actions/flint/)

This repository contains all your keystores needed to build and sign your applications. They are encrypted using OpenSSL via a passphrase.

**Important:** Make sure this repository is set to private and only your team members have access to this repo.

Do not modify this file, as it gets overwritten every time you run _flint_.

### Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using

```
[sudo] gem install fastlane -NV
```

or alternatively using `brew cask install fastlane`

### Usage

Navigate to your project folder and run

```
fastlane flint development
```
```
fastlane flint release
```

For more information open [fastlane flint git repo](https://docs.fastlane.tools/actions/flint/)

### Content

#### certs

This directory contains all your keystores

------------------------------------

For more information open [fastlane flint git repo](https://docs.fastlane.tools/actions/flint/)
