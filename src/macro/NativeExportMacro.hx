package macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import Lambda;

/**
 * Build macro that auto-generates extern "C" DLL wrapper functions for every
 * `@:keep public static` method on the annotated class.
 *
 * Usage:
 *   @:build(macro.NativeExportMacro.build())
 *   class Editor { ... }
 *
 * Opt-out for individual methods:
 *   @:noExport @:keep public static function init():Int { ... }
 *
 * The generated C++ replaces the hand-written @:cppFileCode block with:
 *   - A fixed prologue (SDL log hook, hxcpp_initialized guard, HxcppInit,
 *     init wrapper with hxcpp_initialized check, initWithCallback)
 *   - One __declspec(dllexport) wrapper per qualifying method
 *
 * Type mapping (Haxe → C):
 *   Int        → int
 *   Float      → float
 *   Bool       → int
 *   String     → const char*   (return: .__s   arg: ::String(...))
 *   Void       → void
 *   cpp.Pointer<T>    → T*     (arg: (cpp::Pointer<T>)ptr)
 *   cpp.RawPointer<T> → T*     (arg: passed as-is)
 *   cpp.RawPointer<cpp.Void> → void*
 */
class NativeExportMacro {

    // ── Type helpers ────────────────────────────────────────────────────────

    /** Converts a Haxe ComplexType to a C type string. */
    static function toCType(t:Null<ComplexType>):String {
        if (t == null) return "void";
        return switch t {
            case TPath(p):
                switch p.name {
                    case "Void":    "void";
                    case "Int":     "int";
                    case "Float":   "float";
                    case "Bool":    "bool";
                    case "String":  "const char*";
                    case "Pointer" | "RawPointer":
                        var inner = firstParamType(p.params);
                        if (inner == null) return "void*";
                        var innerC = toCType(inner);
                        (innerC == "Void" || innerC == "void") ? "void*" : innerC + "*";
                    default:
                        // Struct externs: MapProps, TilesetInfoStruct, etc.
                        p.name;
                }
            default: "void";
        }
    }

    /** Extracts the ComplexType from the first TypeParam, if any. */
    static function firstParamType(params:Null<Array<TypeParam>>):Null<ComplexType> {
        if (params == null || params.length == 0) return null;
        return switch params[0] {
            case TPType(t): t;
            default: null;
        };
    }

    /**
     * Returns the short type name for the inner type of Pointer<T> / RawPointer<T>,
     * used when emitting `(cpp::Pointer<T>)` cast expressions.
     */
    static function pointerInnerName(t:ComplexType):Null<String> {
        return switch t {
            case TPath(p) if (p.name == "Pointer" || p.name == "RawPointer"):
                switch firstParamType(p.params) {
                    case TPath(ip): ip.name;
                    default: null;
                }
            default: null;
        };
    }

    /**
     * Converts a single function argument from C to the expression used when
     * calling the corresponding Haxe static method.
     */
    static function toCallArg(name:String, t:Null<ComplexType>):String {
        if (t == null) return name;
        return switch t {
            case TPath(p):
                switch p.name {
                    case "String":
                        '::String($name)';
                    case "Pointer":
                        var inner = pointerInnerName(t);
                        inner != null ? '(cpp::Pointer<$inner>)$name' : name;
                    default:
                        name;
                }
            default: name;
        };
    }

    /**
     * Wraps the Haxe call expression into a C return statement, adding `.__s`
     * for String returns and nothing for void.
     */
    static function wrapReturn(call:String, ret:Null<ComplexType>):String {
        if (ret == null) return '$call;';
        return switch ret {
            case TPath(p) if (p.name == "Void"):    '$call;';
            case TPath(p) if (p.name == "String"):  'return $call.__s;';
            default:                                'return $call;';
        };
    }

    // ── Main build entry ────────────────────────────────────────────────────

    public static function build():Array<Field> {
        var fields = Context.getBuildFields();
        var cls   = Context.getLocalClass().get();
        var obj   = cls.name + "_obj";   // e.g. "Editor_obj"

        var sb = new StringBuf();

        // ── Fixed prologue ──────────────────────────────────────────────────
        sb.add('#include <SDL3/SDL_log.h>\n');
        sb.add('\n');
        sb.add('bool hxcpp_initialized = false;\n');
        sb.add('CustomCallback g_callback = nullptr;\n');
        sb.add('EntitySelectionChangedCallback g_entitySelectionChangedCallback = nullptr;\n');
        sb.add('\n');
        sb.add('void SDLCALL CustomLogOutput(void* userdata, int category, SDL_LogPriority priority, const char* message) {\n');
        sb.add('    if (g_callback != nullptr) {\n');
        sb.add('        char buffer[1024];\n');
        sb.add('        snprintf(buffer, sizeof(buffer), "%s", message);\n');
        sb.add('        const char* priorityStr;\n');
        sb.add('        switch (priority) {\n');
        sb.add('            case SDL_LOG_PRIORITY_VERBOSE:  priorityStr = "VERBOSE";  break;\n');
        sb.add('            case SDL_LOG_PRIORITY_DEBUG:    priorityStr = "DEBUG";    break;\n');
        sb.add('            case SDL_LOG_PRIORITY_INFO:     priorityStr = "INFO";     break;\n');
        sb.add('            case SDL_LOG_PRIORITY_WARN:     priorityStr = "WARN";     break;\n');
        sb.add('            case SDL_LOG_PRIORITY_ERROR:    priorityStr = "ERROR";    break;\n');
        sb.add('            case SDL_LOG_PRIORITY_CRITICAL: priorityStr = "CRITICAL"; break;\n');
        sb.add('            default:                        priorityStr = "LOG";      break;\n');
        sb.add('        }\n');
        sb.add('        const char* categoryStr;\n');
        sb.add('        switch (category) {\n');
        sb.add('            case SDL_LOG_CATEGORY_APPLICATION: categoryStr = "APP";    break;\n');
        sb.add('            case SDL_LOG_CATEGORY_ERROR:       categoryStr = "ERROR";  break;\n');
        sb.add('            case SDL_LOG_CATEGORY_ASSERT:      categoryStr = "ASSERT"; break;\n');
        sb.add('            case SDL_LOG_CATEGORY_SYSTEM:      categoryStr = "SYSTEM"; break;\n');
        sb.add('            case SDL_LOG_CATEGORY_AUDIO:       categoryStr = "AUDIO";  break;\n');
        sb.add('            case SDL_LOG_CATEGORY_VIDEO:       categoryStr = "VIDEO";  break;\n');
        sb.add('            case SDL_LOG_CATEGORY_RENDER:      categoryStr = "RENDER"; break;\n');
        sb.add('            case SDL_LOG_CATEGORY_INPUT:       categoryStr = "INPUT";  break;\n');
        sb.add('            case SDL_LOG_CATEGORY_TEST:        categoryStr = "TEST";   break;\n');
        sb.add('            case SDL_LOG_CATEGORY_GPU:         categoryStr = "GPU";    break;\n');
        sb.add('            default:                           categoryStr = "CUSTOM"; break;\n');
        sb.add('        }\n');
        sb.add('        g_callback(priorityStr, categoryStr, buffer);\n');
        sb.add('    }\n');
        sb.add('}\n');
        sb.add('\n');
        sb.add('extern "C" {\n');
        sb.add('\n');
        sb.add('    __declspec(dllexport) const char* HxcppInit() {\n');
        sb.add('        if (hxcpp_initialized) {\n');
        sb.add('            return NULL;  // Already initialized\n');
        sb.add('        }\n');
        sb.add('        const char* err = hx::Init();\n');
        sb.add('        if (err == NULL) {\n');
        sb.add('            hxcpp_initialized = true;\n');
        sb.add('        }\n');
        sb.add('        return err;\n');
        sb.add('    }\n');
        sb.add('\n');
        sb.add('    __declspec(dllexport) bool init() {\n');
        sb.add('        if (!hxcpp_initialized) {\n');
        sb.add('            const char* err = hx::Init();\n');
        sb.add('            if (err != NULL) return false;\n');
        sb.add('            hxcpp_initialized = true;\n');
        sb.add('        }\n');
        sb.add('        hx::NativeAttach attach;\n');
        sb.add('        return ::$obj::init();\n');
        sb.add('    }\n');
        sb.add('\n');
        sb.add('    __declspec(dllexport) bool initWithCallback(CustomCallback callback) {\n');
        sb.add('        if (callback != nullptr) {\n');
        sb.add('            g_callback = callback;\n');
        sb.add('            SDL_SetLogOutputFunction(CustomLogOutput, (void*)callback);\n');
        sb.add('        }\n');
        sb.add('        return init();\n');
        sb.add('    }\n');
        sb.add('\n');
        sb.add('    __declspec(dllexport) void setEntitySelectionChangedCallback(EntitySelectionChangedCallback callback) {\n');
        sb.add('        g_entitySelectionChangedCallback = callback;\n');
        sb.add('    }\n');

        // ── Auto-generated wrappers ─────────────────────────────────────────
        for (field in fields) {
            switch field.kind {
                case FFun(f):
                    // Must be @:keep public static
                    if (!field.access.contains(APublic)) continue;
                    if (!field.access.contains(AStatic)) continue;

                    var meta:Array<MetadataEntry> = field.meta != null ? field.meta : [];

                    if (!Lambda.exists(meta, m -> m.name == ":keep")) continue;

                    // Respect @:noExport opt-out
                    if (Lambda.exists(meta, m -> m.name == ":noExport")) continue;

                    // Never re-emit 'main' or the already-hardcoded 'init'
                    if (field.name == "main" || field.name == "init") continue;

                    // Build C parameter list and Haxe call-arg list
                    var cParams:Array<String>   = [];
                    var callArgs:Array<String>  = [];

                    for (arg in f.args) {
                        cParams.push(toCType(arg.type) + " " + arg.name);
                        callArgs.push(toCallArg(arg.name, arg.type));
                    }

                    var retC   = toCType(f.ret);
                    var call   = '::$obj::${field.name}(${callArgs.join(", ")})';
                    var body   = wrapReturn(call, f.ret);

                    sb.add('\n');
                    sb.add('    __declspec(dllexport) $retC ${field.name}(${cParams.join(", ")}) {\n');
                    sb.add('        $body\n');
                    sb.add('    }\n');

                default: // ignore non-function fields
            }
        }

        sb.add('\n}\n');

        // ── Inject generated code as @:cppFileCode ──────────────────────────
        // Remove any pre-existing @:cppFileCode so we don't get duplicates.
        if (cls.meta.has(":cppFileCode")) {
            cls.meta.remove(":cppFileCode");
        }
        cls.meta.add(":cppFileCode", [macro $v{sb.toString()}], cls.pos);

        return fields;
    }
}
