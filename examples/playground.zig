const std = @import("std");

const llvm = @import("llvm");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const native_triple = llvm.target.Target.getDefaultTriple();
    std.debug.print("Found target triple to be '{s}'.\n", .{native_triple});

    llvm.target.TargetArch.initAllTargetInfos();
    const target = llvm.target.Target.fromTriple(native_triple);

    const arch = llvm.target.TargetArch.X86;
    arch.initFull();

    const machine = llvm.target.TargetMachine.create(
        target,
        native_triple,
        "generic",
        "",
        .Default,
        .Default,
        .Default,
    );
    const target_layout = machine.createTargetDataLayout();
    defer target_layout.dispose();

    const ctx = llvm.context.Context.create();
    defer ctx.dispose();

    const util_module = buildUtilityModule(ctx, target_layout, native_triple);
    // No dispose, because link2 already disposes the source module.

    const main_module = buildMainModule(ctx, target_layout, native_triple);
    defer main_module.dispose();

    // Link modules together.
    _ = llvm.linker.Linker.link2(main_module, util_module);

    // Run optimization passes.
    const pm = llvm.pass.PassBuilderOptions.create();
    defer pm.dispose();
    _ = pm.runOnModule(main_module, machine, "default<O3>");

    // Dump main module and emit asm.
    main_module.dump();

    try emitAsmFile(io, main_module, machine);

    llvm.LLVMShutdown();
}

fn buildUtilityModule(cx: *llvm.context.Context, layout: *llvm.target.TargetData, triple: [*:0]const u8) *llvm.module.Module {
    const module = cx.createModuleWithName("utils");

    module.setDataLayout(layout);
    module.setTargetTriple(triple);

    // "sum" function.
    const fn_type = llvm.types.Type.functionType(cx.intType(32), &.{
        cx.intType(32),
        cx.intType(32),
    }, false);
    const sum_fn = module.addFunction("sum", fn_type);
    sum_fn.setCC(.Fast);
    sum_fn.asGlobal().setLinkage(.LinkOnceODR);
    const entry_bb = sum_fn.appendBasicBlock("entry");

    const builder = cx.createBuilder();
    defer builder.dispose();

    builder.positionAtEnd(entry_bb);
    const a = sum_fn.getParam(0);
    const b = sum_fn.getParam(1);
    const sum = builder.buildAdd(a, b, "sum");
    _ = builder.buildRet(sum);

    return module;
}

fn buildMainModule(cx: *llvm.context.Context, layout: *llvm.target.TargetData, triple: [*:0]const u8) *llvm.module.Module {
    const module = cx.createModuleWithName("main");

    module.setDataLayout(layout);
    module.setTargetTriple(triple);

    const start_fn_type = llvm.types.Type.functionType(cx.intType(32), &.{}, false);
    const start_fn = module.addFunction("_start", start_fn_type);
    const start_entry_bb = start_fn.appendBasicBlock("entry");

    const builder = cx.createBuilder();
    defer builder.dispose();

    const sum_fn_type = llvm.types.Type.functionType(cx.intType(32), &.{
        cx.intType(32),
        cx.intType(32),
    }, false);
    const sum_fn_decl = module.addFunction("sum", sum_fn_type);

    builder.positionAtEnd(start_entry_bb);
    const sum2 = builder.buildCall(sum_fn_type, sum_fn_decl.asValue(), &.{
        llvm.builder.Constant.constInt(cx.intType(32), 2, false),
        llvm.builder.Constant.constInt(cx.intType(32), 3, false),
    }, "add_res");
    sum2.setInstCC(.Fast); // Is this necessary?
    _ = builder.buildRet(sum2);

    return module;
}

fn emitAsmFile(io: std.Io, module: *llvm.module.Module, machine: *llvm.target.TargetMachine) !void {
    const cwd_parent = try std.Io.Dir.cwd().realPathFileAlloc(io, ".", std.heap.c_allocator);
    const out_dir = try std.fs.path.join(std.heap.c_allocator, &.{ cwd_parent, "ignore-me" });
    std.heap.c_allocator.free(cwd_parent);

    std.Io.Dir.createDirAbsolute(io, out_dir, std.Io.Dir.Permissions.default_file) catch {
        std.debug.print("Skipping directory creation as it probably already exists.\n", .{});
    };
    const out_file = try std.fs.path.join(std.heap.c_allocator, &.{ out_dir, "playground.asm" });
    std.heap.c_allocator.free(out_dir);
    defer std.heap.c_allocator.free(out_file);

    const out_c = try toSentinel(out_file, std.heap.c_allocator);
    defer std.heap.c_allocator.free(out_c[0..out_file.len :0]);

    _ = machine.emitModuleToFile(module, out_c, .AssemblyFile);
}

fn toSentinel(str: []const u8, allocator: std.mem.Allocator) ![*:0]const u8 {
    var buf = try allocator.allocSentinel(u8, str.len, 0); // 0 = sentinel
    @memcpy(buf[0..str.len], str);
    return buf;
}
