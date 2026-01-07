use std::ffi::{CStr, c_char};
use semver::Version;

/// Compare two semantic version strings
/// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2, -999 on parse error
#[no_mangle]
pub extern "C" fn version_compare(v1_ptr: *const c_char, v2_ptr: *const c_char) -> i32 {
    unsafe {
        // Validate pointers
        if v1_ptr.is_null() || v2_ptr.is_null() {
            return -999;
        }

        // Convert C strings to Rust strings
        let v1_str = match CStr::from_ptr(v1_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return -999,
        };
        let v2_str = match CStr::from_ptr(v2_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return -999,
        };

        // Strip 'v' prefix if present
        let v1_clean = v1_str.strip_prefix('v').unwrap_or(v1_str);
        let v2_clean = v2_str.strip_prefix('v').unwrap_or(v2_str);

        // Parse as semantic versions
        let v1 = match Version::parse(v1_clean) {
            Ok(v) => v,
            Err(_) => return -999,
        };
        let v2 = match Version::parse(v2_clean) {
            Ok(v) => v,
            Err(_) => return -999,
        };

        // Compare and return result
        match v1.cmp(&v2) {
            std::cmp::Ordering::Less => -1,
            std::cmp::Ordering::Equal => 0,
            std::cmp::Ordering::Greater => 1,
        }
    }
}

/// Check if update is available (latest > current)
/// Returns: true if latest > current, false otherwise
#[no_mangle]
pub extern "C" fn version_has_update(current_ptr: *const c_char, latest_ptr: *const c_char) -> bool {
    version_compare(current_ptr, latest_ptr) == 1
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn test_version_compare() {
        let v1 = CString::new("2.6.0").unwrap();
        let v2 = CString::new("2.5.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), 1);

        let v1 = CString::new("2.5.0").unwrap();
        let v2 = CString::new("2.6.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), -1);

        let v1 = CString::new("2.6.0").unwrap();
        let v2 = CString::new("2.6.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), 0);
    }

    #[test]
    fn test_version_compare_edge_cases() {
        // Test lexical ordering edge case
        let v1 = CString::new("2.10.0").unwrap();
        let v2 = CString::new("2.9.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), 1);

        // Test 'v' prefix
        let v1 = CString::new("v2.6.0").unwrap();
        let v2 = CString::new("2.5.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), 1);

        // Test both with 'v' prefix
        let v1 = CString::new("v2.6.0").unwrap();
        let v2 = CString::new("v2.5.0").unwrap();
        assert_eq!(version_compare(v1.as_ptr(), v2.as_ptr()), 1);
    }

    #[test]
    fn test_version_has_update() {
        let current = CString::new("2.5.0").unwrap();
        let latest = CString::new("2.6.0").unwrap();
        assert!(version_has_update(current.as_ptr(), latest.as_ptr()));

        let current = CString::new("2.6.0").unwrap();
        let latest = CString::new("2.5.0").unwrap();
        assert!(!version_has_update(current.as_ptr(), latest.as_ptr()));

        let current = CString::new("2.6.0").unwrap();
        let latest = CString::new("2.6.0").unwrap();
        assert!(!version_has_update(current.as_ptr(), latest.as_ptr()));
    }
}
