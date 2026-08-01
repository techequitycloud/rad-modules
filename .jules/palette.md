## 2024-08-01 - [UIMeta Group Alignment]
**Learning:** Application-specific variables (like deploy_application with order=601) sometimes incorrectly default to group=0 instead of matching their logical section group (e.g., group=6). This causes application settings to render on the Provider/Metadata wizard page instead of the Application page.
**Action:** Always verify that group=N aligns with the hundreds digit of order=Nxx and the standard section ordering in SKILLS.md.
