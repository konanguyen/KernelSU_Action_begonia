#!/bin/bash
# Convert Suzaku-bka old MANUAL_HOOK-guarded KSU hooks to guard-less style
# required by BakaSU SUSFS inline-hook mode (see
# KernelSU/kernel/tools/inline_hook_check.mk).
# - hook guards: CONFIG_KSU_MANUAL_HOOK -> CONFIG_KSU
# - drop old bool-style branches forbidden by inline_hook_check:
#   ksu_init_rc_hook (fs/read_write.c), ksu_input_hook (drivers/input/input.c)
# Must run in kernel source root. Idempotent.
set -e

HOOK_FILES="fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/sys.c kernel/reboot.c drivers/input/input.c"

for f in $HOOK_FILES; do
    [ -f "$f" ] || { echo "missing $f"; exit 1; }
    sed -i 's/CONFIG_KSU_MANUAL_HOOK/CONFIG_KSU/g' "$f"
done
echo "guards switched to CONFIG_KSU"

python3 - <<'EOF'
import re

def patch(path, patterns):
    with open(path) as f:
        t = f.read()
    orig = t
    for pat, repl in patterns:
        t = re.sub(pat, repl, t, flags=re.M)
    if t != orig:
        open(path, 'w').write(t)
        print(f"patched {path}")
    else:
        print(f"already clean {path}")

# fs/read_write.c: drop ksu_init_rc_hook bool, call handler directly
patch('fs/read_write.c', [
    (r'extern bool ksu_init_rc_hook __read_mostly;\n', ''),
    (r'#ifdef CONFIG_KSU\n\tif \(unlikely\(ksu_init_rc_hook\)\)[ \t]*\n\t\tksu_handle_sys_read\(fd, &buf, &count\);\n#endif',
     '#ifdef CONFIG_KSU\n\tksu_handle_sys_read(fd, &buf, &count);\n#endif'),
])

# drivers/input/input.c: drop ksu_input_hook bool, call handler directly
patch('drivers/input/input.c', [
    (r'extern bool ksu_input_hook __read_mostly;\n', ''),
    (r'#ifdef CONFIG_KSU\n\tif \(unlikely\(ksu_input_hook\)\)\n\t\tksu_handle_input_handle_event\(&type, &code, &value\);\n#endif',
     '#ifdef CONFIG_KSU\n\tksu_handle_input_handle_event(&type, &code, &value);\n#endif'),
])
EOF

echo "checking forbidden old hooks are gone:"
if grep -rn "ksu_vfs_read_hook\|ksu_input_hook\|ksu_execveat_hook\|ksu_init_rc_hook" \
    fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/sys.c kernel/reboot.c drivers/input/input.c; then
    echo "ERROR: old hooks remain"; exit 1
fi
echo "hook conversion OK"
