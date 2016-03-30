#!/bin/bash
#
# Test core assignment with MPI
#
: slaves=${slaves:=4}
: jobs=${jobs:=3}
export affinity=${affinity:=0}
num_cores=$(( $slaves * $jobs ))

if (( $(nproc) < $num_cores )); then
    echo '$slaves * $jobs < $(nproc)' 1>&2
    echo "usage: jobs=N slaves=M bash $(basename $0)" 1>&2
    exit 1
fi

cat > pi.py <<'EOF'
#!/usr/bin/env python
import os


def set_core():
    from mpi4py import MPI
    import os
    import subprocess
    import sys

    comm = MPI.COMM_WORLD
    rank = comm.Get_rank()
    base = int(sys.argv[1])
    core = base + rank
    subprocess.check_call(['/bin/taskset', '-cp', str(core), str(os.getpid())])


def compute_pi():
    from decimal import Decimal, getcontext

    getcontext().prec=1500
    sum(
        1/Decimal(16)**k *
        (Decimal(4)/(8*k+1) -
         Decimal(2)/(8*k+4) -
         Decimal(1)/(8*k+5) -
         Decimal(1)/(8*k+6)) for k in range(1500))


if int(os.environ.get('affinity', 0)):
    set_core()
compute_pi()
EOF

master_pids=()
for i in $(seq $jobs); do
    mpiexec -n $slaves python pi.py "$(( ($i - 1) * $slaves ))" < /dev/null >& /dev/null &
    master_pids+=( $! )
    sleep 1
done

ps=( ps -o psr,ppid,pid,args ax )
ps_grep() {
    "${ps[@]}" | grep 'python pi.py' | egrep -v 'mpiexec|grep'
}

cores_in_use=( $(ps_grep | colrm 4 | sort -u) )
if (( ${#cores_in_use[@]} == $num_cores )); then
    echo PASS
else
    "${ps[@]}" | head -1
    ps_grep | sort -n
    echo "FAIL: ${#cores[@]}"
fi
kill "${master_pids[@]}" >& /dev/null
wait
