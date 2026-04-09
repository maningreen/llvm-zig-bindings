const std = @import("std");

const module = @import("module.zig");
const types = @import("types.zig");

pub const Target = opaque {
    pub const getDefaultTriple = LLVMGetDefaultTargetTriple;
    extern fn LLVMGetDefaultTargetTriple() [*:0]const u8;

    pub fn fromTriple(triple: [*:0]const u8) *Target {
        var T: *Target = undefined;
        var err: [*:0]const u8 = undefined;
        if (LLVMGetTargetFromTriple(triple, &T, &err).toBool()) {
            std.debug.print("Error message from LLVMGetTargetFromTriple: {s}", .{err});
            @panic("LLVMGetTargetFromTriple failed."); // Error leaks here, but who cares if program panics.
        }
        return T;
    }

    extern fn LLVMGetTargetFromTriple(Triple: [*:0]const u8, T: **Target, ErrorMessage: *[*:0]const u8) types.Bool;

    pub fn getArch(self: *Target) TargetArch {
        _ = self;
        @compileError("getArch is not yet supported");
        // const name = LLVMGetTargetName(self);
        // const name_slice: []const u8 = std.mem.span(name);
        // return std.meta.stringToEnum(TargetArch, name_slice).?;
    }
    extern fn LLVMGetTargetName(T: *Target) [*:0]const u8;
};

pub const TargetData = opaque {
    pub const dispose = LLVMDisposeTargetData;
    extern fn LLVMDisposeTargetData(*TargetData) void;

    pub const abiAlignmentOfType = LLVMABIAlignmentOfType;
    extern fn LLVMABIAlignmentOfType(TD: *TargetData, Ty: *types.Type) c_uint;
};

pub const TargetMachine = opaque {
    pub const create = LLVMCreateTargetMachine;
    extern fn LLVMCreateTargetMachine(
        T: *Target,
        Triple: [*:0]const u8,
        CPU: [*:0]const u8,
        Features: [*:0]const u8,
        Level: CodeGenOptLevel,
        Reloc: RelocMode,
        CodeModel: CodeModel,
    ) *TargetMachine;

    pub const dispose = LLVMDisposeTargetMachine;
    extern fn LLVMDisposeTargetMachine(T: *TargetMachine) void;

    pub const createTargetDataLayout = LLVMCreateTargetDataLayout;
    extern fn LLVMCreateTargetDataLayout(*TargetMachine) *TargetData;

    pub fn emitModuleToFile(self: *TargetMachine, mod: *module.Module, filename: [*:0]const u8, codegen: CodegenType) bool {
        var err: [*:0]const u8 = undefined;
        if (LLVMTargetMachineEmitToFile(self, mod, filename, codegen, &err).toBool()) {
            std.debug.print("Error message from LLVMTargetMachineEmitToFile: {s}", .{err});
            return false;
        }
        return true;
    }
    extern fn LLVMTargetMachineEmitToFile(
        T: *TargetMachine,
        M: *module.Module,
        Filename: [*:0]const u8,
        codegen: CodegenType,
        ErrorMessage: *[*:0]const u8,
    ) types.Bool;
};

pub const CodegenType = enum(c_int) { AssemblyFile, ObjectFile };

pub const CodeModel = enum(c_int) {
    Default,
    JITDefault,
    Tiny,
    Small,
    Kernel,
    Medium,
    Large,
};

pub const CodeGenOptLevel = enum(c_int) {
    None,
    Less,
    Default,
    Aggressive,
};

pub const RelocMode = enum(c_int) {
    Default,
    Static,
    PIC,
    DynamicNoPIC,
    ROPI,
    RWPI,
    ROPI_RWPI,
};

pub const TargetArch = enum {
    AArch64,
    AMDGPU,
    ARM,
    AVR,
    BPF,
    Hexagon,
    Lanai,
    Mips,
    MSP430,
    // NVPTX, // There is no asm parser for this
    PowerPC,
    RISCV,
    Sparc,
    SystemZ,
    WebAssembly,
    X86,
    // XCore,  // Same here.
    VE,

    pub fn initFull(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_target_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "Target");
                const init_target_mc_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "TargetMC");
                const init_asm_printer_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "AsmPrinter");
                const init_asm_parser_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "AsmParser");
                @call(.auto, init_target_fn, .{});
                @call(.auto, init_target_mc_fn, .{});
                @call(.auto, init_asm_printer_fn, .{});
                @call(.auto, init_asm_parser_fn, .{});
            },
        }
    }

    pub fn initAllTargetInfos() callconv(.c) void {
        TargetInit.LLVMInitializeAArch64TargetInfo();
        TargetInit.LLVMInitializeAMDGPUTargetInfo();
        TargetInit.LLVMInitializeARMTargetInfo();
        TargetInit.LLVMInitializeAVRTargetInfo();
        TargetInit.LLVMInitializeBPFTargetInfo();
        TargetInit.LLVMInitializeHexagonTargetInfo();
        TargetInit.LLVMInitializeLanaiTargetInfo();
        TargetInit.LLVMInitializeMipsTargetInfo();
        TargetInit.LLVMInitializeMSP430TargetInfo();
        TargetInit.LLVMInitializeNVPTXTargetInfo();
        TargetInit.LLVMInitializePowerPCTargetInfo();
        TargetInit.LLVMInitializeRISCVTargetInfo();
        TargetInit.LLVMInitializeSparcTargetInfo();
        TargetInit.LLVMInitializeSystemZTargetInfo();
        TargetInit.LLVMInitializeWebAssemblyTargetInfo();
        TargetInit.LLVMInitializeX86TargetInfo();
        TargetInit.LLVMInitializeXCoreTargetInfo();
        TargetInit.LLVMInitializeVETargetInfo();
    }

    pub fn initTargetInfo(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "TargetInfo");
                @call(.auto, init_fn, .{});
            },
        }
    }
    pub fn initTarget(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "Target");
                @call(.auto, init_fn, .{});
            },
        }
    }
    pub fn initTargetMC(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "TargetMC");
                @call(.auto, init_fn, .{});
            },
        }
    }
    pub fn initAsmPrinter(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "AsmPrinter");
                @call(.auto, init_fn, .{});
            },
        }
    }
    pub fn initAsmParser(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "AsmParser");
                @call(.auto, init_fn, .{});
            },
        }
    }
    pub fn initDisassembler(self: TargetArch) void {
        switch (self) {
            inline else => |arch| {
                const arch_str = comptime std.enums.tagName(TargetArch, arch).?;
                const init_fn = @field(TargetInit, "LLVMInitialize" ++ arch_str ++ "Disassembler");
                @call(.auto, init_fn, .{});
            },
        }
    }
};

pub const TargetInit = opaque {
    pub extern fn LLVMInitializeAArch64TargetInfo() void;
    pub extern fn LLVMInitializeAMDGPUTargetInfo() void;
    pub extern fn LLVMInitializeARMTargetInfo() void;
    pub extern fn LLVMInitializeAVRTargetInfo() void;
    pub extern fn LLVMInitializeBPFTargetInfo() void;
    pub extern fn LLVMInitializeHexagonTargetInfo() void;
    pub extern fn LLVMInitializeLanaiTargetInfo() void;
    pub extern fn LLVMInitializeMipsTargetInfo() void;
    pub extern fn LLVMInitializeMSP430TargetInfo() void;
    pub extern fn LLVMInitializeNVPTXTargetInfo() void;
    pub extern fn LLVMInitializePowerPCTargetInfo() void;
    pub extern fn LLVMInitializeRISCVTargetInfo() void;
    pub extern fn LLVMInitializeSparcTargetInfo() void;
    pub extern fn LLVMInitializeSystemZTargetInfo() void;
    pub extern fn LLVMInitializeWebAssemblyTargetInfo() void;
    pub extern fn LLVMInitializeX86TargetInfo() void;
    pub extern fn LLVMInitializeXCoreTargetInfo() void;
    pub extern fn LLVMInitializeVETargetInfo() void;

    pub extern fn LLVMInitializeAArch64Target() void;
    pub extern fn LLVMInitializeAMDGPUTarget() void;
    pub extern fn LLVMInitializeARMTarget() void;
    pub extern fn LLVMInitializeAVRTarget() void;
    pub extern fn LLVMInitializeBPFTarget() void;
    pub extern fn LLVMInitializeHexagonTarget() void;
    pub extern fn LLVMInitializeLanaiTarget() void;
    pub extern fn LLVMInitializeMipsTarget() void;
    pub extern fn LLVMInitializeMSP430Target() void;
    pub extern fn LLVMInitializeNVPTXTarget() void;
    pub extern fn LLVMInitializePowerPCTarget() void;
    pub extern fn LLVMInitializeRISCVTarget() void;
    pub extern fn LLVMInitializeSparcTarget() void;
    pub extern fn LLVMInitializeSystemZTarget() void;
    pub extern fn LLVMInitializeWebAssemblyTarget() void;
    pub extern fn LLVMInitializeX86Target() void;
    pub extern fn LLVMInitializeXCoreTarget() void;
    pub extern fn LLVMInitializeVETarget() void;

    pub extern fn LLVMInitializeAArch64TargetMC() void;
    pub extern fn LLVMInitializeAMDGPUTargetMC() void;
    pub extern fn LLVMInitializeARMTargetMC() void;
    pub extern fn LLVMInitializeAVRTargetMC() void;
    pub extern fn LLVMInitializeBPFTargetMC() void;
    pub extern fn LLVMInitializeHexagonTargetMC() void;
    pub extern fn LLVMInitializeLanaiTargetMC() void;
    pub extern fn LLVMInitializeMipsTargetMC() void;
    pub extern fn LLVMInitializeMSP430TargetMC() void;
    pub extern fn LLVMInitializeNVPTXTargetMC() void;
    pub extern fn LLVMInitializePowerPCTargetMC() void;
    pub extern fn LLVMInitializeRISCVTargetMC() void;
    pub extern fn LLVMInitializeSparcTargetMC() void;
    pub extern fn LLVMInitializeSystemZTargetMC() void;
    pub extern fn LLVMInitializeWebAssemblyTargetMC() void;
    pub extern fn LLVMInitializeX86TargetMC() void;
    pub extern fn LLVMInitializeXCoreTargetMC() void;
    pub extern fn LLVMInitializeVETargetMC() void;

    pub extern fn LLVMInitializeAArch64AsmPrinter() void;
    pub extern fn LLVMInitializeAMDGPUAsmPrinter() void;
    pub extern fn LLVMInitializeARMAsmPrinter() void;
    pub extern fn LLVMInitializeAVRAsmPrinter() void;
    pub extern fn LLVMInitializeBPFAsmPrinter() void;
    pub extern fn LLVMInitializeHexagonAsmPrinter() void;
    pub extern fn LLVMInitializeLanaiAsmPrinter() void;
    pub extern fn LLVMInitializeMipsAsmPrinter() void;
    pub extern fn LLVMInitializeMSP430AsmPrinter() void;
    pub extern fn LLVMInitializeNVPTXAsmPrinter() void;
    pub extern fn LLVMInitializePowerPCAsmPrinter() void;
    pub extern fn LLVMInitializeRISCVAsmPrinter() void;
    pub extern fn LLVMInitializeSparcAsmPrinter() void;
    pub extern fn LLVMInitializeSystemZAsmPrinter() void;
    pub extern fn LLVMInitializeWebAssemblyAsmPrinter() void;
    pub extern fn LLVMInitializeX86AsmPrinter() void;
    pub extern fn LLVMInitializeXCoreAsmPrinter() void;
    pub extern fn LLVMInitializeVEAsmPrinter() void;

    pub extern fn LLVMInitializeAArch64AsmParser() void;
    pub extern fn LLVMInitializeAMDGPUAsmParser() void;
    pub extern fn LLVMInitializeARMAsmParser() void;
    pub extern fn LLVMInitializeAVRAsmParser() void;
    pub extern fn LLVMInitializeBPFAsmParser() void;
    pub extern fn LLVMInitializeHexagonAsmParser() void;
    pub extern fn LLVMInitializeLanaiAsmParser() void;
    pub extern fn LLVMInitializeMipsAsmParser() void;
    pub extern fn LLVMInitializeMSP430AsmParser() void;
    pub extern fn LLVMInitializePowerPCAsmParser() void;
    pub extern fn LLVMInitializeRISCVAsmParser() void;
    pub extern fn LLVMInitializeSparcAsmParser() void;
    pub extern fn LLVMInitializeSystemZAsmParser() void;
    pub extern fn LLVMInitializeWebAssemblyAsmParser() void;
    pub extern fn LLVMInitializeX86AsmParser() void;
    pub extern fn LLVMInitializeVEAsmParser() void;

    pub extern fn LLVMInitializeAArch64Disassembler() void;
    pub extern fn LLVMInitializeAMDGPUDisassembler() void;
    pub extern fn LLVMInitializeARMDisassembler() void;
    pub extern fn LLVMInitializeAVRDisassembler() void;
    pub extern fn LLVMInitializeBPFDisassembler() void;
    pub extern fn LLVMInitializeHexagonDisassembler() void;
    pub extern fn LLVMInitializeLanaiDisassembler() void;
    pub extern fn LLVMInitializeMipsDisassembler() void;
    pub extern fn LLVMInitializeMSP430Disassembler() void;
    pub extern fn LLVMInitializePowerPCDisassembler() void;
    pub extern fn LLVMInitializeRISCVDisassembler() void;
    pub extern fn LLVMInitializeSparcDisassembler() void;
    pub extern fn LLVMInitializeSystemZDisassembler() void;
    pub extern fn LLVMInitializeVEDisassembler() void;
    pub extern fn LLVMInitializeWebAssemblyDisassembler() void;
    pub extern fn LLVMInitializeX86Disassembler() void;
    pub extern fn LLVMInitializeXCoreDisassembler() void;
};
