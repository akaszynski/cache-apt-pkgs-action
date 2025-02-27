#!/bin/bash

# Fail on any error.
set -e

# Include library.
script_dir="$(dirname -- "$(realpath -- "${0}")")"
source "${script_dir}/lib.sh"

# Directory that holds the cached packages.
cache_dir="${1}"

# List of the packages to use.
input_packages="${@:2}"

# Trim commas, excess spaces, and sort.
normalized_packages="$(normalize_package_list "${input_packages}")"

package_count=$(wc -w <<< "${normalized_packages}")
log "Clean installing and caching ${package_count} package(s)."
log "Package list:"
for package in ${normalized_packages}; do
  log "- ${package}"
done

log "Updating APT package list..."
sudo apt-get update > /dev/null
echo "done."

# Strictly contains the requested packages.
manifest_main=""
# Contains all packages including dependencies.
manifest_all=""

log "Clean installing and caching ${package_count} packages..."
for package in ${normalized_packages}; do
  read package_name package_ver < <(get_package_name_ver "${package}")  

  # Comma delimited name:ver pairs in the main requested packages manifest.
  manifest_main="${manifest_main}${package_name}:${package_ver},"

  read dep_packages < <(get_dep_packages "${package_name}")
  if test -z "${dep_packages}"; then
    dep_packages_text="none";
  else
    dep_packages_text="${dep_packages}"
  fi

  log "- ${package_name}"
  log "  * Version: ${package_ver}"
  log "  * Dependencies: ${dep_packages_text}"
  log "  * Installing..."
  # Zero interaction while installing or upgrading the system via apt.
  sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install "${package_name}" > /dev/null
  echo "done."

  for cache_package in ${package_name}:${package_ver} ${dep_packages}; do
    cache_filepath="${cache_dir}/${cache_package}.tar.gz"

    if test ! -f "${cache_filepath}"; then
      read cache_package_name cache_package_ver < <(get_package_name_ver "${cache_package}")
      log "  * Caching ${cache_package_name} to ${cache_filepath}..."
      # Pipe all package files (no folders) to Tar.
      dpkg -L "${cache_package_name}" |
        while IFS= read -r f; do     
          if test -f $f || test -L $f; then echo "${f:1}"; fi;  #${f:1} removes the leading slash that Tar disallows
        done | 
        xargs tar -czf "${cache_filepath}" -C /      
      log "done (compressed size $(du -h "${cache_filepath}" | cut -f1))."
    fi

    # Comma delimited name:ver pairs in the all packages manifest.
    manifest_all="${manifest_all}${cache_package_name}:${cache_package_ver},"
  done  
done
log "done."

write_manifest "all" "${manifest_all}" "${cache_dir}/manifest_all.log"
write_manifest "main" "${manifest_main}" "${cache_dir}/manifest_main.log"
