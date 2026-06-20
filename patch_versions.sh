sed -i 's/    aws = {/    google-beta = {\n      source  = "hashicorp\/google-beta"\n      version = ">= 5.0, < 8.0"\n    }\n    aws = {/g' modules/Migration_Center/versions.tf
