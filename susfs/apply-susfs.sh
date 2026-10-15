#!/bin/bash
# Apply simonpunk susfs4ksu kernel-side patches (branch kernel-4.14) plus
# begonia-specific fixups for the 2 hunks that don't apply cleanly:
#   - fs/proc/cmdline.c (begonia has CONFIG_PROC_BEGONIA_CMDLINE)
#   - kernel/sys.c (MTK fake_comm spoofing shifts context)
# Also drops BakaSU's self-update guard
# (KernelSU/kernel/tools/susfs_compat.mk unconditional $(error)).
# Must run in kernel source root, AFTER BakaSU setup.sh. Idempotent.
set -e

SUSFS_URL="https://gitlab.com/simonpunk/susfs4ksu.git"
SUSFS_BRANCH="kernel-4.14"
SUSFS_PATCH="50_add_susfs_in_kernel-4.14.patch"

if [ ! -d /tmp/susfs4ksu ]; then
    git clone --depth=1 -b "$SUSFS_BRANCH" "$SUSFS_URL" /tmp/susfs4ksu
fi
P=/tmp/susfs4ksu/kernel_patches

cp -f $P/fs/* fs/
cp -f $P/include/linux/* include/linux/
echo "susfs sources copied"

# BakaSU compat: kernel supercall.c matches magic2 against SUSFS_MAGIC,
# defined only in BakaSU userspace (ksud/.../susfs/api/magic.rs = 0xFAFA_FAFA).
# susfs v1.5.5 headers predate it, so provide it here.
if ! grep -q "define SUSFS_MAGIC" include/linux/susfs_def.h; then
    printf '\n/* BakaSU compat: must match SUSFS_MAGIC in ksud susfs api */\n#define SUSFS_MAGIC 0xFAFAFAFAu\n' >> include/linux/susfs_def.h
    echo "SUSFS_MAGIC added"
fi

patch -p1 --forward < $P/$SUSFS_PATCH || true
echo "base patch applied (failures, if any, fixed below)"

python3 - <<'EOF'
def ensure(path, marker, anchor, block, before=False):
    with open(path) as f:
        t = f.read()
    if marker in t:
        print(f"already present in {path}")
        return
    assert anchor in t, f"anchor missing in {path}"
    if before:
        t = t.replace(anchor, block + anchor, 1)
    else:
        t = t.replace(anchor, anchor + block, 1)
    open(path, 'w').write(t)
    print(f"fixup applied to {path}")

# fs/proc/cmdline.c: spoof hook (upstream hunk fails on begonia cmdline)
ensure('fs/proc/cmdline.c',
       'susfs_spoof_cmdline_or_bootconfig',
       '#include <asm/setup.h>\n',
       '\n#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG\n'
       'extern int susfs_spoof_cmdline_or_bootconfig(struct seq_file *m);\n'
       '#endif\n')

with open('fs/proc/cmdline.c') as f:
    t = f.read()
if 'if (!susfs_spoof_cmdline_or_bootconfig(m))' not in t:
    old = 'static int cmdline_proc_show(struct seq_file *m, void *v)\n{\n'
    assert old in t
    t = t.replace(old, old +
        '#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG\n'
        '\tif (!susfs_spoof_cmdline_or_bootconfig(m)) {\n'
        "\t\tseq_putc(m, '\\n');\n"
        '\t\treturn 0;\n'
        '\t}\n'
        '#endif\n', 1)
    open('fs/proc/cmdline.c', 'w').write(t)
    print("cmdline show hook added")
else:
    print("cmdline show hook already present")

# kernel/sys.c: uname spoof hook (upstream hunk fails on MTK fake_comm block)
ensure('kernel/sys.c',
       'susfs_spoof_uname',
       'SYSCALL_DEFINE1(newuname, struct new_utsname __user *, name)',
       '#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\n'
       'extern void susfs_spoof_uname(struct new_utsname* tmp);\n'
       '#endif\n',
       before=True)
with open('kernel/sys.c') as f:
    t = f.read()
if 'susfs_spoof_uname(&tmp);' not in t:
    old = '\tdown_read(&uts_sem);\n\tmemcpy(&tmp, utsname(), sizeof(tmp));\n'
    assert old in t
    t = t.replace(old, old +
        '#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\n'
        '\tsusfs_spoof_uname(&tmp);\n'
        '#endif\n', 1)
    open('kernel/sys.c', 'w').write(t)
    print("uname spoof hook added")
else:
    print("uname spoof hook already present")
EOF

# BakaSU self-update guard: upstream blocks SUSFS until simonpunk syncs.
# We ported the hooks ourselves, so drop the unconditional $(error).
sed -i '/susfs has NOT update with latest KernelSU source/d; /Please wait simonpunk update/d; /Please wait susfs update/d' \
    KernelSU/kernel/tools/susfs_compat.mk
echo "susfs_compat.mk guard removed"

find . -name "*.rej" -delete -o -name "*.orig" -delete

# Stub BakaSU dispatch entries for susfs features missing on 4.14 (v1.5.5).
# stub-dispatch.sh lives next to this script in the action repo (susfs/);
# fall back to no-op when running standalone.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/stub-dispatch.sh" ]; then
    bash "$SCRIPT_DIR/stub-dispatch.sh"
fi

echo "verifying:"
grep -c "susfs_spoof_cmdline_or_bootconfig" fs/proc/cmdline.c
grep -c "susfs_spoof_uname" kernel/sys.c
ls fs/susfs.c include/linux/susfs.h
echo "susfs apply OK"
