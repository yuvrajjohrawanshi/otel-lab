#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# KILLSWITCH — destroys ALL Lab 2 AWS infrastructure
# Run this when done with the lab to stop incurring costs
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║               ⚠  LAB 2 KILLSWITCH  ⚠                   ║${NC}"
echo -e "${RED}║  This will PERMANENTLY DESTROY all Lab 2 infrastructure  ║${NC}"
echo -e "${RED}║  VMs, networking, security groups — everything.          ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

read -rp "$(echo -e ${YELLOW}Type DESTROY to confirm:${NC}) " confirm

if [[ "$confirm" != "DESTROY" ]]; then
  echo "Aborted. No changes made."
  exit 0
fi

echo ""
echo "Switching to terraform directory..."
cd "$(dirname "$0")"

echo "Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo "✅ All Lab 2 infrastructure has been destroyed."
echo "   No further AWS costs will be incurred for this lab."
