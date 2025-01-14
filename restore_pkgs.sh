#!/bin/bash

# Fail on any error.
set -e

# Include library.
script_dir="$(dirname -- "$(realpath -- "${0}")")"
source "${script_dir}/lib.sh"

# Directory that holds the cached packages.
cache_dir="${1}"

# Root directory to untar the cached packages to.
# Typically filesystem root '/' but can be changed for testing.
cache_restore_root="${2}"

cache_filepaths="$(ls -1 "${cache_dir}" | sort)"
log "Found $(echo ${cache_filepaths} | wc -w) files in the cache."
for cache_filepath in ${cache_filepaths}; do
  log "- "$(basename ${cache_filepath})""
done

log "Reading from main requested packages manifest..."
for logline in $(cat "${cache_dir}/manifest_main.log" | tr ',' '\n' ); do
  log "- $(echo "${logline}" | tr ':' ' ')"
done
log "done."

# Only search for archived results. Manifest and cache key also live here.
cache_pkg_filepaths=$(ls -1 "${cache_dir}"/*.tar.gz | sort)
cache_pkg_filecount=$(echo ${cache_pkg_filepaths} | wc -w)
log "Restoring ${cache_pkg_filecount} packages from cache..."
for cache_pkg_filepath in ${cache_pkg_filepaths}; do
  log "- $(basename "${cache_pkg_filepath}") restoring..."
  sudo tar -xf "${cache_pkg_filepath}" -C "${cache_restore_root}" > /dev/null
  log "done."
done
log "done."
