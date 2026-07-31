## 2024-07-31 - UIMeta Group and Order Alignment
**Learning:** Variables with UIMeta order numbers corresponding to a specific logical section (e.g. order=5xx for section 5) are sometimes incorrectly assigned to group=0.
**Action:** Ensure the group=N value strictly aligns with the logical section and corresponds to the hundreds digit of its order=Nxx attribute (e.g., group=5 for order=5xx) to prevent them from appearing on the wrong wizard page.
