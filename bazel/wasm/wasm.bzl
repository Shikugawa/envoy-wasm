load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

def _wasm_transition_impl(settings, attr):
    return {
        "//command_line_option:platforms": "@io_bazel_rules_rust//rust/platform:wasm" if attr.type == "rust" else "",
        "//command_line_option:cpu": "wasm",
        "//command_line_option:crosstool_top": "@proxy_wasm_cpp_sdk//toolchain:emscripten",

        # Overriding copt/cxxopt/linkopt to prevent sanitizers/coverage options leak
        # into WASM build configuration
        "//command_line_option:copt": [],
        "//command_line_option:cxxopt": [],
        "//command_line_option:linkopt": [],
    }

wasm_transition = transition(
    implementation = _wasm_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
        "//command_line_option:copt",
        "//command_line_option:cxxopt",
        "//command_line_option:linkopt",
    ],
)

def _wasm_binary_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.run_shell(
        command = 'cp "{}" "{}"'.format(ctx.files.binary[0].path, out.path),
        outputs = [out],
        inputs = ctx.files.binary,
    )

    return [DefaultInfo(runfiles = ctx.runfiles([out]))]

# WASM binary rule implementation.
# This copies the binary specified in binary attribute in WASM configuration to
# target configuration, so a binary in non-WASM configuration can depend on them.
wasm_binary = rule(
    implementation = _wasm_binary_impl,
    attrs = {
        "binary": attr.label(mandatory = True, cfg = wasm_transition),
        "type": attr.string(default = "cc"),
        "_whitelist_function_transition": attr.label(default = "@bazel_tools//tools/whitelists/function_transition_whitelist"),
    },
)

def wasm_cc_binary(name, **kwargs):
    wasm_name = "_wasm_" + name
    kwargs.setdefault("additional_linker_inputs", ["@proxy_wasm_cpp_sdk//:jslib"])
    kwargs.setdefault("linkopts", ["--js-library external/proxy_wasm_cpp_sdk/proxy_wasm_intrinsics.js"])
    kwargs.setdefault("visibility", ["//visibility:public"])
    native.cc_binary(
        name = wasm_name,
        # Adding manual tag it won't be built in non-WASM (e.g. x86_64 config)
        # when an wildcard is specified, but it will be built in WASM configuration
        # when the wasm_binary below is built.
        tags = ["manual"],
        **kwargs
    )

    wasm_binary(
        name = name,
        binary = ":" + wasm_name,
    )

def wasm_rust_binary(name, **kwargs):
    wasm_name = "_wasm_" + name
    kwargs.setdefault("visibility", ["//visibility:public"])
    kwargs.setdefault("rustc_flags", ["--edition=2018"])
    kwargs.setdefault("out_binary", True)
    kwargs.setdefault("crate_type", "cdylib")

    rust_binary(
        name = wasm_name,
        **kwargs
    )

    wasm_binary(
        name = name + ".wasm",
        binary = ":" + wasm_name,
        type = "rust",
    )
