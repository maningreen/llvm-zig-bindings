const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---< Main llvm bindings module >---
    const llvm_bindings_module = b.addModule("llvm-zig", .{
        .root_source_file = b.path("src/bindings-llvm.zig"),
        .target = target,
        .optimize = optimize,
    });

    llvm_bindings_module.link_libcpp = true;
    llvm_bindings_module.linkSystemLibrary("z", .{});
    llvm_bindings_module.linkSystemLibrary("zstd", .{});

    // Link with llvm.
    switch (target.result.os.tag) {
        .linux => llvm_bindings_module.linkSystemLibrary("LLVM-19", .{}),
        .macos => {
            llvm_bindings_module.addLibraryPath(.{
                .cwd_relative = "/opt/homebrew/opt/llvm@19/lib",
            });
            llvm_bindings_module.linkSystemLibrary("LLVM", .{
                .use_pkg_config = .no,
            });
        },
        .windows => {
            llvm_bindings_module.addLibraryPath(.{
                .cwd_relative = "C:\\Program Files\\LLVM\\lib",
            });
            llvm_bindings_module.linkSystemLibrary("ole32", .{});
            for (llvm_libs) |lib_name|
                llvm_bindings_module.linkSystemLibrary(lib_name, .{
                    .use_pkg_config = .no,
                });
            for (lld_libs) |lib_name|
                llvm_bindings_module.linkSystemLibrary(lib_name, .{
                    .use_pkg_config = .no,
                });
        },
        else => {
            std.debug.print("Invalid target OS. Supported ones are currently: Linux, MacOS, Windows.", .{});
            return error.InvalidOSForLLVM;
        },
    }

    // ---< Main clang bindings module >---
    const libclang_bindings_module = b.addModule("clang-zig", .{
        .root_source_file = b.path("src/bindings-clang.zig"),
        .target = target,
        .optimize = optimize,
    });

    libclang_bindings_module.link_libcpp = true;

    // Link with libclang.
    switch (target.result.os.tag) {
        .linux => libclang_bindings_module.linkSystemLibrary("clang", .{}),
        .macos => {
            libclang_bindings_module.addLibraryPath(.{
                .cwd_relative = "/opt/homebrew/opt/llvm@19/lib",
            });
            libclang_bindings_module.linkSystemLibrary("clang", .{
                .use_pkg_config = .no,
            });
        },
        .windows => {
            libclang_bindings_module.addLibraryPath(.{
                .cwd_relative = "C:\\Program Files\\LLVM\\lib",
            });
            for (clang_libs) |lib_name|
                libclang_bindings_module.linkSystemLibrary(lib_name, .{
                    .use_pkg_config = .no,
                });
        },
        else => {
            std.debug.print("Invalid target OS. Supported ones are currently: Linux, MacOS, Windows.", .{});
            return error.InvalidOSForLLVM;
        },
    }

    // ---< Utilities >---
    try buildTests(b);

    const examples = b.option(bool, "examples", "Build all examples [default: false]") orelse false;
    if (examples) {
        buildExample(b, .{
            .filepath = "examples/playground.zig",
            .target = target,
            .optimize = optimize,
        });
        buildExample(b, .{
            .filepath = "examples/factorial.zig",
            .target = target,
            .optimize = optimize,
        });
    }
}

const BuildInfo = struct {
    filepath: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.splitSequence(u8, std.fs.path.basename(self.filepath), ".");
        return split.first();
    }
};

fn buildExample(b: *std.Build, i: BuildInfo) void {
    const exe = b.addExecutable(.{
        .name = i.filename(),
        .root_module = b.createModule(.{
            .target = i.target,
            .root_source_file = b.path(i.filepath),
        }),
    });
    exe.root_module.addImport("llvm", b.modules.get("llvm-zig").?);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(i.filename(), b.fmt("Run the {s}", .{i.filename()}));
    run_step.dependOn(&run_cmd.step);
}

fn buildTests(b: *std.Build) !void {
    const llvm_bindings_tests = b.addTest(.{
        .root_module = b.modules.get("llvm-zig") orelse return error.MissingModule,
        .name = "llvm-bindings-tests",
    });
    const libclang_bindings_tests = b.addTest(.{
        .root_module = b.modules.get("clang-zig") orelse return error.MissingModule,
        .name = "clang-bindings-tests",
    });

    llvm_bindings_tests.root_module.addImport("llvm", b.modules.get("llvm-zig").?);
    libclang_bindings_tests.root_module.addImport("clang", b.modules.get("clang-zig").?);

    llvm_bindings_tests.step.dependOn(&b.addRunArtifact(libclang_bindings_tests).step);

    const run_only_clang_tests = b.step("test-clang", "Run libclang bindings tests");
    run_only_clang_tests.dependOn(&libclang_bindings_tests.step);

    const run_all_tests = b.step("test", "Run libclang and llvm bindings tests");
    run_all_tests.dependOn(&llvm_bindings_tests.step);
}

// These are yoinked from zig source-code.
const clang_libs = [_][]const u8{
    "clangFrontendTool",
    "clangCodeGen",
    "clangFrontend",
    "clangDriver",
    "clangSerialization",
    "clangSema",
    "clangStaticAnalyzerFrontend",
    "clangStaticAnalyzerCheckers",
    "clangStaticAnalyzerCore",
    "clangAnalysis",
    "clangASTMatchers",
    "clangAST",
    "clangParse",
    "clangSema",
    "clangAPINotes",
    "clangBasic",
    "clangEdit",
    "clangLex",
    "clangARCMigrate",
    "clangRewriteFrontend",
    "clangRewrite",
    "clangCrossTU",
    "clangIndex",
    "clangToolingCore",
    "clangExtractAPI",
    "clangSupport",
    "clangInstallAPI",
    "clangAST",
};

const lld_libs = [_][]const u8{
    "lldMinGW",
    "lldELF",
    "lldCOFF",
    "lldWasm",
    "lldMachO",
    "lldCommon",
};

const llvm_libs = [_][]const u8{
    "LLVMWindowsManifest",
    "LLVMXRay",
    "LLVMLibDriver",
    "LLVMDlltoolDriver",
    "LLVMTelemetry",
    "LLVMTextAPIBinaryReader",
    "LLVMCoverage",
    "LLVMLineEditor",
    "LLVMXCoreDisassembler",
    "LLVMXCoreCodeGen",
    "LLVMXCoreDesc",
    "LLVMXCoreInfo",
    "LLVMX86TargetMCA",
    "LLVMX86Disassembler",
    "LLVMX86AsmParser",
    "LLVMX86CodeGen",
    "LLVMX86Desc",
    "LLVMX86Info",
    "LLVMWebAssemblyDisassembler",
    "LLVMWebAssemblyAsmParser",
    "LLVMWebAssemblyCodeGen",
    "LLVMWebAssemblyUtils",
    "LLVMWebAssemblyDesc",
    "LLVMWebAssemblyInfo",
    "LLVMVEDisassembler",
    "LLVMVEAsmParser",
    "LLVMVECodeGen",
    "LLVMVEDesc",
    "LLVMVEInfo",
    "LLVMSystemZDisassembler",
    "LLVMSystemZAsmParser",
    "LLVMSystemZCodeGen",
    "LLVMSystemZDesc",
    "LLVMSystemZInfo",
    "LLVMSPIRVCodeGen",
    "LLVMSPIRVDesc",
    "LLVMSPIRVInfo",
    "LLVMSPIRVAnalysis",
    "LLVMSparcDisassembler",
    "LLVMSparcAsmParser",
    "LLVMSparcCodeGen",
    "LLVMSparcDesc",
    "LLVMSparcInfo",
    "LLVMRISCVTargetMCA",
    "LLVMRISCVDisassembler",
    "LLVMRISCVAsmParser",
    "LLVMRISCVCodeGen",
    "LLVMRISCVDesc",
    "LLVMRISCVInfo",
    "LLVMPowerPCDisassembler",
    "LLVMPowerPCAsmParser",
    "LLVMPowerPCCodeGen",
    "LLVMPowerPCDesc",
    "LLVMPowerPCInfo",
    "LLVMNVPTXCodeGen",
    "LLVMNVPTXDesc",
    "LLVMNVPTXInfo",
    "LLVMMSP430Disassembler",
    "LLVMMSP430AsmParser",
    "LLVMMSP430CodeGen",
    "LLVMMSP430Desc",
    "LLVMMSP430Info",
    "LLVMMipsDisassembler",
    "LLVMMipsAsmParser",
    "LLVMMipsCodeGen",
    "LLVMMipsDesc",
    "LLVMMipsInfo",
    "LLVMLoongArchDisassembler",
    "LLVMLoongArchAsmParser",
    "LLVMLoongArchCodeGen",
    "LLVMLoongArchDesc",
    "LLVMLoongArchInfo",
    "LLVMLanaiDisassembler",
    "LLVMLanaiCodeGen",
    "LLVMLanaiAsmParser",
    "LLVMLanaiDesc",
    "LLVMLanaiInfo",
    "LLVMHexagonDisassembler",
    "LLVMHexagonCodeGen",
    "LLVMHexagonAsmParser",
    "LLVMHexagonDesc",
    "LLVMHexagonInfo",
    "LLVMBPFDisassembler",
    "LLVMBPFAsmParser",
    "LLVMBPFCodeGen",
    "LLVMBPFDesc",
    "LLVMBPFInfo",
    "LLVMAVRDisassembler",
    "LLVMAVRAsmParser",
    "LLVMAVRCodeGen",
    "LLVMAVRDesc",
    "LLVMAVRInfo",
    "LLVMARMDisassembler",
    "LLVMARMAsmParser",
    "LLVMARMCodeGen",
    "LLVMARMDesc",
    "LLVMARMUtils",
    "LLVMARMInfo",
    "LLVMAMDGPUTargetMCA",
    "LLVMAMDGPUDisassembler",
    "LLVMAMDGPUAsmParser",
    "LLVMAMDGPUCodeGen",
    "LLVMAMDGPUDesc",
    "LLVMAMDGPUUtils",
    "LLVMAMDGPUInfo",
    "LLVMAArch64Disassembler",
    "LLVMAArch64AsmParser",
    "LLVMAArch64CodeGen",
    "LLVMAArch64Desc",
    "LLVMAArch64Utils",
    "LLVMAArch64Info",
    "LLVMOrcDebugging",
    "LLVMOrcJIT",
    "LLVMWindowsDriver",
    "LLVMMCJIT",
    "LLVMJITLink",
    "LLVMInterpreter",
    "LLVMExecutionEngine",
    "LLVMRuntimeDyld",
    "LLVMOrcTargetProcess",
    "LLVMOrcShared",
    "LLVMDWP",
    "LLVMDebugInfoLogicalView",
    "LLVMDebugInfoGSYM",
    "LLVMOption",
    "LLVMObjectYAML",
    "LLVMObjCopy",
    "LLVMMCA",
    "LLVMMCDisassembler",
    "LLVMLTO",
    "LLVMPasses",
    "LLVMHipStdPar",
    "LLVMCFGuard",
    "LLVMCoroutines",
    "LLVMipo",
    "LLVMVectorize",
    "LLVMSandboxIR",
    "LLVMLinker",
    "LLVMInstrumentation",
    "LLVMFrontendOpenMP",
    "LLVMFrontendOffloading",
    "LLVMFrontendOpenACC",
    "LLVMFrontendHLSL",
    "LLVMFrontendDriver",
    "LLVMFrontendAtomic",
    "LLVMExtensions",
    "LLVMDWARFLinkerParallel",
    "LLVMDWARFLinkerClassic",
    "LLVMDWARFLinker",
    "LLVMGlobalISel",
    "LLVMMIRParser",
    "LLVMAsmPrinter",
    "LLVMSelectionDAG",
    "LLVMCodeGen",
    "LLVMTarget",
    "LLVMObjCARCOpts",
    "LLVMCodeGenTypes",
    "LLVMCGData",
    "LLVMIRPrinter",
    "LLVMInterfaceStub",
    "LLVMFileCheck",
    "LLVMFuzzMutate",
    "LLVMScalarOpts",
    "LLVMInstCombine",
    "LLVMAggressiveInstCombine",
    "LLVMTransformUtils",
    "LLVMBitWriter",
    "LLVMAnalysis",
    "LLVMProfileData",
    "LLVMSymbolize",
    "LLVMDebugInfoBTF",
    "LLVMDebugInfoPDB",
    "LLVMDebugInfoMSF",
    "LLVMDebugInfoCodeView",
    "LLVMDebugInfoDWARF",
    "LLVMObject",
    "LLVMTextAPI",
    "LLVMMCParser",
    "LLVMIRReader",
    "LLVMAsmParser",
    "LLVMMC",
    "LLVMBitReader",
    "LLVMFuzzerCLI",
    "LLVMCore",
    "LLVMRemarks",
    "LLVMBitstreamReader",
    "LLVMBinaryFormat",
    "LLVMTargetParser",
    "LLVMSupport",
    "LLVMDemangle",
};
