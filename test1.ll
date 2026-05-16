; Test 1: Arithmetic-Heavy Function
; This function contains mostly arithmetic operations (add, mul, sub)
; with low weighted cost compared to memory and call operations.

; ModuleID = 'test1.c'
source_filename = "test1.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define dso_local i32 @arithmetic_heavy(i32 noundef %n) #0 {
entry:
  %n.addr = alloca i32, align 4
  %result = alloca i32, align 4
  %i = alloca i32, align 4
  store i32 %n, ptr %n.addr, align 4
  store i32 0, ptr %result, align 4
  store i32 0, ptr %i, align 4
  br label %for.cond

for.cond:                                         ; preds = %for.inc, %entry
  %0 = load i32, ptr %i, align 4
  %1 = load i32, ptr %n.addr, align 4
  %cmp = icmp slt i32 %0, %1
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.cond
  br label %for.end

for.body:                                         ; preds = %for.cond
  %2 = load i32, ptr %result, align 4
  %3 = load i32, ptr %i, align 4
  %add = add i32 %2, %3
  store i32 %add, ptr %result, align 4
  %4 = load i32, ptr %result, align 4
  %5 = load i32, ptr %i, align 4
  %mul = mul i32 %4, %5
  store i32 %mul, ptr %result, align 4
  %6 = load i32, ptr %result, align 4
  %sub = sub i32 %6, 1
  store i32 %sub, ptr %result, align 4
  %7 = load i32, ptr %result, align 4
  %8 = load i32, ptr %i, align 4
  %add1 = add i32 %7, %8
  store i32 %add1, ptr %result, align 4
  br label %for.inc

for.inc:                                          ; preds = %for.body
  %9 = load i32, ptr %i, align 4
  %inc = add i32 %9, 1
  store i32 %inc, ptr %i, align 4
  br label %for.cond, !llvm.loop !6

for.end:                                          ; preds = %for.cond.cleanup
  %10 = load i32, ptr %result, align 4
  ret i32 %10
}

attributes #0 = { noinline nounwind  uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+cxsr,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 7, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 2}
!5 = !{!"clang version 14.0.0"}
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
