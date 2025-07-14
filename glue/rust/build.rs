use std::env;
use std::path::PathBuf;

fn main() {
    // Get the output directory
    let out_dir = env::var("OUT_DIR").unwrap();
    
    // Build the FFI library
    cc::Build::new()
        .file("../../glue/ffi/nanocore_ffi.c")
        .include("../../glue/ffi")
        .opt_level(2)
        .flag("-fPIC")
        .compile("nanocore_ffi");
    
    // Tell cargo to invalidate the built crate whenever the wrapper changes
    println!("cargo:rerun-if-changed=../../glue/ffi/nanocore_ffi.c");
    
    // Link to the library
    println!("cargo:rustc-link-lib=static=nanocore_ffi");
    println!("cargo:rustc-link-search=native={}", out_dir);
}