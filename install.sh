#!/usr/bin/env bash
set -euo pipefail

case "${RUNNER_OS}" in
  Linux) os=linux ;;
  Windows) os=win32 ;;
  macOS) os=darwin ;;
  *)
    echo "unsupported runner OS: ${RUNNER_OS}" >&2
    exit 1
    ;;
esac

case "${RUNNER_ARCH}" in
  X64) arch=x64 ;;
  ARM64) arch=arm64 ;;
  *)
    echo "unsupported runner arch: ${RUNNER_ARCH}" >&2
    exit 1
    ;;
esac

pkg="@wangpkg/${os}-${arch}"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

# Exact semver with optional pre-release / build metadata (hash stripped already).
is_exact_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
}

# Read wangpkg version hint from package.json:
# 1) packageManager: "wangpkg@0.1.0"
# 2) devEngines.packageManager: { name: "wangpkg", version: "^0.1.0" }
resolve_from_manifest() {
  local file="${INPUT_MANIFEST:-package.json}"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  node --input-type=commonjs -e '
const fs = require("fs");
const file = process.argv[1];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));

const fromPackageManager = (value) => {
  if (typeof value !== "string") return "";
  const m = /^(?:wangpkg)@([^+\s]+)(?:\+.*)?$/.exec(value.trim());
  return m ? m[1] : "";
};

const fromDevEngines = (value) => {
  if (!value) return "";
  const list = Array.isArray(value) ? value : [value];
  for (const item of list) {
    if (item && item.name === "wangpkg" && item.version) {
      return String(item.version).replace(/\+.*$/, "");
    }
  }
  return "";
};

const version =
  fromPackageManager(pkg.packageManager) ||
  fromDevEngines(pkg.devEngines && pkg.devEngines.packageManager) ||
  "";
if (version) process.stdout.write(version);
' "$file"
}

resolve_version() {
  local requested="${INPUT_VERSION:-}"
  if [[ -z "$requested" ]]; then
    requested=$(resolve_from_manifest || true)
  fi
  if [[ -z "$requested" ]]; then
    requested=latest
  fi
  if is_exact_version "$requested"; then
    printf '%s\n' "$requested"
    return
  fi
  # Semver range or dist-tag: let npm resolve against the published wangpkg package.
  npm view "wangpkg@${requested}" version
}

version=$(resolve_version)
version=$(printf '%s' "$version" | tr -d '\r' | head -n1)
if [[ -z "$version" ]]; then
  echo "failed to resolve wangpkg version" >&2
  exit 1
fi

tarball=$(npm view "${pkg}@${version}" dist.tarball | tr -d '\r' | head -n1)
if [[ -z "$tarball" ]]; then
  echo "failed to resolve tarball for ${pkg}@${version}" >&2
  exit 1
fi

to_posix_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p"
    return
  fi
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive="${BASH_REMATCH[1]}"
    drive=$(printf '%s' "$drive" | tr '[:upper:]' '[:lower:]')
    printf '/%s/%s\n' "$drive" "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "$p"
  fi
}

to_github_path() {
  local p="$1"
  if [[ "$os" == "win32" ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  else
    printf '%s\n' "$p"
  fi
}

install_dir="$(to_posix_path "${RUNNER_TEMP}")/wangpkg-${version}-${os}-${arch}"
rm -rf "$install_dir"
mkdir -p "$install_dir"
archive="${install_dir}/package.tgz"
curl -fsSL -o "$archive" "$tarball"
(
  cd "$install_dir"
  tar -xzf package.tgz
)

bin_dir="${install_dir}/bin"
mkdir -p "$bin_dir"
pkg_dir="${install_dir}/package"

if [[ "$os" == "win32" ]]; then
  if [[ -f "${pkg_dir}/wangpkg.exe" ]]; then
    cp "${pkg_dir}/wangpkg.exe" "${bin_dir}/wangpkg.exe"
  elif [[ -f "${pkg_dir}/wangpkg" ]]; then
    cp "${pkg_dir}/wangpkg" "${bin_dir}/wangpkg.exe"
  else
    echo "wangpkg.exe not found in ${pkg}@${version}" >&2
    exit 1
  fi
  wangpkg_bin="${bin_dir}/wangpkg.exe"
else
  if [[ ! -f "${pkg_dir}/wangpkg" ]]; then
    echo "wangpkg binary not found in ${pkg}@${version}" >&2
    exit 1
  fi
  cp "${pkg_dir}/wangpkg" "${bin_dir}/wangpkg"
  chmod +x "${bin_dir}/wangpkg"
  wangpkg_bin="${bin_dir}/wangpkg"
fi

github_bin_dir=$(to_github_path "$bin_dir")
echo "${github_bin_dir}" >> "$GITHUB_PATH"
{
  echo "version=${version}"
  echo "path=${github_bin_dir}"
} >> "$GITHUB_OUTPUT"

echo "Installed wangpkg ${version} (${pkg})"
"$wangpkg_bin" --version
