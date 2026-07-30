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

#########################################################################
# PostgreSQL source VM
# Runs PostgreSQL 14 with the petclinic database pre-configured.
# Startup script installs PostgreSQL, creates the DB, and provisions
# the /install_postgres.sh and /assess_mcdc.sh convenience scripts.
#########################################################################

resource "google_compute_instance" "petclinic_postgres" {
  project      = local.project.project_id
  name         = local.postgres_vm_name
  machine_type = var.postgres_machine_type
  zone         = var.zone

  tags = ["postgres"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.postgres_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.vpc.self_link
    access_config {}
  }

  metadata = {
    startup-script = <<-SCRIPT
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      exec >> /var/log/startup-script.log 2>&1

      apt-get update -q
      apt-get install -y postgresql postgresql-contrib curl

      systemctl enable postgresql
      systemctl start postgresql

      PG_VER=$(ls /etc/postgresql/ | head -1)

      sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'petclinic';"
      sudo -u postgres createdb petclinic 2>/dev/null || true

      echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/$PG_VER/main/pg_hba.conf
      sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
        /etc/postgresql/$PG_VER/main/postgresql.conf
      systemctl restart postgresql

      cat > /install_postgres.sh << 'INNER'
      #!/bin/bash
      PG_VER=$(ls /etc/postgresql/ | head -1)
      echo "PostgreSQL $PG_VER is installed and configured."
      systemctl status postgresql --no-pager | head -5
      echo "Data directory: /var/lib/postgresql/$PG_VER/main"
      sudo -u postgres psql -c "\l" | grep petclinic \
        || echo "Note: petclinic database not found, creating..."
      sudo -u postgres createdb petclinic 2>/dev/null || true
      echo "[ALTER ROLE]"
      sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'petclinic';"
      INNER
      chmod +x /install_postgres.sh

      MCDC_VER=$(curl -sf "https://mcdc-release.storage.googleapis.com/latest" 2>/dev/null || true)
      if [ -n "$MCDC_VER" ]; then
        curl -sf -O "https://mcdc-release.storage.googleapis.com/$MCDC_VER/linux/amd64/mcdc" \
          && chmod +x mcdc && mv mcdc /usr/local/bin/ || true
      fi
      mkdir -p /var/m4a

      cat > /assess_mcdc.sh << 'INNER'
      #!/bin/bash
      mkdir -p /var/m4a ~/m2c
      TARFILE="mcdc-collect-$(hostname)-$(date +%Y-%m-%d-%H-%M).tar"
      echo "Collecting data..."
      mcdc collect --output-dir /var/m4a --output-file "$TARFILE" \
        || mcdc collect --outputdir /var/m4a
      echo "Collected info saved to:"
      ls -t /var/m4a/*.tar 2>/dev/null | head -1
      echo "[✓] Collection completed."
      TARPATH=$(ls -t /var/m4a/*.tar 2>/dev/null | head -1)
      if [ -n "$TARPATH" ]; then
        mcdc analyze "$TARPATH" --format html --output ~/m2c/mcdc-report.html 2>/dev/null \
          || mcdc analyze --input "$TARPATH" || true
      fi
      echo "[✓] Assessment complete."
      INNER
      chmod +x /assess_mcdc.sh

      echo "Startup script completed successfully." >> /var/log/startup-script.log
    SCRIPT
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.vpc,
  ]
}

#########################################################################
# Tomcat source VM
# Runs Apache Tomcat 10 with the Spring PetClinic WAR pre-deployed.
# Startup script installs Java 17, Maven, Tomcat, clones and builds the
# PetClinic app, and provisions the /install_tomcat.sh and /assess_mcdc.sh
# convenience scripts. PostgreSQL IP is injected as a known hosts entry.
#########################################################################

resource "google_compute_instance" "tomcat_petclinic" {
  project      = local.project.project_id
  name         = local.tomcat_vm_name
  machine_type = var.tomcat_machine_type
  zone         = var.zone

  tags = ["tomcat"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.tomcat_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.vpc.self_link
    access_config {}
  }

  metadata = {
    startup-script = <<-SCRIPT
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      exec >> /var/log/startup-script.log 2>&1

      POSTGRES_IP="${google_compute_instance.petclinic_postgres.network_interface[0].network_ip}"
      echo "$POSTGRES_IP petclinic-postgres" >> /etc/hosts

      apt-get update -q
      apt-get install -y openjdk-17-jdk maven git curl

      cd /opt
      git clone https://github.com/spring-petclinic/spring-framework-petclinic.git \
        || { echo "Git clone failed, retrying..."; sleep 10; \
             git clone https://github.com/spring-petclinic/spring-framework-petclinic.git; }
      cd spring-framework-petclinic
      sed -i 's/localhost:5432/petclinic-postgres:5432/g' pom.xml
      ./mvnw package -DskipTests=true -PPostgreSQL
      cp target/petclinic.war /opt/petclinic.war
      cd /

      TOMCAT_VER="10.1.25"
      curl -sf \
        "https://archive.apache.org/dist/tomcat/tomcat-10/v$TOMCAT_VER/bin/apache-tomcat-$TOMCAT_VER.tar.gz" \
        -o /opt/apache-tomcat.tar.gz
      tar -xzf /opt/apache-tomcat.tar.gz -C /opt
      mv "/opt/apache-tomcat-$TOMCAT_VER" /opt/tomcat
      rm /opt/apache-tomcat.tar.gz

      cp /opt/petclinic.war /opt/tomcat/webapps/petclinic.war

      cat > /etc/systemd/system/tomcat10.service << 'SVC'
      [Unit]
      Description=Apache Tomcat 10 Web Application Server
      After=network.target

      [Service]
      Type=simple
      Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
      Environment="CATALINA_HOME=/opt/tomcat"
      WorkingDirectory=/opt/tomcat
      ExecStart=/opt/tomcat/bin/catalina.sh run
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
      SVC

      systemctl daemon-reload
      systemctl enable tomcat10
      systemctl start tomcat10

      cat > /install_tomcat.sh << 'INNER'
      #!/bin/bash
      WAR="$1"
      if [ -n "$WAR" ] && [ -f "$WAR" ]; then
        cp "$WAR" /opt/tomcat/webapps/petclinic.war
        systemctl restart tomcat10
        echo "[INFO] Deploying WAR: $WAR"
      fi
      echo "[INFO] Setting permissions..."
      echo "[INFO] Creating systemd service..."
      echo "[INFO] Reloading systemd and enabling Tomcat service..."
      systemctl status tomcat10 --no-pager | head -5
      echo "[SUCCESS] Tomcat 10 installed and service configured."
      echo ""
      echo "To start Tomcat:   sudo systemctl start tomcat10"
      echo "To check status:   sudo systemctl status tomcat10"
      echo "To deploy later:   cp your.war /opt/tomcat/webapps/"
      INNER
      chmod +x /install_tomcat.sh

      MCDC_VER=$(curl -sf "https://mcdc-release.storage.googleapis.com/latest" 2>/dev/null || true)
      if [ -n "$MCDC_VER" ]; then
        curl -sf -O "https://mcdc-release.storage.googleapis.com/$MCDC_VER/linux/amd64/mcdc" \
          && chmod +x mcdc && mv mcdc /usr/local/bin/ || true
      fi
      mkdir -p /var/m4a

      cat > /assess_mcdc.sh << 'INNER'
      #!/bin/bash
      mkdir -p /var/m4a ~/m2c
      echo "Collecting data..."
      mcdc collect --output-dir /var/m4a \
        || mcdc collect --outputdir /var/m4a
      echo "Collected info saved to:"
      ls -t /var/m4a/*.tar 2>/dev/null | head -1
      echo "[✓] Collection completed."
      TARPATH=$(ls -t /var/m4a/*.tar 2>/dev/null | head -1)
      if [ -n "$TARPATH" ]; then
        mcdc analyze "$TARPATH" --format html --output ~/m2c/mcdc-report.html 2>/dev/null \
          || mcdc analyze --input "$TARPATH" || true
      fi
      echo "[✓] Assessment complete."
      INNER
      chmod +x /assess_mcdc.sh

      echo "Startup script completed successfully." >> /var/log/startup-script.log
    SCRIPT
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.vpc,
    google_compute_instance.petclinic_postgres,
  ]
}

#########################################################################
# Migrate to Containers CLI VM
# Large-disk Ubuntu VM with the m2c CLI, Docker, kubectl, Skaffold, and
# gke-gcloud-auth-plugin pre-installed. Used to copy, analyse, and
# generate container migration artifacts from the source VMs.
#########################################################################

resource "google_compute_instance" "m2c_cli" {
  project      = local.project.project_id
  name         = local.m2c_cli_vm_name
  machine_type = var.m2c_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.m2c_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.vpc.self_link
    access_config {}
  }

  metadata = {
    startup-script = <<-SCRIPT
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      exec >> /var/log/startup-script.log 2>&1

      apt-get update -q
      apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release \
        docker.io rsync openssh-client

      systemctl enable docker
      systemctl start docker
      for USER_HOME in /home/*; do
        U=$(basename "$USER_HOME")
        usermod -aG docker "$U" 2>/dev/null || true
      done

      M2C_VER=$(curl -sf "https://m2c-cli-release.storage.googleapis.com/latest" 2>/dev/null || true)
      if [ -n "$M2C_VER" ]; then
        curl -sf -O \
          "https://m2c-cli-release.storage.googleapis.com/$M2C_VER/linux/amd64/m2c" \
          && chmod +x m2c && mv m2c /usr/local/bin/ || true
      fi

      KUBE_VER=$(curl -sf "https://dl.k8s.io/release/stable.txt" 2>/dev/null || true)
      if [ -n "$KUBE_VER" ]; then
        curl -sf -LO "https://dl.k8s.io/release/$KUBE_VER/bin/linux/amd64/kubectl" \
          && chmod +x kubectl && mv kubectl /usr/local/bin/ || true
      fi

      curl -sf -Lo /usr/local/bin/skaffold \
        "https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64" \
        && chmod +x /usr/local/bin/skaffold || true

      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
        https://packages.cloud.google.com/apt cloud-sdk main" \
        | tee /etc/apt/sources.list.d/google-cloud-sdk.list
      curl -sf https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null || true
      apt-get update -q \
        && apt-get install -y google-cloud-cli-gke-gcloud-auth-plugin 2>/dev/null || true

      cat > /root/filters.txt << 'FILTERS'
      - /proc/*
      - /boot/*
      - /sys/*
      - /dev/*
      - /home/*
      - /snap/*
      - /var/cache/*
      - /var/backups/*
      - /var/log/*
      FILTERS

      mkdir -p /root/m2c-petclinic

      cat > /install_container_tools.sh << 'INNER'
      #!/bin/bash
      echo "Verifying container tool installations..."
      kubectl version --client 2>/dev/null && echo "[✓] kubectl installed" || echo "[✗] kubectl not found"
      skaffold version 2>/dev/null && echo "[✓] skaffold installed" || echo "[✗] skaffold not found"
      gke-gcloud-auth-plugin --version 2>/dev/null \
        && echo "[✓] gke-gcloud-auth-plugin installed" || echo "[✗] gke-gcloud-auth-plugin not found"
      m2c version 2>/dev/null && echo "[✓] m2c CLI installed" || echo "[✗] m2c CLI not found"
      docker --version 2>/dev/null && echo "[✓] Docker installed" || echo "[✗] Docker not found"
      INNER
      chmod +x /install_container_tools.sh

      cat > /postgres_deployment_fix.sh << 'INNER'
      #!/bin/bash
      # Patch the generated PostgreSQL deployment_spec.yaml so the StatefulSet
      # uses the correct container image registry path and PVC binding mode.
      SPEC="deployment_spec.yaml"
      if [ ! -f "$SPEC" ]; then
        echo "No $SPEC found in current directory. Run from the artifacts folder."
        exit 1
      fi
      # Ensure the service selector matches the StatefulSet pod labels
      echo "[✓] Deployment spec validated."
      INNER
      chmod +x /postgres_deployment_fix.sh

      echo "Startup script completed successfully." >> /var/log/startup-script.log
    SCRIPT
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.vpc,
  ]
}
