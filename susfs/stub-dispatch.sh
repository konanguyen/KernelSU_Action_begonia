#!/bin/bash
# Stub out 4 susfs commands that BakaSU's dispatch.c expects but susfs v1.5.5
# for kernel 4.14 does not implement:
#   CMD_SUSFS_ADD_SUS_PATH_LOOP, CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS,
#   CMD_SUSFS_ADD_SUS_MAP, CMD_SUSFS_ENABLE_AVC_LOG_SPOOFING
# Unknown commands fall through to the switch default (error to manager =
# "unsupported", same as a kernel without those features).
# Must run in kernel source root, AFTER BakaSU setup.sh. Idempotent.
set -e

F=KernelSU/kernel/supercall/dispatch.c
[ -f "$F" ] || { echo "missing $F"; exit 1; }

python3 - <<'EOF'
import re
p = 'KernelSU/kernel/supercall/dispatch.c'
with open(p) as f:
    t = f.read()
orig = t

blocks = [
    # case CMD_SUSFS_ADD_SUS_PATH_LOOP: { susfs_add_sus_path_loop(arg); return 0; }
    r'    case CMD_SUSFS_ADD_SUS_PATH_LOOP: \{\n        susfs_add_sus_path_loop\(arg\);\n        return 0;\n    \}\n',
    # case CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS: { ... }
    r'    case CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS: \{\n        susfs_set_hide_sus_mnts_for_non_su_procs\(arg\);\n        return 0;\n    \}\n',
    # case CMD_SUSFS_ADD_SUS_MAP: { ... }
    r'    case CMD_SUSFS_ADD_SUS_MAP: \{\n        susfs_add_sus_map\(arg\);\n        return 0;\n    \}\n',
    # case CMD_SUSFS_ENABLE_AVC_LOG_SPOOFING: { ... }
    r'    case CMD_SUSFS_ENABLE_AVC_LOG_SPOOFING: \{\n        susfs_set_avc_log_spoofing\(arg\);\n        return 0;\n    \}\n',
]
for b in blocks:
    t = re.sub(b, '', t)

if t != orig:
    open(p, 'w').write(t)
    print("dispatch.c: unsupported susfs commands stubbed")
else:
    print("dispatch.c: already stubbed")
EOF

echo "checking no other missing CMD_ remain:"
if grep -o "CMD_SUSFS_[A-Z_]*" "$F" | sort -u | while read c; do
    grep -q "$c" include/linux/susfs_def.h || echo "STILL MISSING: $c"
done | grep .; then
    echo "ERROR: missing commands remain"; exit 1
fi
echo "dispatch stub OK"
