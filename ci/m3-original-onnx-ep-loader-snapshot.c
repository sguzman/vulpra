// CI-only Linux loader residency census for the pinned original ONNX EP probe.
// Uses dl_iterate_phdr and emits ONLY bounded basenames and origin classes.
// Not a complete dependency, symbol-binding, browser lifetime or dlopen closure proof.
#define _GNU_SOURCE
#include <link.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { MAX_MAP_OBJECTS = 256, MAX_NAME = 111, MAX_STAGE = 32 };
static const char *original_path;
static const char *plugin_path;
static size_t package_dir_len;
static int enabled;

struct Census {
  const char *stage;
  size_t total;
  size_t package;
  size_t plugin;
  size_t host;
  int invalid;
};

static int safe_component(const char *s, size_t max_length) {
  if (s == NULL || *s == '\0') return 0;
  size_t n = 0;
  for (const unsigned char *p = (const unsigned char *)s; *p; ++p) {
    if (++n > max_length) return 0;
    if (!( (*p >= 'a' && *p <= 'z') ||
           (*p >= 'A' && *p <= 'Z') ||
           (*p >= '0' && *p <= '9') ||
           *p == '.' || *p == '_' || *p == '-' || *p == '+' )) return 0;
  }
  return 1;
}

static int map_callback(struct dl_phdr_info *info, size_t size, void *data) {
  (void)size;
  struct Census *c = (struct Census *)data;
  if (info == NULL || info->dlpi_name == NULL || info->dlpi_name[0] == '\0')
    return 0; // The main probe executable is not a shared-library mapping.
  if (++c->total > MAX_MAP_OBJECTS) {
    c->invalid = 1;
    return 1;
  }
  const char *path = info->dlpi_name;
  const char *slash = strrchr(path, '/');
  const char *name = slash == NULL ? path : slash + 1;
  if (!safe_component(name, MAX_NAME)) {
    c->invalid = 1;
    return 1;
  }
  const char *kind = "host";
  if (strcmp(path, plugin_path) == 0) {
    kind = "plugin"; ++c->plugin;
  } else if (strncmp(path, original_path, package_dir_len) == 0 &&
             path[package_dir_len] == '/') {
    kind = "package"; ++c->package;
  } else {
    ++c->host;
  }
  printf("M3_EP_MAP stage=%s kind=%s name=%s\n", c->stage, kind, name);
  return 0;
}

// Paths are only compared within this process; never emitted or exported.
int m3_ci_loader_init(const char *original, const char *plugin) {
  const char *mode = getenv("VULPRA_CI_ONNX_EP_MAP");
  enabled = mode != NULL && strcmp(mode, "1") == 0;
  if (!enabled) return 0;
  if (original == NULL || plugin == NULL ||
      original[0] != '/' || plugin[0] != '/') return 1;
  const char *last_slash = strrchr(original, '/');
  if (last_slash == NULL || last_slash == original) return 1;
  package_dir_len = (size_t)(last_slash - original);
  original_path = original;
  plugin_path = plugin;
  return 0;
}

// Stages are fixed literal labels, not user controlled or filesystem data.
int m3_ci_loader_snapshot(const char *stage) {
  if (!enabled) return 0;
  if (!safe_component(stage, MAX_STAGE)) return 1;
  struct Census c = {.stage = stage, .total = 0,
                     .package = 0, .plugin = 0, .host = 0, .invalid = 0};
  int rc = dl_iterate_phdr(map_callback, &c);
  if (rc != 0 || c.invalid || c.total == 0) {
    fputs("M3_EP_MAP_ERROR=invalid_or_truncated_snapshot\n", stderr);
    return 1;
  }
  printf("M3_EP_MAP_SUMMARY stage=%s total=%zu package=%zu plugin=%zu host=%zu\n",
         stage, c.total, c.package, c.plugin, c.host);
  fflush(stdout);
  return 0;
}
