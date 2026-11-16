#!/usr/bin/env bash
# Turn `tofu show -json` into an inventory that is safe to keep in build-logs/.
#
#   redact_state_json.sh <full-state.json> <inventory.json>
#
# The destroy pipeline used to upload the full `tofu show -json` document as
# its audit record. That document carries every attribute of every resource in
# PLAINTEXT, sensitive ones included (database passwords, generated keys,
# tokens passed as variables) -- `sensitive` only masks the human-readable
# output, never the JSON. build-logs/ is removed by nothing but a 400-day
# lifecycle rule, so a destroyed deployment's secrets outlived it by over a
# year. Nothing reads values from the uploaded object; an audit needs to know
# WHAT was destroyed, not what it held.
#
# The output is BUILT from a fixed list of fields, never derived by deleting
# the dangerous ones: a field a future OpenTofu adds is then absent by default
# instead of uploaded by default. Kept per resource: address, mode, type, name,
# provider, and the module path. Outputs keep their name and sensitive flag,
# never a value.
#
# It walks child modules. The pipeline's own `.values.root_module.resources`
# listings do not, so for a module built from child modules this inventory is
# the complete one.
#
# Fails CLOSED: on any error the output file is removed and the exit code is
# non-zero, so a caller cannot upload a partial or unredacted document by
# mistake. Callers must upload ONLY the output of a successful run.
set -u

IN="${1:-}"
OUT="${2:-}"
if [ -z "$IN" ] || [ -z "$OUT" ]; then
    echo "usage: redact_state_json.sh <full-state.json> <inventory.json>" >&2
    exit 2
fi

rm -f "$OUT"
TMP="${OUT}.tmp.$$"

# shellcheck disable=SC2016  # $m is a jq variable, not a shell one
if jq '
    def modules: ., (.child_modules[]? | modules);
    {
      redacted: true,
      note: "Inventory only. Attribute values and output values are never stored.",
      format_version: (.format_version // null),
      terraform_version: (.terraform_version // null),
      resources: [
        (.values.root_module // {}) | modules
        | (.address // "") as $m
        | .resources[]?
        | {
            address: (.address // null),
            mode: (.mode // null),
            type: (.type // null),
            name: (.name // null),
            provider_name: (.provider_name // null),
            module: $m
          }
      ],
      outputs: [
        (.values.outputs // {}) | to_entries[]
        | { name: .key, sensitive: (.value.sensitive // false) }
      ]
    }
    | .resource_count = (.resources | length)
' "$IN" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
    mv "$TMP" "$OUT"
    exit 0
fi

rm -f "$TMP" "$OUT"
echo "redact_state_json.sh: could not build an inventory from $IN" >&2
exit 1
