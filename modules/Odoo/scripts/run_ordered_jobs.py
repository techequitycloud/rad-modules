import sys
import json
import subprocess
import time

def run_command(command):
    print(f"Running: {command}")
    # Run command and stream output
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Poll process for new output
    while True:
        output = process.stdout.readline()
        if output == '' and process.poll() is not None:
            break
        if output:
            print(output.strip(), flush=True)

    rc = process.poll()
    if rc != 0:
        print(f"Command failed with exit code {rc}")
        print(process.stderr.read())
        sys.exit(rc)

def main():
    if len(sys.argv) < 5:
        print("Usage: run_ordered_jobs.py <jobs_json> <resource_prefix> <region> <project_id> [impersonate_sa]")
        sys.exit(1)

    jobs_map = json.loads(sys.argv[1])
    prefix = sys.argv[2]
    region = sys.argv[3]
    project = sys.argv[4]
    impersonate_sa = sys.argv[5] if len(sys.argv) > 5 else ""

    # Filter jobs that should be executed
    jobs = {k: v for k, v in jobs_map.items() if v.get('execute_on_apply', True)}

    if not jobs:
        print("No jobs to execute.")
        return

    # Build dependency graph
    # Node: job_name (key)
    # Edges: job -> set of dependencies (must run before job)
    graph = {k: set() for k in jobs}
    for name, config in jobs.items():
        deps = config.get('depends_on_jobs', [])
        for dep in deps:
            if dep in jobs:
                graph[name].add(dep)
            else:
                # If dependency is not in the map (e.g. nfs-init is in map, but maybe some other external dep?), ignore or warn
                # Assuming all dependencies are keys in jobs_map
                pass

    # Topological sort
    # We want an execution order where dependencies come first.
    execution_order = []
    visited = set()
    temp_mark = set()

    def visit(n):
        if n in temp_mark:
            print(f"Error: Circular dependency detected involving {n}")
            sys.exit(1)
        if n in visited:
            return
        temp_mark.add(n)
        for m in graph[n]:
            visit(m)
        temp_mark.remove(n)
        visited.add(n)
        execution_order.append(n)

    for n in jobs:
        if n not in visited:
            visit(n)

    print(f"Computed execution order: {execution_order}")

    # Execute jobs in order
    for job_key in execution_order:
        full_job_name = f"{prefix}-{job_key}"
        print(f"\n==================================================")
        print(f"Executing Job: {full_job_name} ({job_key})")
        print(f"==================================================")

        impersonate_flag = f"--impersonate-service-account={impersonate_sa}" if impersonate_sa else ""

        # Using --wait to ensure it completes before moving to next
        cmd = f"gcloud run jobs execute {full_job_name} --region {region} --project {project} {impersonate_flag} --wait"

        try:
            run_command(cmd)
            print(f"✓ Job {full_job_name} completed successfully")
        except Exception as e:
            print(f"✗ Job {full_job_name} failed: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()
