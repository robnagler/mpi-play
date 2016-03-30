#!/bin/bash
#
# Test core assignment with MPI
#
: slaves=${slaves:=4}
: jobs=${jobs:=3}
cores=$(( $slaves * $jobs ))

if (( $(nproc) < $cores )); then
    echo '$slaves * $jobs < $(nproc)' 1>&2
    echo "usage: jobs=N slaves=M bash $(basename $0)" 1>&2
    exit 1
fi

cat > pi.py <<'EOF'
from mpi4py import MPI
from decimal import Decimal, getcontext

getcontext().prec=1500
sum(
    1/Decimal(16)**k *
    (Decimal(4)/(8*k+1) -
     Decimal(2)/(8*k+4) -
     Decimal(1)/(8*k+5) -
     Decimal(1)/(8*k+6)) for k in range(1500))
EOF

procs=()
for i in $(seq $jobs); do
    mpiexec -n $slaves python pi.py < /dev/null >& /dev/null &
    procs+=( $! )
    sleep 1
done

ps=( ps -o psr,ppid,pid,args ax )
ps_grep() {
    "${ps[@]}" | grep 'python pi.py' | egrep -v 'mpiexec|grep'
}
x=( $(ps_grep | colrm 4 | sort -u) )
if (( ${#x[@]} == $cores )); then
    echo PASS
else
    "${ps[@]}" | head -1
    ps_grep | sort -n
    echo "FAIL: ${#x[@]}"
fi
kill "${procs[@]}"
wait
