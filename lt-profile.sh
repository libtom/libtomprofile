#!/usr/bin/env bash

set -e

readonly ltc="../libtomcrypt"
readonly ltm="../libtommath"
readonly results_dir="$(readlink -f "$(date +%y%m%d%H%M)")"

declare -a ltm_branches

analyze=
check_git=1
ltc_debug=
ltm_debug=
gnuplot_terminal="svg enhanced background rgb 'white'"

while getopts dfhpa:c:m: opt
do
  case $opt in
    a)  analyze="$OPTARG";;
    f)  check_git=;;
    d)  ltc_debug="LTC_DEBUG=1"
        ltm_debug="COMPILE_DEBUG=1";;
    m)  ltm_branches+=("$OPTARG");;
    p)  gnuplot_terminal="png";;
    h|?)  printf "Usage: %s: [-dfhp] [-a directory] [-m ltm-branch [-m ...]]\n\n" $0
        printf "    -a directory    Analyze the results of a previous run from the\n"
        printf "                    'directory' given.\n"
        printf "                    This only analyzes the results.\n"
        printf "    -d              Enable debug builds.\n"
        printf "    -f              Force execution, don't check if repo's are clean.\n"
        printf "    -h              This help.\n"
        printf "    -m ltm-branch   Add a libtommath branch that should be processed.\n"
        printf "    -p              Generate PNG's instead of SVG's.\n"
        printf "                                                                       \n"
        printf "\n"
        exit 2;;
  esac
done


[ -d "$ltc" ] && [ -d "$ltm" ]


function _check_git() {
  git -C "$1" update-index --refresh
  git -C "$1" diff-index --quiet HEAD -- . || ( echo "FAILURE: $*" && exit 1 )
}

if [ $check_git ]; then
  _check_git "$ltc"
  _check_git "$ltm"
fi

_check_git "$ltm"

if [ -z $analyze ]; then
  mkdir -p "$results_dir"
  analyze="$results_dir"
  for b in "${ltm_branches[@]}"
  do
    git -C "$ltm" checkout "$b"
    make -C "$ltm" clean
    make -C "$ltm" -j9
    touch "$ltc"/demos/timing.c
    make -C "$ltc" timing -j9 EXTRALIBS="$ltm/libtommath.a" CFLAGS="-DUSE_LTM -DLTM_DESC -DTIMING_DONT_MAKE_KEY -I$ltm" $ltc_debug V=0
    pushd "$ltc"
    branch=$(echo $b | tr '/\\' '_')
    ./timing rsa > "$results_dir"/rsa_"$branch".csv
    ./timing ecc > "$results_dir"/ecc_"$branch".csv
    popd
  done
fi

for alg in ecc rsa
do
  for op in encrypt_key decrypt_key sign_hash verify_hash
  do
    plotstring=
    for b in "${ltm_branches[@]}"
    do
      branch=$(echo $b | tr '/\\' '_')
      csvgrep -c operation -r "$op" "$analyze"/"$alg"_"$branch".csv | csvcut -c keysize,ticks | tail -n +2 | tr ',' ' ' > "$analyze"/"$alg"_"$branch"_"$op".log
      [ -z "$plotstring" ] && plotstring="plot" || plotstring="${plotstring},"
      plotstring="${plotstring} '"$analyze"/"$alg"_"$branch"_"$op".log' smooth bezier title \"$b\""
    done
    algop=$(echo "${alg}_${op}" | sed -e 's@_@\\\\\_@g')
    gnuplot << EOF
set terminal $gnuplot_terminal
set ylabel "Cycles per Operation"
set xlabel "Operand size (bits)"
set title "${algop}"

set output "${alg}_${op}.${gnuplot_terminal%% *}"
$plotstring
EOF
  done
done
