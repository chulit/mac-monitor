# 08: Privileged helper necessity verdict

**What to build:** an evidence-backed verdict on whether a privileged helper is needed for any metric, with a least-privilege design if yes.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [ ] Each metric documents whether unprivileged collection suffices, with evidence
- [ ] If a helper is needed: narrow operations only, least privilege, transparent install and removal
- [ ] If not needed: the verdict records why, and no helper ships
