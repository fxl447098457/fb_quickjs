#include once "include/quickjs.bi"
#ifndef __FB_64BIT__
#libpath "win32"
#else
#libpath "win64"
#endif
' 辅助函数：打印并清理异常
sub printException(byval ctx as JSContext ptr)
    ' 检查是否有异常
    if JS_HasException(ctx) = false then
        Return
    end if
    
    ' ★ 使用 JS_GetException 获取异常（必须已声明）
    Dim exc As JSValue = JS_GetException(ctx)
    
    ' 转换为字符串
    Dim msg As  ZString Ptr = JS_ToCString(ctx, exc)
    if msg <> NULL then
        print "JavaScript 错误: " & *msg
        JS_FreeCString(ctx, msg)
    else
        print "JavaScript 错误: [无法转换为字符串]"
    end if
    
    ' 清理异常对象
    JS_FreeValue(ctx, exc)
end sub

' 执行 JS 代码，返回数值结果
Function evalNumber(ByVal ctx As JSContext Ptr, ByVal code As ZString Ptr) As Double
    Dim result As JSValue = JS_Eval(ctx, code, len(*code), "test.js", 0)
    
    ' 检查异常
    if JS_IsException(result) then
        printException(ctx)
        JS_FreeValue(ctx, result)
        return 0.0
    end if
    
    ' 转换为数值
    dim d as double
    if JS_ToFloat64(ctx, @d, result) <> 0 then
        d = 0.0
    end if
    
    JS_FreeValue(ctx, result)
    return d
end function

' ==================== 主程序 ====================
print "QuickJS FreeBASIC 测试"
print "======================"

' 创建运行时
dim rt as JSRuntime ptr = JS_NewRuntime()
if rt = NULL then
    print "错误：无法创建 JSRuntime"
    end 1
end if

' 创建上下文
dim ctx as JSContext ptr = JS_NewContext(rt)
if ctx = NULL then
    print "错误：无法创建 JSContext"
    JS_FreeRuntime(rt)
    end 1
end if

' 测试1：基础计算
print "[测试1] 基础计算"
dim n1 as double = evalNumber(ctx, @"40 + 2")
print "  40 + 2 = " & n1 & iif(n1 = 42, "", " ?")

' 测试2：故意制造错误（测试 JS_GetException）
print "[测试2] 错误捕获"
dim errResult as JSValue = JS_Eval(ctx, @"syntax error here !!!", 20, "error.js", 0)
if JS_IsException(errResult) then
    printException(ctx)
else
    JS_FreeValue(ctx, errResult)
end if

' 测试3：创建和操作对象
print "[测试3] 对象操作"
dim obj as JSValue = JS_NewObject(ctx)
if JS_IsObject(obj) then
    Print "创建对象成功"
    
    ' 设置属性
    dim numVal as JSValue = JS_NewInt32(ctx, 123)
    JS_SetPropertyStr(ctx, obj, "value", numVal)
    JS_FreeValue(ctx, numVal)
    
    ' 获取属性
    dim prop as JSValue = JS_GetPropertyStr(ctx, obj, "value")
    dim propInt as int32_t
    JS_ToInt32(ctx, @propInt, prop)
    Print "  obj.value = " & propInt & IIf(propInt = 123, "", "?")
    JS_FreeValue(ctx, prop)
else
    print "  创建对象失败"
end if
JS_FreeValue(ctx, obj)

' 测试4：数组
print "[测试4] 数组操作"
dim arrCode as zstring ptr = @"[1, 22, 333, 4444, 55555]"
dim arrVal as JSValue = JS_Eval(ctx, arrCode, len(*arrCode), "array.js", 0)
if JS_IsArray(arrVal) then
    Print "  创建数组成功"
    ' 获取长度
    dim arrLen as int64_t
    if JS_GetLength(ctx, arrVal, @arrLen) = 0 then  ' 返回0表示成功
       Print "数组长度:" & arrLen
       ' ★★★ 遍历数组元素 ★★★
        print ""
        Print "遍历数组元素:"
        dim i as integer
        for i = 0 to arrLen - 1
            ' 获取第 i 个元素
            dim elem as JSValue = JS_GetPropertyUint32(ctx, arrVal, i)
            
            ' 转换为整数并打印
            Dim dval As int32_t
            If JS_ToInt32(ctx, @dval, elem) = 0 Then
                Print "   arr[" & i & "] = " & dval
            End If
            
            ' 释放元素引用
            JS_FreeValue(ctx, elem)
        Next i
   Else
      Print "获取长度失败"
   End If
End If
JS_FreeValue(ctx, arrVal)

' 清理
JS_FreeContext(ctx)
JS_FreeRuntime(rt)

print ""
print "测试完成！"
sleep