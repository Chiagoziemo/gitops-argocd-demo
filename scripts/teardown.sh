#!/usr/bin/env bash
# Deletes the entire kind cluster. Everything in this repo is reproducible
# from bootstrap/, so there's nothing worth preserving in-cluster.
set -euo pipefail

kind delete cluster --name gitops-demo
