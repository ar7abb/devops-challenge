# Docker and Kubernetes solution

The app runs as a non-root user in a single-replica Deployment. A ClusterIP Service exposes port 80 and forwards requests to the app on port 5000.

## Choices

I used `python:3.12-slim` because the app only needs Python's standard library. There are no dependencies to install or files to compile, so there wasn't a useful build stage to separate.

The image creates `appuser` and runs Python as UID/GID 10001. The app only needs to read its code and listen on port 5000, so it doesn't need root privileges. `ENV PORT=5000` makes the default explicit, while still allowing a runtime override. `EXPOSE 5000` documents the port; it doesn't publish it.

The Deployment uses `intern-task-app:local` with `imagePullPolicy: Never`. The challenge uses a local image, so I load it into kind instead of publishing it to a registry. A new cluster needs the image loaded again.

Both probes request `/healthz` on port 5000. Readiness starts after two seconds and checks every five seconds. Liveness starts after five seconds and checks every ten seconds. Readiness removes an unresponsive Pod from Service traffic; repeated liveness failures restart the container. This endpoint checks that the HTTP server responds. The app has no external dependencies to check.

CPU/memory requests are `50m`/`32Mi`, with limits of `250m`/`64Mi`. These are initial settings for this small service and passed the smoke tests. They aren't based on load testing.

## Run locally

Run from the repository root. Docker, kind and kubectl must already be installed. These commands assume there isn't already a cluster named `intern-task`; skip cluster creation if reusing it.

```bash
cd intern-task-app
docker build -t intern-task-app:local .
kind create cluster --name intern-task
kind load docker-image intern-task-app:local --name intern-task
kubectl --context kind-intern-task apply -f k8s/
kubectl --context kind-intern-task rollout status deployment/intern-task-app --timeout=60s
kubectl --context kind-intern-task get pods
kubectl --context kind-intern-task port-forward svc/intern-task-app 8080:80
```

Leave port forwarding running and use a second terminal:

```bash
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/
```

Both should return HTTP 200. The bodies should be `ok` and `hello from intern-task`, respectively. Stop port forwarding with Ctrl+C.

To test the actual internal Service connection as well:

```bash
kubectl --context kind-intern-task exec deployment/intern-task-app -- python -c 'import urllib.request; print(urllib.request.urlopen("http://intern-task-app/healthz", timeout=5).read().decode())'
```

This should print `ok`. Unlike Service port forwarding, this request uses the Service's DNS name and ClusterIP networking path.

The image also supports the README's direct Docker example:

```bash
docker run --rm -p 8080:8080 -e PORT=8080 intern-task-app:local
```

Then request `http://localhost:8080/healthz` from another terminal.

If rebuilding an image for an existing deployment, load it again and replace the running Pods:

```bash
kind load docker-image intern-task-app:local --name intern-task
kubectl --context kind-intern-task rollout restart deployment/intern-task-app
kubectl --context kind-intern-task rollout status deployment/intern-task-app --timeout=60s
```

Loading an image alone doesn't update a running container.

For schema validation, with kubeconform installed, run from `intern-task-app`:

```bash
kubeconform -summary -strict k8s/
```

## Verification

The following local checks passed:

- Docker build, UID 10001, both endpoints, and the `PORT=8080` override.
- Strict kubeconform validation: two valid resources, no invalid resources or errors.
- Build/load/apply on a fresh kind cluster, with rollout completing within 60 seconds and zero initial container restarts. No resource patching was needed.
- Both endpoints through port forwarding and through the internal Service.
- An unresponsive-process test: pausing Python caused readiness to fail, liveness restarted the container, and readiness recovered.

Tests used kind 0.33.0 with Kubernetes 1.37.0. The `python:3.12-slim` tag can receive newer patches, so future builds may use an updated base image.
