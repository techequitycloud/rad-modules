#!/bin/bash
for dir in modules/Bank_GKE modules/MC_Bank_GKE; do
  find $dir -name "*.tf" -exec sed -i -e 's|^\s*// |# |g' -e 's|^\s*//# |# |g' -e 's|^\s*//|#|g' {} +
done

# Fix missing random version
sed -i '/required_providers {/a \    random = {\n      source  = "hashicorp/random"\n      version = ">= 3.0"\n    }' modules/Bank_GKE/versions.tf
sed -i '/required_providers {/a \    random = {\n      source  = "hashicorp/random"\n      version = ">= 3.0"\n    }' modules/MC_Bank_GKE/versions.tf

# Fix missing null version
sed -i '/required_providers {/a \    null = {\n      source  = "hashicorp/null"\n      version = ">= 3.0"\n    }' modules/Bank_GKE/versions.tf
sed -i '/required_providers {/a \    null = {\n      source  = "hashicorp/null"\n      version = ">= 3.0"\n    }' modules/MC_Bank_GKE/versions.tf

# Fix missing local version in MC_Bank_GKE
sed -i '/required_providers {/a \    local = {\n      source  = "hashicorp/local"\n      version = ">= 2.0"\n    }' modules/MC_Bank_GKE/versions.tf

# Fix google-beta version in Bank_GKE
sed -i '/required_providers {/a \    google-beta = {\n      source  = "hashicorp/google-beta"\n      version = ">= 5.0"\n    }' modules/Bank_GKE/versions.tf
