/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Windows Server 2022 VM that hosts the MC Discovery Client (MCDCv6).
# The sysprep startup script runs on first boot and:
#   1. Creates the migrationcenter local user with the lab RDP password
#   2. Enables RDP and adds the user to Remote Desktop Users
#   3. Silently downloads and installs MCDCv6
#   4. Pre-downloads the AWS sample import zip to the Downloads folder
#   5. Installs Google Chrome (required by MCDCv6 OAuth browser flow)
resource "google_compute_instance" "windows_vm" {
  count        = var.create_windows_vm ? 1 : 0
  project      = local.project.project_id
  name         = local.windows_vm_name
  machine_type = var.windows_vm_machine_type
  zone         = var.zone

  tags = ["windows-vm"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
      size  = var.windows_vm_boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.lab_vpc.self_link
    access_config {}
  }

  metadata = {
    windows-startup-script-ps1 = <<-PS1
      # ── 1. Create lab user ──────────────────────────────────────────────────
      $labUser     = "migrationcenter"
      $labPassword = "m1grat10nc#nt#r"
      $securePass  = ConvertTo-SecureString $labPassword -AsPlainText -Force

      if (-not (Get-LocalUser -Name $labUser -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $labUser -Password $securePass `
          -FullName "Migration Center" -Description "Lab RDP user" `
          -PasswordNeverExpires
      } else {
        Set-LocalUser -Name $labUser -Password $securePass
      }
      Add-LocalGroupMember -Group "Administrators"        -Member $labUser -ErrorAction SilentlyContinue
      Add-LocalGroupMember -Group "Remote Desktop Users"  -Member $labUser -ErrorAction SilentlyContinue

      # ── 2. Enable RDP ───────────────────────────────────────────────────────
      Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" -Value 0
      Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

      # ── 3. Install Google Chrome ────────────────────────────────────────────
      $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
      if (-not (Test-Path $chromePath)) {
        $chromeInstaller = "$env:TEMP\ChromeSetup.exe"
        Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe" `
          -OutFile $chromeInstaller -UseBasicParsing
        Start-Process -FilePath $chromeInstaller -ArgumentList "/silent /install" -Wait
        Remove-Item $chromeInstaller -Force -ErrorAction SilentlyContinue
      }

      # ── 4. Download and silently install MCDCv6 ─────────────────────────────
      $mcdcUrl       = "https://storage.googleapis.com/mcdc-release/current/windows/mcdc.msi"
      $mcdcInstaller = "$env:TEMP\mcdc.msi"
      Invoke-WebRequest -Uri $mcdcUrl -OutFile $mcdcInstaller -UseBasicParsing
      Start-Process msiexec.exe -ArgumentList "/i `"$mcdcInstaller`" /quiet /norestart" -Wait
      Remove-Item $mcdcInstaller -Force -ErrorAction SilentlyContinue

      # ── 5. Pre-stage AWS import sample data ─────────────────────────────────
      $downloadsDir = "C:\Users\$labUser\Downloads"
      New-Item -ItemType Directory -Force -Path $downloadsDir | Out-Null
      $awsZipUrl  = "https://storage.googleapis.com/spls/gsp1095/vm-aws-import-files.zip"
      $awsZipPath = "$downloadsDir\vm-aws-import-files.zip"
      Invoke-WebRequest -Uri $awsZipUrl -OutFile $awsZipPath -UseBasicParsing
      Expand-Archive -Path $awsZipPath -DestinationPath "$downloadsDir\vm-aws-import-files" -Force

      Write-Output "VM Migration lab setup complete."
    PS1
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.lab_vpc,
  ]
}
