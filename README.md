# SBG toolchain generator

Build script to generate GCC-based toolchains.

While there already are various solutions that do this, some of the needs
at SBG Systems, such as support for modern C++ on TI C6X DSPs, have
motivated this project.

This script uses GCC version 13, but the patches should apply cleanly on
the latest versions as well, since the c6x target hasn't been changed much
in years.

## Thread-safe C++ exception handling

### ARM

Official ARM toolchains are not built with TLS support enabled, which is
required for C++ exception handling to be thread-safe. Toolchains built
by this project enables TLS, which then requires some support at the
application/OS level, according to the [ARM run-time ABI][ref1].

### C6000

For TI C6000 (c6x) targets, there is simply no existing official GCC
toolchain, and GCC doesn't implement TLS support at all. As a result,
toolchains build by this generator override the GCC TLS emulation layer
to augment the [C6000 ABI][ref2]. As for ARM targets, this requires support at
application/OS level. See the gcc patch about thread-local storage to find
out how the TLS emulation layer has been overriden.

## C6000 exception handling type matching

The [C6000 ABI][ref2] specifies that type identifiers used by catch descriptors
must be encoded with the R\_C6000\_EHTYPE relocation type. That relocation
type is a DP-relative one, resolved with a symbol + addend - base address
operation, base address being the data pointer register, sometimes also
called the static base (SB) register.

However, GCC implement these relocations as DP-relative, GOT-indirect.
There seems to also be a bug concerning how GOT entries are referenced
from the data pointer register. In order to solve this issue, the binutils
and gcc submodules are patched so that EHTYPE relocations are processed
as specified in the C6000 ABI.

## References

- [ARM run-time ABI][ref1]
- [C6000 ABI][ref2]

[ref1]: https://github.com/ARM-software/abi-aa/blob/main/rtabi32/rtabi32.rst
[ref2]: https://www.ti.com/lit/sprab89
