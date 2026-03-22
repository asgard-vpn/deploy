#!/bin/bash

set -e

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
src_env_file=${script_dir}/amnezia.env.example
env_file=${script_dir}/amnezia.env

if [ -f ${env_file} ]; then
    exit 0
fi

cp ${src_env_file} ${env_file}

AWG_JC=$(shuf -i 4-12 -n 1)
AWG_JMIN=$(shuf -i 8-50 -n 1)
AWG_JMAX=$(shuf -i 80-250 -n 1)
AWG_S1=$(shuf -i 15-150 -n 1)
AWG_S2=$(shuf -i 15-150 -n 1)
while [ $((AWG_S1 + 56)) -eq $AWG_S2 ]; do \
    AWG_S2=$(shuf -i 15-150 -n 1)
done
AWG_H1=$(shuf -i 5-2147483647 -n 1)
AWG_H2=$(shuf -i 5-2147483647 -n 1)
while [ $AWG_H2 -eq $AWG_H1 ]; do AWG_H2=$(shuf -i 5-2147483647 -n 1); done
AWG_H3=$(shuf -i 5-2147483647 -n 1)
while [ $AWG_H3 -eq $AWG_H1 ] || [ $AWG_H3 -eq $AWG_H2 ]; do AWG_H3=$(shuf -i 5-2147483647 -n 1); done
AWG_H4=$(shuf -i 5-2147483647 -n 1)
while [ $AWG_H4 -eq $AWG_H1 ] || [ $AWG_H4 -eq $AWG_H2 ] || [ $AWG_H4 -eq $AWG_H3 ]; do AWG_H4=$(shuf -i 5-2147483647 -n 1); done
sed -i "s/^AWG_JC=.*/AWG_JC=$AWG_JC/" ${env_file}
sed -i "s/^AWG_JMIN=.*/AWG_JMIN=$AWG_JMIN/" ${env_file}
sed -i "s/^AWG_JMAX=.*/AWG_JMAX=$AWG_JMAX/" ${env_file}
sed -i "s/^AWG_S1=.*/AWG_S1=$AWG_S1/" ${env_file}
sed -i "s/^AWG_S2=.*/AWG_S2=$AWG_S2/" ${env_file}
sed -i "s/^AWG_H1=.*/AWG_H1=$AWG_H1/" ${env_file}
sed -i "s/^AWG_H2=.*/AWG_H2=$AWG_H2/" ${env_file}
sed -i "s/^AWG_H3=.*/AWG_H3=$AWG_H3/" ${env_file}
sed -i "s/^AWG_H4=.*/AWG_H4=$AWG_H4/" ${env_file}
echo "$Generated random obfuscation parameters:"
echo "  Jc=$AWG_JC Jmin=$AWG_JMIN Jmax=$AWG_JMAX"
echo "  S1=$AWG_S1 S2=$AWG_S2"
echo "  H1=$AWG_H1 H2=$AWG_H2 H3=$AWG_H3 H4=$AWG_H4"


