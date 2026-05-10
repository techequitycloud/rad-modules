## 2024-05-10 - UIMeta Group Assignments for Logical Sections
 **Learning:** Module variables occasionally default to `group=0` incorrectly (putting them on the first wizard page) rather than their logical section, which breaks the standard UIMeta variable ordering across different wizard pages as specified in `SKILLS.md`. For example, `deploy_application` was mapped to `group=0` rather than `group=6`.
 **Action:** When verifying UIMeta annotations, always check that the `group=N` matches the logical section rather than assuming `group=0` is correct.
