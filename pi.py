#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Test parallel core assignment

:copyright: Copyright (c) 2016 RadiaSoft LLC.  All Rights Reserved.
:license: http://www.apache.org/licenses/LICENSE-2.0.html
"""
from __future__ import absolute_import, division, print_function
import os
import signal
import sys

_rank = None
_pids = []
_mpi = bool(int(os.environ.get('OMPI_UNIVERSE_SIZE', 0)))
_affinity = bool(int(os.environ.get('affinity', 0)))


def compute_pi():
    from decimal import Decimal, getcontext

    getcontext().prec=1500
    sum(
        1/Decimal(16)**k *
        (Decimal(4)/(8*k+1) -
         Decimal(2)/(8*k+4) -
         Decimal(1)/(8*k+5) -
         Decimal(1)/(8*k+6)) for k in range(1500))


def get_rank():
    global _rank
    if _mpi:
        from mpi4py import MPI
        comm = MPI.COMM_WORLD
        _rank = comm.Get_rank()
        return

    _rank = int(sys.argv[2]) - 1
    pids = []
    for i in range(_rank):
        pid = os.fork()
        if pid == 0:
            _rank = i
            return
        pids.append(pid)
    global _pids
    _pids = pids
    signal.signal(signal.SIGTERM, kill_slaves)


def kill_slaves(*args):
    for p in _pids:
        try:
            os.kill(p, signal.SIGTERM)
        except Exception:
            pass
    sys.exit(1)


def set_affinity():
    if not _affinity:
        return
    base = int(sys.argv[1])
    core = base + _rank
    import subprocess
    subprocess.check_call(['/bin/taskset', '-cp', str(core), str(os.getpid())])


def wait_slaves():
    for p in _pids:
        try:
            os.waitpid(p, 0)
        except Exception:
            pass


get_rank()
set_affinity()
compute_pi()
wait_slaves()
