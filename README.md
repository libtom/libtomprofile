# Profiling for libtom projects

## dependencies

* cvskit
* gnuplot

## example usage

```sh
git clone https://github.com/libtom/libtommath.git
git clone https://github.com/libtom/libtomcrypt.git -b timing-benchmark
git clone https://github.com/libtom/libtomprofile.git
cd libtomprofile
./lt-profile.sh -m develop -m remove-warray -m support/1.x -p
```
