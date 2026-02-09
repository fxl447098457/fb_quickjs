#include once "include/quickjs.bi"

#ifdef __FB_64BIT__
    #libpath "win64"
#else
    #libpath "win32"
#endif

' === 执行 JS 代码并直接返回字符串（内部完全释放）===
function EvalJSToString(byval ctx as JSContext ptr, byval js_code as string) as string
    dim as JSValue result = JS_Eval(ctx, StrPtr(js_code), Len(js_code), @"<input>", JS_EVAL_TYPE_GLOBAL)
    
    ' 检查异常
    if JS_IsException(result) then
        dim as JSValue exc = JS_GetException(ctx)
        dim as zstring ptr exc_str = JS_ToCString(ctx, exc)
        dim as string err_msg = "[EXCEPTION: " & *exc_str & "]"
        JS_FreeCString(ctx, exc_str)
        JS_FreeValue(ctx, exc)
        JS_FreeValue(ctx, result)
        return err_msg
    end if
    
    ' 转换为字符串
    dim as zstring ptr cstr_ptr = JS_ToCString(ctx, result)
    if cstr_ptr = NULL then
        JS_FreeValue(ctx, result)
        return "[NULL]"
    end if
    
    dim as string ret_str = *cstr_ptr
    JS_FreeCString(ctx, cstr_ptr)
    
    ' 关键：必须释放 JS_Eval 返回的 result！
    JS_FreeValue(ctx, result)
    
    return ret_str
end function



' === 测试1：前瞻断言（Lookahead）===
sub TestLookahead(byval ctx as JSContext ptr)
    Print "=== 1. 前瞻断言 (?=...) ==="
    
    Dim As String jscode = "(function() { " & _
        "const s = 'hello hello world world'; " & _
        "const matches = s.match(/(\b\w+)\s+\1/g); " & _
        "return matches ? matches.join(' | ') : 'null'; " & _
        "})()"
    
    Print "JS代码: "; jscode
    Dim As String result = EvalJSToString(ctx, jscode)
    
    print "字符串: 'hello hello world world'"
    Print "匹配结果: "; result
    print
end sub

' === 测试2：反向引用（Backreference）===
sub TestBackreference(byval ctx as JSContext ptr)
    Print "=== 2. 反向引用 \1, \2 ==="
    
    Dim As String result = EvalJSToString(ctx, _
        "(function() { " & _
        !"const s = 'hello hello world world'; " & _
        "const matches = s.match(/(\b\w+)\s+\1/g); " & _
        "return matches ? matches.join(' | ') : 'null'; " & _
        "})()")
    
    Print "字符串: 'hello hello world world'"
    print "重复单词: "; result
    print
End Sub

' === 测试3：非贪婪匹配（?）===
sub TestNonGreedy(byval ctx as JSContext ptr)
    print "=== 3. 非贪婪匹配 .*? ==="
    
    dim as string result = EvalJSToString(ctx, _
        "(function() { " & _
        "const html = '<div>First</div><span>Second</span>'; " & _
        "const matches = html.match(/<[^>]+>(.*?)<\/[^>]+>/g); " & _
        "return matches ? matches.map(function(m) { return m.replace(/<[^>]+>/g, '').replace(/<\/[^>]+>/g, ''); }).join(' | ') : 'null'; " & _
        "})()")
    
    print "HTML: <div>First</div><span>Second</span>"
    Print "标签内容: "; result
    print
end sub



' === 主程序 ===
sub main()
    print "FreeBASIC + QuickJS 正则表达式综合测试"
    print string(70, "=")
    
    dim as JSRuntime ptr rt = JS_NewRuntime()
    if rt = NULL then 
        print "错误: JS_NewRuntime 失败"
        return
    end if
    
    dim as JSContext ptr ctx = JS_NewContext(rt)
    if ctx = NULL then 
        print "错误: JS_NewContext 失败"
        JS_FreeRuntime(rt)
        return
    end if
    
    ' 启用正则表达式支持
    JS_AddIntrinsicRegExp(ctx)
    Print "启用正则"
    
    ' 执行所有测试
    TestLookahead(ctx)
    TestBackreference(ctx)
    TestNonGreedy(ctx)
  
    ' 清理资源
    JS_FreeContext(ctx)
    JS_FreeRuntime(rt)
    
    print string(70, "=")
    print "所有测试完成！按任意键退出..."
    sleep
end sub

main()