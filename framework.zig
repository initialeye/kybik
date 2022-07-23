const std = @import ("std");

pub const API_VERSION: usize = 0;

//TODO make as pointers
pub const Module = *align(stdalign) anyopaque;
pub const Signal = opaque{};
pub const VPtr = opaque{};
pub const FnPtr = opaque{};

pub const String = Slice(u8);
pub const Deps = Slice(Dependency);

pub const SubCallback = fn(String, CbCtx) callconv(.C) void;
pub const SchedCallback = fn(CbCtx) callconv(.C) void;
pub const FileIterateCallback = fn(String, String) callconv(.C) void;

pub const stdalign = @alignOf(*void);

pub const CbCtx = extern struct {
    f1: usize,
    f2: ?*anyopaque,
};

pub const Action = extern struct {
    ctx: CbCtx,
    execute: fn(CbCtx) callconv(.C) void,
    destroy: fn(CbCtx) callconv(.C) void,
};

pub const Allocator = extern struct {
    ptr: *anyopaque,
    vtable: *align(stdalign) const anyopaque,
};

pub fn Slice(comptime T: type) type {
    return extern struct {
        data: [*]const T,
        size: usize,

        pub fn from(this: @This()) []const T {
            return this.data[0..this.size];
        }
        pub fn init(data: []const T) @This() {
            return .{ .data = data.ptr, .size = data.len, };
        }
    };
}

// Compatibility depends on interface API 
pub const CompatVersion = extern struct {
    major: u16,
    minor: u16,
    
    pub fn init(ma: u16, mi: u16) CompatVersion {
        return .{
            .major = ma,
            .minor = mi,
        };
    }

    pub fn num(this: CompatVersion) u32 {
        return @bitCast(u32, this);
    }
};

// Patch depends on module implementation
pub const PatchVersion = extern struct {
    patch: u16,
    build: u16,
    
    pub fn init(pt: u16, bu: u16) PatchVersion {
        return .{
            .patch = pt,
            .build = bu,
        };
    }
};

pub const Version = extern struct {
    c: CompatVersion,
    p: PatchVersion,

    pub fn init(c: CompatVersion, p: PatchVersion) Version {
        return .{
            .c = c,
            .p = p,
        };
    }

    pub fn num(this: Version) u64 {
        return @bitCast(u64, this);
    }
    
    pub fn compat(this: Version) CompatVersion {
        return this.c;
    }
    
    pub fn patch(this: Version) PatchVersion {
        return this.p;
    }
};

pub const Dependency = extern struct {
    min: CompatVersion,
    max: CompatVersion,
    ifn: String,
    
    pub fn init(min: CompatVersion, max: CompatVersion, ifname: String) Dependency {
        return .{
            .min = min,
            .max = max,
            .ifn = ifname,
        };
    }
    
    pub fn check(this: Dependency, ver: Version) bool {
        return this.min.num() <= ver.compat().num() and this.max.num() >= ver.compat().num();
    }
};

pub const Attributes = packed struct {
    multiple_versions: u1,
    multiple_modules:  u1,
    padding: u62 = 0,
};

pub const ModuleHeader = extern struct {
    name: String,
    desc: String,
    deps: Deps,
    vers: Version,
    logp: [8]u8,
    dirn: [8]u8,
    func: ModuleFunctions,
    intf: Interface,
};

pub const ModuleFunctions = extern struct {
    init: fn(*const Core, Module) callconv(.C) void,
    quit: fn() callconv(.C) void,
    run: fn() callconv(.C) void,
    handle: fn(*const Interface, u64) callconv(.C) void,
    resolve_dependency: fn(*const ModuleHeader) callconv(.C) bool,
};

pub const Interface = extern struct {
    name: String,
    desc: String,
    attr: Attributes,
    iffn: InterfaceFunctions,
    get_func_info: fn(*const FnPtr) callconv(.C) String,
};

pub const InterfaceFunctions = extern struct {
    vptr: *const VPtr,
    len:  usize,
};

pub const LogLevel = enum(u8) {
    Critical,
    Error,
    Warning,
    MainInfo,
    AdditionInfo,
    DebugLevel0,
    DebugLevel1,
    DebugLevel2,
    DebugLevel3,
    DebugLevel4,
};

pub const Core = extern struct {
    exit: fn() callconv(.C) void,
    log: fn(Module, LogLevel, String) callconv(.C) void,
    get_allocator: fn (Module) callconv(.C) Allocator,
    get_if: fn(String) callconv(.C) ?*const Interface,
    get_if_specific: fn(String, Version) callconv(.C) ?*const Interface,
    get_if_ver_num: fn(String, usize) callconv(.C)  ?*const Interface,
    get_if_ver_count: fn(String) callconv(.C) usize,
    get_if_count: fn() callconv(.C) usize,
    get_if_name: fn(usize) callconv(.C) String,
    get_resource_path: fn(Module) callconv(.C) String, 
    subscribe: fn (String, Version, String, SubCallback) callconv(.C) u8,
    register: fn (Module, String) callconv(.C) *const Signal,
    emit: fn (*const Signal, CbCtx) callconv(.C) usize,
    schedule_task: fn(Module, SchedCallback, u64, CbCtx) callconv(.C) void,
    iterate_files: fn(Module, String, String, FileIterateCallback) callconv(.C) void,
    nanotime: fn() callconv(.C) u64,
};
