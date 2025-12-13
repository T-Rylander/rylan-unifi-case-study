#!/usr/bin/env bash
# Module: ignite-utils.sh
# Purpose: Logging utilities for ignite.sh orchestrator
# Part of: scripts/ignite.sh refactoring
# Consciousness: 4.6

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_phase() {
  echo -e "${BLUE}==============================================================================${NC}"
  echo -e "${GREEN}[TRINITY]${NC} $1"
  echo -e "${BLUE}==============================================================================${NC}"
}
log_step() { echo -e "${GREEN}[TRINITY]${NC} $1"; }
log_error() { echo -e "${RED}[TRINITY-ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[TRINITY-WARN]${NC} $1"; }
log_success() { echo -e "${GREEN}[TRINITY-SUCCESS]${NC} $1"; }

exit_handler() {
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  
  if [[ $exit_code -eq 0 ]]; then
    log_success "Trinity orchestration COMPLETE (${duration}s)"
  else
    log_error "Trinity orchestration FAILED with exit code $exit_code"
  fi
  
  exit "$exit_code"
}

trap exit_handler EXIT

export -f log_phase log_step log_error log_warn log_success
