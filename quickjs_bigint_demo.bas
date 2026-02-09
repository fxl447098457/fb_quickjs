#include once "include/quickjs.bi"
#ifndef __FB_64BIT__
#libpath "win32"
#else
#libpath "win64"
#endif

' === 安全转换：JSValue → String ===
function JSValueToString(byval ctx as JSContext ptr, byval v as JSValue) as string
    If JS_IsException(v) Then Return "[EXCEPTION]"
    Dim As  ZString Ptr cstr = JS_ToCString(ctx, v)
    If cstr = NULL Then
        JS_FreeValue(ctx, v)
        Return "[NULL]"
    end if
    dim as string result = *cstr
    JS_FreeCString(ctx, cstr)
    JS_FreeValue(ctx, v)
    return result
end function

' === 创建 BigInt（从字符串）===
function NewBigInt(byval ctx as JSContext ptr, byval num_str as string) as JSValue
    dim as string code = num_str & "n"  ' 添加 BigInt 后缀
    return JS_Eval(ctx, strptr(code), len(code), @"bigint", 0)
end function

' === 创建函数对象 ===
function CreateFunction(byval ctx as JSContext ptr, byval func_body as string) as JSValue
    ' 包装为函数表达式：(function(a, b) { return arguments[0] + arguments[1]; })
    dim as string wrapper = "(function() { " & func_body & " })"
    return JS_Eval(ctx, strptr(wrapper), len(wrapper), @"function", 0)
end function

' === 演示：使用 arguments 传递参数 ===
sub ArgumentsDemo(byval ctx as JSContext ptr)
    print "=== 使用 arguments 传递参数==="
    print
    
    ' 1. 创建两个 BigInt 变量
    Dim As JSValue a = NewBigInt(ctx, "123456789012345678901234567890")
    Dim As JSValue b = NewBigInt(ctx, "987654321098765432109876543210")
    Dim As String func_code = "(function() { return arguments[0] + arguments[1]; })"
    ' 2. 创建函数对象：使用 arguments[0] + arguments[1]
    ' 注意：必须用括号包裹函数表达式，使 eval 返回函数对象而非执行结果
    Dim As JSValue func = JS_Eval(ctx,StrPtr(func_code),len(func_code), @"func_add", 0)
    
    ' 3. 准备参数数组（必须是连续内存）
    dim as JSValue args(1)
    args(0) = a
    args(1) = b
    
    ' 4. 调用函数（关键：使用 JS_Call 传入参数）
    dim as JSValue result = JS_Call(ctx, func, JS_UNDEFINED, 2, @args(0))
    
    print "a = 123456789012345678901234567890"
    print "b = 987654321098765432109876543210"
    print "a + b = "; JSValueToString(ctx, result)
    
    ' 5. 清理函数对象（a/b 已在 JSValueToString 中释放）
    JS_FreeValue(ctx, func)
    
    print
end sub

' === 演示：通用二元运算（支持 +, -, *, /）===
sub BinaryOpDemo(byval ctx as JSContext ptr, byval op as string)
    print "=== 二元运算：arguments[0] "; op; " arguments[1] ==="
    
    dim as JSValue x = NewBigInt(ctx, "999999999999999999999999999999")
    dim as JSValue y = NewBigInt(ctx, "888888888888888888888888888888")
    
    ' 动态创建运算函数
    Dim As String func_code = "(function() { return arguments[0] " & op & " arguments[1]; })"
    Dim As JSValue func = JS_Eval(ctx, StrPtr(func_code), len(func_code), @"func_op", 0)
    
    dim as JSValue args(1) = {x, y}
    Dim As JSValue res = JS_Call(ctx, func, JS_UNDEFINED, 2, @args(0))
    
    print "x = 999...999 (30位)"
    print "y = 888...888 (30位)"
    print "x "; op; " y = "; left(JSValueToString(ctx, res), 60); "..."
    
    JS_FreeValue(ctx, func)
    print
end sub

' === 演示：阶乘函数（带单个参数）===
sub FactorialDemo(byval ctx as JSContext ptr, byval n as ulong)
    print "=== 阶乘函数：arguments[0]! ==="
    
    ' 创建阶乘函数
    dim as string fact_func = _
        "(function() {" & _
        "  let n = arguments[0];" & _
        "  let r = 1n;" & _
        "  for (let i = 2n; i <= n; i++) r *= i;" & _
        "  return r;" & _
        "})"
    
    dim as JSValue func = JS_Eval(ctx, strptr(fact_func), len(fact_func), @"fact_func", 0)
    
    ' 创建参数：100n
    dim as JSValue arg = NewBigInt(ctx, str(n))
    dim as JSValue args(0) = {arg}
    
    dim as JSValue res = JS_Call(ctx, func, JS_UNDEFINED, 1, @args(0))
    dim as string s = JSValueToString(ctx, res)
    
    print n; "! 位数: "; len(s)
    print "前50位: "; left(s, 50)
    
    JS_FreeValue(ctx, func)
    print
end sub

' === 主程序 ===
sub main()
    print "FreeBasic + QuickJS BigInt 函数调用演示"
    print string(60, "=")
    print
    
    dim as JSRuntime ptr rt = JS_NewRuntime()
    if rt = NULL then print "错误: JS_NewRuntime 失败": return
    dim as JSContext ptr ctx = JS_NewContext(rt)
    if ctx = NULL then print "错误: JS_NewContext 失败": JS_FreeRuntime(rt): return
    
    ' 演示1：基础加法
    ArgumentsDemo(ctx)
    
    ' 演示2：多种运算
    BinaryOpDemo(ctx, "+")
    BinaryOpDemo(ctx, "*")
    
    ' 演示3：阶乘
    FactorialDemo(ctx, 100)
    
    ' 清理
    JS_FreeContext(ctx)
    JS_FreeRuntime(rt)
    
    print string(60, "=")
    print "完成！按任意键退出..."
    sleep
end sub

main()