#include once "include/quickjs.bi"
#ifndef __FB_64BIT__
#libpath "win32"
#else
#libpath "win64"
#endif

Dim As JSRuntime Ptr rt = JS_NewRuntime()
dim as JSContext ptr ctx = JS_NewContext(rt)

' 定义函数并显式赋值到全局
dim as JSValue r = JS_Eval(ctx, "globalThis.myfunc = function(x) { return x * 2; };", 50, "", JS_EVAL_TYPE_GLOBAL)
if JS_IsException(r) then
    Dim As ZString Ptr err_ = JS_ToCString(ctx, r)
    Print "Eval error: "; *err_
    JS_FreeCString(ctx, err_)
    Goto end_test
end if
JS_FreeValue(ctx, r)

dim as JSValue glob = JS_GetGlobalObject(ctx)
dim as JSValue func = JS_GetPropertyStr(ctx, glob, "myfunc")

if JS_IsFunction(ctx, func) then
    Print "Function 'myfunc' found!"
    
    dim as JSValue arg = JS_NewInt32(ctx, 5)
    dim as JSValue res = JS_Call(ctx, func, glob, 1, @arg)
    
    if not JS_IsException(res) then
        dim as zstring ptr s = JS_ToCString(ctx, res)
        print "myfunc(5) = "; *s
        JS_FreeCString(ctx, s)
    End If
    
    JS_FreeValue(ctx, res)
    JS_FreeValue(ctx, arg)
else
    Print "Function 'myfunc' NOT found!"
    ' 列出全局属性
    Dim As JSPropertyEnum Ptr Tab_
    Dim As uint32_t len_
    If JS_GetOwnPropertyNames(ctx, @Tab_, @len_, glob, JS_GPN_STRING_MASK) = 0 Then
        For i As uint32_t = 0 To len_-1
            Dim As ZString Ptr n = JS_AtomToCStringLen(ctx, 0, Tab_[i].atom)
            print "  global."; iif(n, *n, "?")
            JS_FreeCString(ctx, n)
        next
        JS_FreePropertyEnum(ctx, Tab_, len_)
    end if
end if

JS_FreeValue(ctx, func)
JS_FreeValue(ctx, glob)

end_test:
JS_FreeContext(ctx)
JS_FreeRuntime(rt)
print "Done."
sleep