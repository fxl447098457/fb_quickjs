' quickjs.bi -- Full, accurate FreeBASIC binding for quickjs-ng (as of 2025)
' Based strictly on the provided quickjs.h
' Auto-adapts: 32-bit â†?JS_NAN_BOXING=1; 64-bit â†?struct mode
' Use with fbc -m32 or fbc -m64

#ifndef __QUICKJS_BI__
#define __QUICKJS_BI__

#include "crt/stdio.bi"
#include "crt/stdint.bi"
#include "crt/string.bi"
#include "crt/math.bi"
#inclib "qjs"
extern "C"

' ----------------------------
' Opaque types
' ----------------------------
type JSRuntime as any ptr
type JSContext as any ptr
type JSObject as any ptr
type JSClass as any ptr
type JSModuleDef as any ptr
type JSGCObjectHeader as any ptr

' ----------------------------
' Basic typedefs
' ----------------------------
type JSClassID as uint32_t
type JSAtom as uint32_t

' ----------------------------
' Tags
' ----------------------------
const JS_TAG_FIRST            = -9
const JS_TAG_BIG_INT          = -9
const JS_TAG_SYMBOL           = -8
const JS_TAG_STRING           = -7
const JS_TAG_MODULE           = -3
const JS_TAG_FUNCTION_BYTECODE= -2
const JS_TAG_OBJECT           = -1
const JS_TAG_INT              = 0
const JS_TAG_BOOL             = 1
const JS_TAG_NULL             = 2
const JS_TAG_UNDEFINED        = 3
const JS_TAG_UNINITIALIZED    = 4
const JS_TAG_CATCH_OFFSET     = 5
const JS_TAG_EXCEPTION        = 6
const JS_TAG_SHORT_BIG_INT    = 7
const JS_TAG_FLOAT64          = 8

' ----------------------------
' Platform-dependent JSValue definition
' ----------------------------
#ifdef __FB_64BIT__
    ' 64-bit: JS_NAN_BOXING is OFF 
    union JSValueUnion
        As int32_t      INT32
        As Double       float64
        As Any Ptr      PTR_
        as int32_t      short_big_int
    end union

    type JSValue
        as JSValueUnion u
        as int64_t      tag
    end type

    type JSValueConst as JSValue

    function JS_VALUE_GET_TAG(byval v as JSValue) as integer
        return cint(v.tag)
    end function

    function JS_VALUE_GET_NORM_TAG(byval v as JSValue) as integer
        Return JS_VALUE_GET_TAG(v)
    end function

    Function JS_VALUE_GET_INT(ByVal v As JSValue) As Integer
        Return v.u.INT32
    end function

    Function JS_VALUE_GET_BOOL(ByVal v As JSValue) As Integer
        Return v.u.int32
    end function

    function JS_VALUE_GET_SHORT_BIG_INT(byval v as JSValue) as integer
        Return v.u.short_big_int
    end function

    function JS_VALUE_GET_PTR(byval v as JSValue) as any ptr
        Return v.u.PTR_
    end function

    Function JS_VALUE_GET_FLOAT64(ByVal v As JSValue) As Double
        Return v.u.float64
    end function

    Function JS_MKPTR(ByVal tag As int64_t, ByVal p As Any Ptr) As JSValue
        Dim As JSValue v
        v.u.PTR_ = p
        v.tag = tag
        Return v
    end function

    Function JS_MKVAL(ByVal tag As int64_t, ByVal val_ As int32_t) As JSValue
        dim as JSValue v
        v.u.INT32 = val_
        v.tag = tag
        return v
    end function

    #define JS_NAN (type<JSValue>(type<JSValueUnion>(NAN), JS_TAG_FLOAT64))

    function JS_TAG_IS_FLOAT64(byval tag as integer) as boolean
        return (cuint(tag) = cuint(JS_TAG_FLOAT64))
    end function

    function JS_VALUE_IS_NAN(byval v as JSValue) as boolean
        if v.tag <> JS_TAG_FLOAT64 then return false
        dim as uint64_t u64 = *cptr(uint64_t ptr, @v.u.float64)
        return (u64 and &h7FFFFFFFFFFFFFFFull) > &h7FF0000000000000ull
    end function
    
#else
    ' 32-bit: JS_NAN_BOXING is ON â†?uint64_t mode
    type JSValue as uint64_t
    type JSValueConst as JSValue

    const JS_FLOAT64_TAG_ADDEND as uint64_t = &h0007800000000000ull

    function JS_VALUE_GET_TAG(byval v as JSValue) as integer
        return cint(v shr 32)
    end function

    Function JS_VALUE_GET_NORM_TAG(ByVal v As JSValue) As Integer
        dim as uint32_t tag = JS_VALUE_GET_TAG(v)
        if ((tag - JS_TAG_FIRST) >= (JS_TAG_FLOAT64 - JS_TAG_FIRST)) then
            return JS_TAG_FLOAT64
        else
            return tag
        end if
    end function

    function JS_VALUE_GET_INT(byval v as JSValue) as integer
        return cint(v and &hFFFFFFFFull)
    end function

    function JS_VALUE_GET_BOOL(byval v as JSValue) as integer
        return cint(v and &hFFFFFFFFull)
    end function

    function JS_VALUE_GET_SHORT_BIG_INT(byval v as JSValue) as integer
        return cint(v and &hFFFFFFFFull)
    End Function


    function JS_VALUE_GET_FLOAT64(byval v as JSValue) as double
        dim as uint64_t temp = v + (JS_FLOAT64_TAG_ADDEND shl 32)
        return *cptr(double ptr, @temp)
    end function

    Function JS_MKPTR(ByVal tag As Integer, ByVal p As Any Ptr) As JSValue
        Return (CULngInt(tag) Shl 32) Or CULngInt(Cast(UInteger,p))
    end function

    Function JS_MKVAL(ByVal tag As Integer, ByVal val_ As Integer) As JSValue
        Return (CULngInt(tag) Shl 32) Or (CULngInt(val_) And &hFFFFFFFFull)
    end function

    const JS_NAN as uint64_t = &h7FF8000000000000ull - (JS_FLOAT64_TAG_ADDEND shl 32)

    function JS_TAG_IS_FLOAT64(byval tag as integer) as boolean
        return cuint(tag - JS_TAG_FIRST) >= cuint(JS_TAG_FLOAT64 - JS_TAG_FIRST)
    end function

    function JS_VALUE_IS_NAN(byval v as JSValue) as boolean
        return (v shr 32) = (JS_NAN shr 32)
    end function

#endif

Function JS_NewFloat64(ByVal ctx As JSContext Ptr, ByVal val_ As Double) As JSValue
    #ifdef __FB_64BIT__
        Dim As JSValue v
        v.u.float64 = val_
        v.tag = JS_TAG_FLOAT64
        return v
    #else
        ' Encode float64 for NaN-boxing
        Dim As uint64_t u64 = *CPtr(uint64_t Ptr, @val_)
        Return u64 - (JS_FLOAT64_TAG_ADDEND Shl 32)
    #endif
End Function
' ----------------------------
' Helper macros (as functions or constants)
' ----------------------------
#define JS_VALUE_IS_BOTH_INT(v1, v2) ((JS_VALUE_GET_TAG(v1) or JS_VALUE_GET_TAG(v2)) = 0)
#define JS_VALUE_IS_BOTH_FLOAT(v1, v2) (JS_TAG_IS_FLOAT64(JS_VALUE_GET_TAG(v1)) and JS_TAG_IS_FLOAT64(JS_VALUE_GET_TAG(v2)))
#define JS_VALUE_GET_OBJ(v) (cptr(JSObject ptr, JS_VALUE_GET_PTR(v)))
#define JS_VALUE_HAS_REF_COUNT(v) (cuint(JS_VALUE_GET_TAG(v)) >= cuint(JS_TAG_FIRST))

' ----------------------------
' Special values
' ----------------------------
#define JS_NULL         JS_MKVAL(JS_TAG_NULL, 0)
#define JS_UNDEFINED    JS_MKVAL(JS_TAG_UNDEFINED, 0)
#define JS_FALSE        JS_MKVAL(JS_TAG_BOOL, 0)
#define JS_TRUE         JS_MKVAL(JS_TAG_BOOL, 1)
#define JS_EXCEPTION    JS_MKVAL(JS_TAG_EXCEPTION, 0)
#define JS_UNINITIALIZED JS_MKVAL(JS_TAG_UNINITIALIZED, 0)

' ----------------------------
' Property flags
' ----------------------------
const JS_PROP_CONFIGURABLE  = 1 shl 0
const JS_PROP_WRITABLE      = 1 shl 1
const JS_PROP_ENUMERABLE    = 1 shl 2
const JS_PROP_C_W_E         = JS_PROP_CONFIGURABLE or JS_PROP_WRITABLE or JS_PROP_ENUMERABLE
const JS_PROP_LENGTH        = 1 shl 3
const JS_PROP_TMASK         = 3 shl 4
const JS_PROP_NORMAL        = 0 shl 4
const JS_PROP_GETSET        = 1 shl 4
const JS_PROP_VARREF        = 2 shl 4
const JS_PROP_AUTOINIT      = 3 shl 4

const JS_PROP_HAS_SHIFT        = 8
const JS_PROP_HAS_CONFIGURABLE = 1 shl 8
const JS_PROP_HAS_WRITABLE     = 1 shl 9
const JS_PROP_HAS_ENUMERABLE   = 1 shl 10
const JS_PROP_HAS_GET          = 1 shl 11
const JS_PROP_HAS_SET          = 1 shl 12
const JS_PROP_HAS_VALUE        = 1 shl 13
const JS_PROP_THROW            = 1 shl 14
const JS_PROP_THROW_STRICT     = 1 shl 15
const JS_PROP_NO_ADD           = 1 shl 16
const JS_PROP_NO_EXOTIC        = 1 shl 17
const JS_PROP_DEFINE_PROPERTY  = 1 shl 18
const JS_PROP_REFLECT_DEFINE_PROPERTY = 1 shl 19

' ----------------------------
' JS_Eval flags
' ----------------------------
const JS_EVAL_TYPE_GLOBAL   = 0 shl 0
const JS_EVAL_TYPE_MODULE   = 1 shl 0
const JS_EVAL_TYPE_DIRECT   = 2 shl 0
const JS_EVAL_TYPE_INDIRECT = 3 shl 0
const JS_EVAL_TYPE_MASK     = 3 shl 0
const JS_EVAL_FLAG_STRICT   = 1 shl 3
const JS_EVAL_FLAG_UNUSED   = 1 shl 4
const JS_EVAL_FLAG_COMPILE_ONLY = 1 shl 5
const JS_EVAL_FLAG_BACKTRACE_BARRIER = 1 shl 6
const JS_EVAL_FLAG_ASYNC    = 1 shl 7

' ----------------------------
' Callback types
' ----------------------------
type JSCFunction as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr) as JSValue
type JSCFunctionMagic as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval magic as integer) as JSValue
type JSCFunctionData as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval magic as integer, byval func_data as JSValueConst ptr) as JSValue

' ----------------------------
' Malloc functions
' ----------------------------
type JSMallocFunctions
    js_calloc as function cdecl(byval opaque as any ptr, byval count as size_t, byval size as size_t) as any ptr
    js_malloc as function cdecl(byval opaque as any ptr, byval size as size_t) as any ptr
    js_free as sub cdecl(byval opaque as any ptr, byval ptr as any ptr)
    js_realloc as function cdecl(byval opaque as any ptr, byval ptr as any ptr, byval size as size_t) as any ptr
    js_malloc_usable_size as function cdecl(byval ptr as any ptr) as size_t
end type

' ----------------------------
' Dump flags
' ----------------------------
const JS_DUMP_BYTECODE_FINAL       = &h00001
const JS_DUMP_BYTECODE_PASS2       = &h00002
const JS_DUMP_BYTECODE_PASS1       = &h00004
const JS_DUMP_BYTECODE_HEX         = &h00010
const JS_DUMP_BYTECODE_PC2LINE     = &h00020
const JS_DUMP_BYTECODE_STACK       = &h00040
const JS_DUMP_BYTECODE_STEP        = &h00080
const JS_DUMP_READ_OBJECT          = &h00100
const JS_DUMP_FREE                 = &h00200
const JS_DUMP_GC                   = &h00400
const JS_DUMP_GC_FREE              = &h00800
const JS_DUMP_MODULE_RESOLVE       = &h01000
const JS_DUMP_PROMISE              = &h02000
const JS_DUMP_LEAKS                = &h04000
const JS_DUMP_ATOM_LEAKS           = &h08000
const JS_DUMP_MEM                  = &h10000
const JS_DUMP_OBJECTS              = &h20000
const JS_DUMP_ATOMS                = &h40000
const JS_DUMP_SHAPES               = &h80000

' ----------------------------
' Finalizer
' ----------------------------
type JSRuntimeFinalizer as sub cdecl(byval rt as JSRuntime ptr, byval arg as any ptr)
type JS_MarkFunc as sub cdecl(byval rt as JSRuntime ptr, byval gp as JSGCObjectHeader ptr)

' ----------------------------
' Atom & Property
' ----------------------------
const JS_ATOM_NULL = 0

type JSPropertyEnum
    as boolean is_enumerable
    as JSAtom  atom
end type

type JSPropertyDescriptor
    as integer flags
    as JSValue value
    as JSValue getter
    as JSValue setter
end type

' ----------------------------
' Exotic methods
' ----------------------------
type JSClassExoticMethods
    get_own_property as function cdecl(byval ctx as JSContext ptr, byval desc as JSPropertyDescriptor ptr, byval obj as JSValueConst, byval prop as JSAtom) as integer
    get_own_property_names as function cdecl(byval ctx as JSContext ptr, byval ptab as JSPropertyEnum ptr ptr, byval plen as uint32_t ptr, byval obj as JSValueConst) as integer
    delete_property as function cdecl(byval ctx as JSContext ptr, byval obj as JSValueConst, byval prop as JSAtom) as integer
    define_own_property as function cdecl(byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom, byval val_ as JSValueConst, byval getter as JSValueConst, byval setter as JSValueConst, byval flags as integer) as integer
    has_property as function cdecl(byval ctx as JSContext ptr, byval obj as JSValueConst, byval atom as JSAtom) as integer
    get_property as function cdecl(byval ctx as JSContext ptr, byval obj as JSValueConst, byval atom as JSAtom, byval receiver as JSValueConst) as JSValue
    set_property as function cdecl(byval ctx as JSContext ptr, byval obj as JSValueConst, byval atom as JSAtom, byval value as JSValueConst, byval receiver as JSValueConst, byval flags as integer) as integer
end type

' ----------------------------
' Class definition
' ----------------------------
type JSClassFinalizer as sub cdecl(byval rt as JSRuntime ptr, byval val_ as JSValueConst)
type JSClassGCMark as sub cdecl(byval rt as JSRuntime ptr, byval val_ as JSValueConst, byval mark_func as JS_MarkFunc ptr)

const JS_CALL_FLAG_CONSTRUCTOR = 1 shl 0

type JSClassCall as function cdecl(byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval flags as integer) as JSValue

type JSClassDef
    as zstring ptr class_name
    as JSClassFinalizer ptr finalizer
    as JSClassGCMark ptr gc_mark
    as JSClassCall ptr call
    as JSClassExoticMethods ptr exotic
end type

const JS_INVALID_CLASS_ID = 0

' ----------------------------
' Eval options
' ----------------------------
const JS_EVAL_OPTIONS_VERSION = 1

type JSEvalOptions
    as integer version
    as integer eval_flags
    as zstring ptr filename
    as integer line_num
end type

' ----------------------------
' Memory usage
' ----------------------------
type JSMemoryUsage
    as int64_t malloc_size, malloc_limit, memory_used_size
    as int64_t malloc_count
    as int64_t memory_used_count
    as int64_t atom_count, atom_size
    as int64_t str_count, str_size
    as int64_t obj_count, obj_size
    as int64_t prop_count, prop_size
    as int64_t shape_count, shape_size
    as int64_t js_func_count, js_func_size, js_func_code_size
    as int64_t js_func_pc2line_count, js_func_pc2line_size
    as int64_t c_func_count, array_count
    as int64_t fast_array_count, fast_array_elements
    as int64_t binary_object_count, binary_object_size
end type

' ----------------------------
' TypedArray
' ----------------------------
enum JSTypedArrayEnum
    JS_TYPED_ARRAY_UINT8C = 0
    JS_TYPED_ARRAY_INT8
    JS_TYPED_ARRAY_UINT8
    JS_TYPED_ARRAY_INT16
    JS_TYPED_ARRAY_UINT16
    JS_TYPED_ARRAY_INT32
    JS_TYPED_ARRAY_UINT32
    JS_TYPED_ARRAY_BIG_INT64
    JS_TYPED_ARRAY_BIG_UINT64
    JS_TYPED_ARRAY_FLOAT16
    JS_TYPED_ARRAY_FLOAT32
    JS_TYPED_ARRAY_FLOAT64
end enum

' ----------------------------
' Promise
' ----------------------------
enum JSPromiseStateEnum
    JS_PROMISE_PENDING
    JS_PROMISE_FULFILLED
    JS_PROMISE_REJECTED
end enum

enum JSPromiseHookType
    JS_PROMISE_HOOK_INIT
    JS_PROMISE_HOOK_BEFORE
    JS_PROMISE_HOOK_AFTER
    JS_PROMISE_HOOK_RESOLVE
end enum

type JSPromiseHook as sub cdecl(byval ctx as JSContext ptr, byval typ as JSPromiseHookType, byval promise as JSValueConst, byval parent_promise as JSValueConst, byval opaque as any ptr)
type JSHostPromiseRejectionTracker as sub cdecl(byval ctx as JSContext ptr, byval promise as JSValueConst, byval reason as JSValueConst, byval is_handled as boolean, byval opaque as any ptr)

' ----------------------------
' Interrupt & Module
' ----------------------------
type JSInterruptHandler as function cdecl(byval rt as JSRuntime ptr, byval opaque as any ptr) as integer

type JSModuleNormalizeFunc as function cdecl(byval ctx as JSContext ptr, byval module_base_name as zstring ptr, byval module_name as zstring ptr, byval opaque as any ptr) as zstring ptr
type JSModuleLoaderFunc as function cdecl(byval ctx as JSContext ptr, byval module_name as zstring ptr, byval opaque as any ptr) as JSModuleDef ptr

' ----------------------------
' Job
' ----------------------------
type JSJobFunc as function cdecl(byval ctx as JSContext ptr, byval argc as integer, byval argv as JSValueConst ptr) as JSValue

' ----------------------------
' SAB
' ----------------------------
type JSFreeArrayBufferDataFunc as sub cdecl(byval rt as JSRuntime ptr, byval opaque as any ptr, byval ptr as any ptr)

type JSSharedArrayBufferFunctions
    sab_alloc as function cdecl(byval opaque as any ptr, byval size as size_t) as any ptr
    sab_free as sub cdecl(byval opaque as any ptr, byval ptr as any ptr)
    sab_dup as sub cdecl(byval opaque as any ptr, byval ptr as any ptr)
    sab_opaque as any ptr
end type

type JSSABTab
    as ubyte ptr ptr tab
    as size_t len
end type

' ----------------------------
' C Function List Entry
' ----------------------------
enum JSCFunctionEnum
    JS_CFUNC_generic
    JS_CFUNC_generic_magic
    JS_CFUNC_constructor
    JS_CFUNC_constructor_magic
    JS_CFUNC_constructor_or_func
    JS_CFUNC_constructor_or_func_magic
    JS_CFUNC_f_f
    JS_CFUNC_f_f_f
    JS_CFUNC_getter
    JS_CFUNC_setter
    JS_CFUNC_getter_magic
    JS_CFUNC_setter_magic
    JS_CFUNC_iterator_next
end enum

union JSCFunctionType
    As JSCFunction generic
    as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval magic as integer) as JSValue generic_magic
    As JSCFunction Constructor
    as function cdecl(byval ctx as JSContext ptr, byval new_target as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval magic as integer) as JSValue constructor_magic
    as JSCFunction constructor_or_func
    as function cdecl(byval d as double) as double f_f
    As Function cdecl(ByVal d1 As Double, ByVal d2 As Double) As Double f_f_f
    as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst) as JSValue getter
    As Function cdecl(ByVal ctx As JSContext Ptr, ByVal this_val As JSValueConst, ByVal val_ As JSValueConst) As JSValue setter
    as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval magic as integer) as JSValue getter_magic
    as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval val_ as JSValueConst, byval magic as integer) as JSValue setter_magic
    as function cdecl(byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr, byval pdone as integer ptr, byval magic as integer) as JSValue iterator_next
end union

type JSCFunctionListEntry
    as zstring ptr name          '' const char *
    as ubyte       prop_flags
    as ubyte       def_type
    as short       magic         '' int16_t

    Union u
        '' --- variant 1: func ---
        Type   func
            As UByte              length
            as ubyte              cproto
            as JSCFunctionType    cfunc
        End Type 

        '' --- variant 2: getset ---
        Type   getset
            as JSCFunctionType    get
            as JSCFunctionType    set
        End Type 

        '' --- variant 3: alias ---
        Type   alias_
            As ZString Ptr        name_
            As Integer            base_
        End Type 

        '' --- variant 4: prop_list ---
        Type   prop_list
            as JSCFunctionListEntry ptr tab
            As Integer            Len
        End Type 

        '' --- scalar variants ---
        As ZString Ptr            str_
        as int32_t                i32
        as int64_t                i64
        as uint64_t               u64
        as double                 f64
    End Union 
end type

const JS_DEF_CFUNC          = 0
const JS_DEF_CGETSET        = 1
const JS_DEF_CGETSET_MAGIC  = 2
const JS_DEF_PROP_STRING    = 3
const JS_DEF_PROP_INT32     = 4
const JS_DEF_PROP_INT64     = 5
const JS_DEF_PROP_DOUBLE    = 6
const JS_DEF_PROP_UNDEFINED = 7
const JS_DEF_OBJECT         = 8
const JS_DEF_ALIAS          = 9

' ----------------------------
' Module init
' ----------------------------
type JSModuleInitFunc as function cdecl(byval ctx as JSContext ptr, byval m as JSModuleDef ptr) as integer

' ----------------------------
' Function declarations (all extern "C" cdecl)
' ----------------------------
declare function JS_NewRuntime  () as JSRuntime ptr
Declare Sub JS_SetRuntimeInfo  (ByVal rt As JSRuntime Ptr, ByVal info As ZString Ptr)
declare sub JS_SetMemoryLimit  (byval rt as JSRuntime ptr, byval limit as size_t)
declare sub JS_SetDumpFlags  (byval rt as JSRuntime ptr, byval flags as uint64_t)
declare function JS_GetDumpFlags  (byval rt as JSRuntime ptr) as uint64_t
declare function JS_GetGCThreshold  (byval rt as JSRuntime ptr) as size_t
declare sub JS_SetGCThreshold  (byval rt as JSRuntime ptr, byval gc_threshold as size_t)
declare sub JS_SetMaxStackSize  (byval rt as JSRuntime ptr, byval stack_size as size_t)
declare sub JS_UpdateStackTop  (byval rt as JSRuntime ptr)
declare function JS_NewRuntime2  (byval mf as JSMallocFunctions ptr, byval opaque as any ptr) as JSRuntime ptr
declare sub JS_FreeRuntime  (byval rt as JSRuntime ptr)
declare function JS_GetRuntimeOpaque  (byval rt as JSRuntime ptr) as any ptr
declare sub JS_SetRuntimeOpaque  (byval rt as JSRuntime ptr, byval opaque as any ptr)
declare function JS_AddRuntimeFinalizer  (byval rt as JSRuntime ptr, byval finalizer as JSRuntimeFinalizer ptr, byval arg as any ptr) as integer
declare sub JS_MarkValue  (byval rt as JSRuntime ptr, byval val_ as JSValueConst, byval mark_func as JS_MarkFunc ptr)
declare sub JS_RunGC  (byval rt as JSRuntime ptr)
declare function JS_IsLiveObject  (byval rt as JSRuntime ptr, byval obj as JSValueConst) as boolean

declare function JS_NewContext  (byval rt as JSRuntime ptr) as JSContext ptr
Declare Sub JS_FreeContext  (ByVal s As JSContext Ptr)
declare function JS_DupContext  (byval ctx as JSContext ptr) as JSContext ptr
declare function JS_GetContextOpaque  (byval ctx as JSContext ptr) as any ptr
declare sub JS_SetContextOpaque  (byval ctx as JSContext ptr, byval opaque as any ptr)
declare function JS_GetRuntime  (byval ctx as JSContext ptr) as JSRuntime ptr
declare sub JS_SetClassProto  (byval ctx as JSContext ptr, byval class_id as JSClassID, byval obj as JSValue)
declare function JS_GetClassProto  (byval ctx as JSContext ptr, byval class_id as JSClassID) as JSValue
declare function JS_GetFunctionProto  (byval ctx as JSContext ptr) as JSValue

declare function JS_NewContextRaw  (byval rt as JSRuntime ptr) as JSContext ptr
declare sub JS_AddIntrinsicBaseObjects  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicDate  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicEval  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicRegExpCompiler  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicRegExp  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicJSON  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicProxy  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicMapSet  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicTypedArrays  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicPromise  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicBigInt  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicWeakRef  (byval ctx as JSContext ptr)
declare sub JS_AddPerformance  (byval ctx as JSContext ptr)
declare sub JS_AddIntrinsicDOMException  (byval ctx as JSContext ptr)

declare function JS_IsEqual  (byval ctx as JSContext ptr, byval op1 as JSValueConst, byval op2 as JSValueConst) as integer
declare function JS_IsStrictEqual  (byval ctx as JSContext ptr, byval op1 as JSValueConst, byval op2 as JSValueConst) as boolean
declare function JS_IsSameValue  (byval ctx as JSContext ptr, byval op1 as JSValueConst, byval op2 as JSValueConst) as boolean
declare function JS_IsSameValueZero  (byval ctx as JSContext ptr, byval op1 as JSValueConst, byval op2 as JSValueConst) as boolean

declare function js_string_codePointRange  (byval ctx as JSContext ptr, byval this_val as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr) as JSValue

' Memory allocation
declare function js_calloc_rt  (byval rt as JSRuntime ptr, byval count as size_t, byval size as size_t) as any ptr
declare function js_malloc_rt  (byval rt as JSRuntime ptr, byval size as size_t) as any ptr
declare sub js_free_rt  (byval rt as JSRuntime ptr, byval ptr as any ptr)
declare function js_realloc_rt  (byval rt as JSRuntime ptr, byval ptr as any ptr, byval size as size_t) as any ptr
declare function js_malloc_usable_size_rt  (byval rt as JSRuntime ptr, byval ptr as any ptr) as size_t
declare function js_mallocz_rt  (byval rt as JSRuntime ptr, byval size as size_t) as any ptr

declare function js_calloc  (byval ctx as JSContext ptr, byval count as size_t, byval size as size_t) as any ptr
declare function js_malloc  (byval ctx as JSContext ptr, byval size as size_t) as any ptr
declare sub js_free  (byval ctx as JSContext ptr, byval ptr as any ptr)
declare function js_realloc  (byval ctx as JSContext ptr, byval ptr as any ptr, byval size as size_t) as any ptr
declare function js_malloc_usable_size  (byval ctx as JSContext ptr, byval ptr as any ptr) as size_t
declare function js_realloc2  (byval ctx as JSContext ptr, byval ptr as any ptr, byval size as size_t, byval pslack as size_t ptr) as any ptr
declare function js_mallocz  (byval ctx as JSContext ptr, byval size as size_t) as any ptr
declare function js_strdup  (byval ctx as JSContext ptr, byval str as zstring ptr) as zstring ptr
declare function js_strndup  (byval ctx as JSContext ptr, byval s as zstring ptr, byval n as size_t) as zstring ptr

declare sub JS_ComputeMemoryUsage  (byval rt as JSRuntime ptr, byval s as JSMemoryUsage ptr)
declare sub JS_DumpMemoryUsage  (byval fp as FILE ptr, byval s as JSMemoryUsage ptr, byval rt as JSRuntime ptr)

' Atom functions
declare function JS_NewAtomLen  (byval ctx as JSContext ptr, byval str as zstring ptr, byval len as size_t) as JSAtom
declare function JS_NewAtom  (byval ctx as JSContext ptr, byval str as zstring ptr) as JSAtom
declare function JS_NewAtomUInt32  (byval ctx as JSContext ptr, byval n as uint32_t) as JSAtom
declare function JS_DupAtom  (byval ctx as JSContext ptr, byval v as JSAtom) as JSAtom
declare sub JS_FreeAtom  (byval ctx as JSContext ptr, byval v as JSAtom)
declare sub JS_FreeAtomRT  (byval rt as JSRuntime ptr, byval v as JSAtom)
declare function JS_AtomToValue  (byval ctx as JSContext ptr, byval atom as JSAtom) as JSValue
declare function JS_AtomToString  (byval ctx as JSContext ptr, byval atom as JSAtom) as JSValue
declare function JS_AtomToCStringLen  (byval ctx as JSContext ptr, byval plen as size_t ptr, byval atom as JSAtom) as zstring ptr
Declare Function JS_ValueToAtom  (ByVal ctx As JSContext Ptr, ByVal val_ As JSValueConst) As JSAtom

' Class functions
declare function JS_NewClassID  (byval rt as JSRuntime ptr, byval pclass_id as JSClassID ptr) as JSClassID
Declare Function JS_GetClassID  (ByVal v As JSValueConst) As JSClassID
declare function JS_NewClass  (byval rt as JSRuntime ptr, byval class_id as JSClassID, byval class_def as JSClassDef ptr) as integer
declare function JS_IsRegisteredClass  (byval rt as JSRuntime ptr, byval class_id as JSClassID) as boolean
Declare Function JS_NewNumber  (ByVal ctx As JSContext Ptr, ByVal d As Double) As jsValue
Declare Function JS_NewBigInt64  (ByVal ctx As JSContext Ptr, ByVal v As int64_t) As JSValue
Declare Function JS_NewBigUint64  (ByVal ctx As JSContext Ptr, ByVal v As uint64_t) As JSValue
' Value creation (inline in C, we provide as functions)
Function JS_NewBool(ByVal ctx As JSContext Ptr, ByVal val_ As Boolean) As JSValue
    Return JS_MKVAL(JS_TAG_BOOL, IIf(val_, 1, 0))
end function

Function JS_NewInt32(ByVal ctx As JSContext Ptr, ByVal val_ As int32_t) As JSValue
    Return JS_MKVAL(JS_TAG_INT, val_)
end function

Function JS_NewCatchOffset(ByVal ctx As JSContext Ptr, ByVal val_ As int32_t) As JSValue
    return JS_MKVAL(JS_TAG_CATCH_OFFSET, val_)
End Function

Function JS_NewInt64(ByVal ctx As JSContext Ptr, ByVal val_ As int64_t) As JSValue
    If (val_ >= -2147483648ll And val_ <= 2147483647ll) Then
        Return JS_NewInt32(ctx, val_)
    Else
        Return JS_NewFloat64(ctx, val_)
    end if
End Function

Function JS_NewUint32(ByVal ctx As JSContext Ptr, ByVal val_ As uint32_t) As JSValue
    If (val_ <= 2147483647ul) Then
        Return JS_NewInt32(ctx, val_)
    Else
        Return JS_NewFloat64(ctx, val_)
    end if
End Function

' Type checks
function JS_IsNumber(byval v as JSValueConst) as boolean
    dim as integer tag = JS_VALUE_GET_TAG(v)
    return (tag = JS_TAG_INT) or JS_TAG_IS_FLOAT64(tag)
end function

function JS_IsBigInt(byval v as JSValueConst) as boolean
    dim as integer tag = JS_VALUE_GET_TAG(v)
    return (tag = JS_TAG_BIG_INT) or (tag = JS_TAG_SHORT_BIG_INT)
end function

function JS_IsBool(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_BOOL
end function

function JS_IsNull(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_NULL
end function

function JS_IsUndefined(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_UNDEFINED
end function

function JS_IsException(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_EXCEPTION
end function

function JS_IsUninitialized(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_UNINITIALIZED
end function

function JS_IsString(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_STRING
end function

function JS_IsSymbol(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_SYMBOL
end function

function JS_IsObject(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_OBJECT
end function

function JS_IsModule(byval v as JSValueConst) as boolean
    return JS_VALUE_GET_TAG(v) = JS_TAG_MODULE
end function

' Exception
declare function JS_Throw  (byval ctx as JSContext ptr, byval obj as JSValue) as JSValue
declare function JS_GetException  (byval ctx as JSContext ptr) as JSValue
Declare Function JS_HasException  (ByVal ctx As JSContext Ptr) As Boolean
declare function JS_IsError  (byval val_ as JSValueConst) as boolean
declare function JS_IsUncatchableError  (byval val_ as JSValueConst) as boolean
Declare Sub JS_SetUncatchableError  (ByVal ctx As JSContext Ptr, byval val_ as JSValueConst)
declare sub JS_ClearUncatchableError  (byval ctx as JSContext ptr, byval val_ as JSValueConst)
declare sub JS_ResetUncatchableError  (byval ctx as JSContext ptr)
declare function JS_NewError  (byval ctx as JSContext ptr) as JSValue
declare function JS_NewInternalError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_NewPlainError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_NewRangeError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_NewReferenceError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_NewSyntaxError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_NewTypeError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowInternalError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowPlainError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowRangeError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowReferenceError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowSyntaxError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowTypeError  (byval ctx as JSContext ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowDOMException  (byval ctx as JSContext ptr, byval name as zstring ptr, byval fmt as zstring ptr, ...) as JSValue
declare function JS_ThrowOutOfMemory  (byval ctx as JSContext ptr) as JSValue

' Memory management
declare sub JS_FreeValue  (byval ctx as JSContext ptr, byval v as JSValue)
declare sub JS_FreeValueRT  (byval rt as JSRuntime ptr, byval v as JSValue)
declare function JS_DupValue  (byval ctx as JSContext ptr, byval v as JSValueConst) as JSValue
declare function JS_DupValueRT  (byval rt as JSRuntime ptr, byval v as JSValueConst) as JSValue

' Conversion
declare function JS_ToBool  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as integer
declare function JS_ToNumber  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_ToInt32  (byval ctx as JSContext ptr, byval pres as int32_t ptr, byval val_ as JSValueConst) as integer
Declare Function JS_ToUint32  (ByVal ctx As JSContext Ptr, ByVal pres As uint32_t Ptr, ByVal val_ As JSValueConst) As Integer
declare function JS_ToInt64  (byval ctx as JSContext ptr, byval pres as int64_t ptr, byval val_ as JSValueConst) as integer
declare function JS_ToIndex  (byval ctx as JSContext ptr, byval plen as uint64_t ptr, byval val_ as JSValueConst) as integer
declare function JS_ToFloat64  (byval ctx as JSContext ptr, byval pres as double ptr, byval val_ as JSValueConst) as integer
declare function JS_ToBigInt64  (byval ctx as JSContext ptr, byval pres as int64_t ptr, byval val_ as JSValueConst) as integer
declare function JS_ToBigUint64  (byval ctx as JSContext ptr, byval pres as uint64_t ptr, byval val_ as JSValueConst) as integer
declare function JS_ToInt64Ext  (byval ctx as JSContext ptr, byval pres as int64_t ptr, byval val_ as JSValueConst) as integer

declare function JS_NewStringLen  (byval ctx as JSContext ptr, byval str1 as zstring ptr, byval len1 as size_t) as JSValue
Function JS_NewString(ByVal ctx As JSContext Ptr, ByVal xstr As ZString Ptr) As JSValue
    Return JS_NewStringLen(ctx, xstr, Len(xstr))
end function

declare function JS_NewTwoByteString  (byval ctx as JSContext ptr, byval buf as ushort ptr, byval len as size_t) as JSValue
declare function JS_NewAtomString  (byval ctx as JSContext ptr, byval str as zstring ptr) as JSValue
declare function JS_ToString  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_ToPropertyKey  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_ToCStringLen2  (byval ctx as JSContext ptr, byval plen as size_t ptr, byval val1 as JSValueConst, byval cesu8 as boolean) as zstring ptr
function JS_ToCStringLen(byval ctx as JSContext ptr, byval plen as size_t ptr, byval val1 as JSValueConst) as zstring ptr
    return JS_ToCStringLen2(ctx, plen, val1, 0)
end function
function JS_ToCString(byval ctx as JSContext ptr, byval val1 as JSValueConst) as zstring ptr
    return JS_ToCStringLen2(ctx, 0, val1, 0)
End Function
Declare Sub JS_FreeCString  (ByVal ctx As JSContext Ptr, ByVal PTR_ As ZString Ptr)

' Object creation
declare function JS_NewObjectProtoClass  (byval ctx as JSContext ptr, byval proto as JSValueConst, byval class_id as JSClassID) as JSValue
declare function JS_NewObjectClass  (byval ctx as JSContext ptr, byval class_id as JSClassID) as JSValue
declare function JS_NewObjectProto  (byval ctx as JSContext ptr, byval proto as JSValueConst) as JSValue
declare function JS_NewObject  (byval ctx as JSContext ptr) as JSValue
declare function JS_NewObjectFrom  (byval ctx as JSContext ptr, byval count as integer, byval props as JSAtom ptr, byval values as JSValue ptr) as JSValue
declare function JS_NewObjectFromStr  (byval ctx as JSContext ptr, byval count as integer, byval props as zstring ptr ptr, byval values as JSValue ptr) as JSValue
declare function JS_ToObject  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_ToObjectString  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_IsFunction  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as boolean
declare function JS_IsConstructor  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as boolean
declare function JS_SetConstructorBit  (byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval val_ as boolean) as boolean
declare function JS_IsRegExp  (byval val_ as JSValueConst) as boolean
declare function JS_IsMap  (byval val_ as JSValueConst) as boolean
declare function JS_IsSet  (byval val_ as JSValueConst) as boolean
declare function JS_IsWeakRef  (byval val_ as JSValueConst) as boolean
declare function JS_IsWeakSet  (byval val_ as JSValueConst) as boolean
declare function JS_IsWeakMap  (byval val_ as JSValueConst) as boolean
declare function JS_IsDataView  (byval val_ as JSValueConst) as boolean
declare function JS_NewArray  (byval ctx as JSContext ptr) as JSValue
declare function JS_NewArrayFrom  (byval ctx as JSContext ptr, byval count as integer, byval values as JSValue ptr) as JSValue
declare function JS_IsArray  (byval val_ as JSValueConst) as boolean
declare function JS_IsProxy  (byval val_ as JSValueConst) as boolean
declare function JS_GetProxyTarget  (byval ctx as JSContext ptr, byval proxy as JSValueConst) as JSValue
declare function JS_GetProxyHandler  (byval ctx as JSContext ptr, byval proxy as JSValueConst) as JSValue
declare function JS_NewDate  (byval ctx as JSContext ptr, byval epoch_ms as double) as JSValue
declare function JS_IsDate  (byval v as JSValueConst) as boolean

' Property access
declare function JS_GetProperty  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom) as JSValue
declare function JS_GetPropertyUint32  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval idx as uint32_t) as JSValue
declare function JS_GetPropertyInt66  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval idx as int64_t) as JSValue
declare function JS_GetPropertyStr  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as zstring ptr) as JSValue
declare function JS_SetProperty  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom, byval val_ as JSValue) as integer
declare function JS_SetPropertyUint32  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval idx as uint32_t, byval val_ as JSValue) as integer
declare function JS_SetPropertyInt64  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval idx as int64_t, byval val_ as JSValue) as integer
declare function JS_SetPropertyStr  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as zstring ptr, byval val_ as JSValue) as integer
declare function JS_HasProperty  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom) as integer
declare function JS_IsExtensible  (byval ctx as JSContext ptr, byval obj as JSValueConst) as integer
declare function JS_PreventExtensions  (byval ctx as JSContext ptr, byval obj as JSValueConst) as integer
declare function JS_DeleteProperty  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval prop as JSAtom, byval flags as integer) as integer
declare function JS_SetPrototype  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval proto_val as JSValueConst) as integer
declare function JS_GetPrototype  (byval ctx as JSContext ptr, byval val_ as JSValueConst) as JSValue
declare function JS_GetLength  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval pres as int64_t ptr) as integer
declare function JS_SetLength  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval len as int64_t) as integer
declare function JS_SealObject  (byval ctx as JSContext ptr, byval obj as JSValueConst) as integer
declare function JS_FreezeObject  (byval ctx as JSContext ptr, byval obj as JSValueConst) as integer

const JS_GPN_STRING_MASK  = 1 shl 0
const JS_GPN_SYMBOL_MASK  = 1 shl 1
const JS_GPN_PRIVATE_MASK = 1 shl 2
const JS_GPN_ENUM_ONLY    = 1 shl 4
const JS_GPN_SET_ENUM     = 1 shl 5

declare function JS_GetOwnPropertyNames  (byval ctx as JSContext ptr, byval ptab as JSPropertyEnum ptr ptr, byval plen as uint32_t ptr, byval obj as JSValueConst, byval flags as integer) as integer
declare function JS_GetOwnProperty  (byval ctx as JSContext ptr, byval desc as JSPropertyDescriptor ptr, byval obj as JSValueConst, byval prop as JSAtom) as integer
declare sub JS_FreePropertyEnum  (byval ctx as JSContext ptr, byval tab as JSPropertyEnum ptr, byval len as uint32_t)

' Function call
declare function JS_Call  (byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval this_obj as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr) as JSValue
declare function JS_Invoke  (byval ctx as JSContext ptr, byval this_val as JSValueConst, byval atom as JSAtom, byval argc as integer, byval argv as JSValueConst ptr) as JSValue
declare function JS_CallConstructor  (byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr) as JSValue
declare function JS_CallConstructor2  (byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval new_target as JSValueConst, byval argc as integer, byval argv as JSValueConst ptr) as JSValue

' Eval
declare function JS_DetectModule  (byval input as zstring ptr, byval input_len as size_t) as boolean
declare function JS_Eval  (byval ctx as JSContext ptr, byval input as zstring ptr, byval input_len as size_t, byval filename as zstring ptr, byval eval_flags as integer) as JSValue
declare function JS_Eval2  (byval ctx as JSContext ptr, byval input as zstring ptr, byval input_len as size_t, byval options as JSEvalOptions ptr) as JSValue
declare function JS_EvalThis  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval input as zstring ptr, byval input_len as size_t, byval filename as zstring ptr, byval eval_flags as integer) as JSValue
declare function JS_EvalThis2  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval input as zstring ptr, byval input_len as size_t, byval options as JSEvalOptions ptr) as JSValue

' Global
declare function JS_GetGlobalObject  (byval ctx as JSContext ptr) as JSValue
declare function JS_IsInstanceOf  (byval ctx as JSContext ptr, byval val_ as JSValueConst, byval obj as JSValueConst) as integer

' Define property
declare function JS_DefineProperty  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom, byval val_ as JSValueConst, byval getter as JSValueConst, byval setter as JSValueConst, byval flags as integer) as integer
declare function JS_DefinePropertyValue  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom, byval val_ as JSValue, byval flags as integer) as integer
declare function JS_DefinePropertyValueUint32  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval idx as uint32_t, byval val_ as JSValue, byval flags as integer) as integer
declare function JS_DefinePropertyValueStr  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as zstring ptr, byval val_ as JSValue, byval flags as integer) as integer
declare function JS_DefinePropertyGetSet  (byval ctx as JSContext ptr, byval this_obj as JSValueConst, byval prop as JSAtom, byval getter as JSValue, byval setter as JSValue, byval flags as integer) as integer

' Opaque
declare function JS_SetOpaque  (byval obj as JSValueConst, byval opaque as any ptr) as integer
declare function JS_GetOpaque  (byval obj as JSValueConst, byval class_id as JSClassID) as any ptr
declare function JS_GetOpaque2  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval class_id as JSClassID) as any ptr
declare function JS_GetAnyOpaque  (byval obj as JSValueConst, byval class_id as JSClassID ptr) as any ptr

' JSON
declare function JS_ParseJSON  (byval ctx as JSContext ptr, byval buf as zstring ptr, byval buf_len as size_t, byval filename as zstring ptr) as JSValue
declare function JS_JSONStringify  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval replacer as JSValueConst, byval space0 as JSValueConst) as JSValue

' ArrayBuffer
declare function JS_NewArrayBuffer  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval len as size_t, byval free_func as JSFreeArrayBufferDataFunc ptr, byval opaque as any ptr, byval is_shared as boolean) as JSValue
declare function JS_NewArrayBufferCopy  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval len as size_t) as JSValue
declare sub JS_DetachArrayBuffer  (byval ctx as JSContext ptr, byval obj as JSValueConst)
declare function JS_GetArrayBuffer  (byval ctx as JSContext ptr, byval psize as size_t ptr, byval obj as JSValueConst) as ubyte ptr
declare function JS_IsArrayBuffer  (byval obj as JSValueConst) as boolean
declare function JS_GetUint8Array  (byval ctx as JSContext ptr, byval psize as size_t ptr, byval obj as JSValueConst) as ubyte ptr

' TypedArray
declare function JS_NewTypedArray  (byval ctx as JSContext ptr, byval argc as integer, byval argv as JSValueConst ptr, byval array_type as JSTypedArrayEnum) as JSValue
declare function JS_GetTypedArrayBuffer  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval pbyte_offset as size_t ptr, byval pbyte_length as size_t ptr, byval pbytes_per_element as size_t ptr) as JSValue
declare function JS_NewUint8Array  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval len as size_t, byval free_func as JSFreeArrayBufferDataFunc ptr, byval opaque as any ptr, byval is_shared as boolean) as JSValue
declare function JS_GetTypedArrayType  (byval obj as JSValueConst) as integer
declare function JS_NewUint8ArrayCopy  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval len as size_t) as JSValue

' SharedArrayBuffer
declare sub JS_SetSharedArrayBufferFunctions  (byval rt as JSRuntime ptr, byval sf as JSSharedArrayBufferFunctions ptr)

' Promise
declare function JS_NewPromiseCapability  (byval ctx as JSContext ptr, byval resolving_funcs as JSValue ptr) as JSValue
declare function JS_PromiseState  (byval ctx as JSContext ptr, byval promise as JSValueConst) as JSPromiseStateEnum
declare function JS_PromiseResult  (byval ctx as JSContext ptr, byval promise as JSValueConst) as JSValue
declare function JS_IsPromise  (byval val_ as JSValueConst) as boolean
declare function JS_NewSymbol  (byval ctx as JSContext ptr, byval description as zstring ptr, byval is_global as boolean) as JSValue

declare sub JS_SetPromiseHook  (byval rt as JSRuntime ptr, byval promise_hook as JSPromiseHook ptr, byval opaque as any ptr)
declare sub JS_SetHostPromiseRejectionTracker  (byval rt as JSRuntime ptr, byval cb as JSHostPromiseRejectionTracker ptr, byval opaque as any ptr)

' Interrupt
declare sub JS_SetInterruptHandler  (byval rt as JSRuntime ptr, byval cb as JSInterruptHandler ptr, byval opaque as any ptr)
declare sub JS_SetCanBlock  (byval rt as JSRuntime ptr, byval can_block as boolean)
declare sub JS_SetIsHTMLDDA  (byval ctx as JSContext ptr, byval obj as JSValueConst)

' Module loader
declare sub JS_SetModuleLoaderFunc  (byval rt as JSRuntime ptr, byval module_normalize as JSModuleNormalizeFunc ptr, byval module_loader as JSModuleLoaderFunc ptr, byval opaque as any ptr)
declare function JS_GetImportMeta  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr) as JSValue
declare function JS_GetModuleName  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr) as JSAtom
declare function JS_GetModuleNamespace  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr) as JSValue

' Job
declare function JS_EnqueueJob  (byval ctx as JSContext ptr, byval job_func as JSJobFunc ptr, byval argc as integer, byval argv as JSValueConst ptr) as integer
declare function JS_IsJobPending  (byval rt as JSRuntime ptr) as boolean
declare function JS_ExecutePendingJob  (byval rt as JSRuntime ptr, byval pctx as JSContext ptr ptr) as integer

' Object writer/reader
const JS_WRITE_OBJ_BYTECODE       = 1 shl 0
const JS_WRITE_OBJ_SAB            = 1 shl 2
const JS_WRITE_OBJ_REFERENCE      = 1 shl 3
const JS_WRITE_OBJ_STRIP_SOURCE   = 1 shl 4
const JS_WRITE_OBJ_STRIP_DEBUG    = 1 shl 5

declare function JS_WriteObject  (byval ctx as JSContext ptr, byval psize as size_t ptr, byval obj as JSValueConst, byval flags as integer) as ubyte ptr
declare function JS_WriteObject2  (byval ctx as JSContext ptr, byval psize as size_t ptr, byval obj as JSValueConst, byval flags as integer, byval psab_tab as JSSABTab ptr) as ubyte ptr

const JS_READ_OBJ_BYTECODE  = 1 shl 0
const JS_READ_OBJ_SAB       = 1 shl 2
const JS_READ_OBJ_REFERENCE = 1 shl 3

declare function JS_ReadObject  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval buf_len as size_t, byval flags as integer) as JSValue
declare function JS_ReadObject2  (byval ctx as JSContext ptr, byval buf as ubyte ptr, byval buf_len as size_t, byval flags as integer, byval psab_tab as JSSABTab ptr) as JSValue
declare function JS_EvalFunction  (byval ctx as JSContext ptr, byval fun_obj as JSValue) as JSValue
declare function JS_ResolveModule  (byval ctx as JSContext ptr, byval obj as JSValueConst) as integer

' Script/module name
declare function JS_GetScriptOrModuleName  (byval ctx as JSContext ptr, byval n_stack_levels as integer) as JSAtom
declare function JS_LoadModule  (byval ctx as JSContext ptr, byval basename as zstring ptr, byval filename as zstring ptr) as JSValue

' C function
declare function JS_NewCFunction2  (byval ctx as JSContext ptr, byval func as JSCFunction ptr, byval name as zstring ptr, byval length as integer, byval cproto as JSCFunctionEnum, byval magic as integer) as JSValue
declare function JS_NewCFunction3  (byval ctx as JSContext ptr, byval func as JSCFunction ptr, byval name as zstring ptr, byval length as integer, byval cproto as JSCFunctionEnum, byval magic as integer, byval proto_val as JSValueConst) as JSValue
declare function JS_NewCFunctionData  (byval ctx as JSContext ptr, byval func as JSCFunctionData ptr, byval length as integer, byval magic as integer, byval data_len as integer, byval data as JSValueConst ptr) as JSValue
declare function JS_NewCFunctionData2  (byval ctx as JSContext ptr, byval func as JSCFunctionData ptr, byval name as zstring ptr, byval length as integer, byval magic as integer, byval data_len as integer, byval data as JSValueConst ptr) as JSValue

declare sub JS_SetConstructor  (byval ctx as JSContext ptr, byval func_obj as JSValueConst, byval proto as JSValueConst)

' Property list
declare function JS_SetPropertyFunctionList  (byval ctx as JSContext ptr, byval obj as JSValueConst, byval tab as JSCFunctionListEntry ptr, byval len as integer) as integer

' Module
declare function JS_NewCModule  (byval ctx as JSContext ptr, byval name_str as zstring ptr, byval func as JSModuleInitFunc ptr) as JSModuleDef ptr
declare function JS_AddModuleExport  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr, byval name_str as zstring ptr) as integer
declare function JS_AddModuleExportList  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr, byval tab as JSCFunctionListEntry ptr, byval len as integer) as integer
declare function JS_SetModuleExport  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr, byval export_name as zstring ptr, byval val_ as JSValue) as integer
declare function JS_SetModuleExportList  (byval ctx as JSContext ptr, byval m as JSModuleDef ptr, byval tab as JSCFunctionListEntry ptr, byval len as integer) as integer

' Version
const QJS_VERSION_MAJOR = 0
const QJS_VERSION_MINOR = 11
const QJS_VERSION_PATCH = 0
const QJS_VERSION_SUFFIX = ""
declare function JS_GetVersion  () as zstring ptr

' Internal
declare function js_std_cmd  (byval cmd as uintptr_t, ...) as uintptr_t

end extern

#endif ' __QUICKJS_BI__