#!/bin/bash
#
# Test core assignment with MPI
#
: slaves=${slaves:=4}
: jobs=${jobs:=3}
: mpi=${mpi:=1}
export affinity=${affinity:=0}
num_cores=$(( $slaves * $jobs ))

if (( $(nproc) < $num_cores )); then
    echo '$slaves * $jobs < $(nproc)' 1>&2
    echo "usage: mpi=0/1 affinity=0/1 jobs=N slaves=M bash $(basename $0)" 1>&2
    exit 1
fi

master_pids=()
for i in $(seq $jobs); do
    base=$(( ($i - 1) * $slaves ))
    if (( $mpi )); then
        mpiexec --bind-to none -n "$slaves" python pi.py "$base" < /dev/null >& /dev/null &
    else
        python pi.py "$base" "$slaves" &
    fi
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
    echo "FAIL: Only ${#cores_in_use[@]} in use (expecting $num_cores)"
fi
kill "${master_pids[@]}" >& /dev/null
wait >& /dev/null
