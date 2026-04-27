## 2024-04-27 - Variables UIMeta Missing `group` Alignment
**Learning:** UIMeta elements `group` value must map correctly to the standard `SKILLS.md` format. Across all modules, variables that logically belong to a specific group are miscategorized as `group=0` or with incorrect orders.
**Action:** Re-align group values in all `variables.tf` files based on the `SKILLS.md` definition table.

## 2024-04-27 - Deployment ID Missing UIMeta
**Learning:** Across all modules, `deployment_id` is lacking a `{{UIMeta group=0 order=... }}` annotation, which means it relies on default UI parsing or gets omitted completely from the ordered UI.
**Action:** Add `{{UIMeta group=0 order=108 updatesafe }}` to `deployment_id` across all modules.
