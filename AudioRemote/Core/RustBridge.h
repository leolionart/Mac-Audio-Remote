#ifndef RustBridge_h
#define RustBridge_h

#include <stdbool.h>

/// Compare two semantic version strings
/// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2, -999 on error
int version_compare(const char* v1, const char* v2);

/// Check if update is available (latest > current)
/// Returns: true if latest > current, false otherwise
bool version_has_update(const char* current, const char* latest);

#endif /* RustBridge_h */
