.class final Lcom/lcs/esp/OverlayService$startReceiver$1;
.super Lkotlin/jvm/internal/Lambda;
.source "OverlayService.kt"

# interfaces
.implements Lkotlin/jvm/functions/Function0;


# annotations
.annotation system Ldalvik/annotation/EnclosingMethod;
    value = Lcom/lcs/esp/OverlayService;->startReceiver()V
.end annotation

.annotation system Ldalvik/annotation/InnerClass;
    accessFlags = 0x18
    name = null
.end annotation

.annotation system Ldalvik/annotation/Signature;
    value = {
        "Lkotlin/jvm/internal/Lambda;",
        "Lkotlin/jvm/functions/Function0<",
        "Lkotlin/Unit;",
        ">;"
    }
.end annotation

.annotation system Ldalvik/annotation/SourceDebugExtension;
    value = "SMAP\nOverlayService.kt\nKotlin\n*S Kotlin\n*F\n+ 1 OverlayService.kt\ncom/lcs/esp/OverlayService$startReceiver$1\n+ 2 fake.kt\nkotlin/jvm/internal/FakeKt\n*L\n1#1,191:1\n1#2:192\n*E\n"
.end annotation

.annotation runtime Lkotlin/Metadata;
    d1 = {
        "\u0000\u0008\n\u0000\n\u0002\u0010\u0002\n\u0000\u0010\u0000\u001a\u00020\u0001H\n\u00a2\u0006\u0002\u0008\u0002"
    }
    d2 = {
        "<anonymous>",
        "",
        "invoke"
    }
    k = 0x3
    mv = {
        0x1,
        0x9,
        0x0
    }
    xi = 0x30
.end annotation


# instance fields
.field final synthetic this$0:Lcom/lcs/esp/OverlayService;


# direct methods
.method public static synthetic $r8$lambda$TYaGKNbWa25zjRHp_AeRTM1ZxBw(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V
    .locals 0

    invoke-static {p0, p1, p2}, Lcom/lcs/esp/OverlayService$startReceiver$1;->invoke$lambda$2(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V

    return-void
.end method

.method public static synthetic $r8$lambda$qbZMzVOt4ey2i0Odxf0Hk7o33Ig(Lcom/lcs/esp/OverlayService;)V
    .locals 0

    invoke-static {p0}, Lcom/lcs/esp/OverlayService$startReceiver$1;->invoke$lambda$1(Lcom/lcs/esp/OverlayService;)V

    return-void
.end method

.method constructor <init>(Lcom/lcs/esp/OverlayService;)V
    .locals 0

    iput-object p1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    const/4 p1, 0x0

    invoke-direct {p0, p1}, Lkotlin/jvm/internal/Lambda;-><init>(I)V

    return-void
.end method

.method private static final invoke$lambda$1(Lcom/lcs/esp/OverlayService;)V
    .locals 1

    const-string v0, "this$0"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 127
    :try_start_0
    sget-object v0, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    invoke-static {p0}, Lcom/lcs/esp/OverlayService;->access$getView$p(Lcom/lcs/esp/OverlayService;)Lcom/lcs/esp/EspView;

    move-result-object p0

    if-nez p0, :cond_0

    const-string p0, "view"

    invoke-static {p0}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    const/4 p0, 0x0

    :cond_0
    invoke-virtual {p0}, Lcom/lcs/esp/EspView;->playSplash()V

    sget-object p0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    invoke-static {p0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    goto :goto_0

    :catchall_0
    move-exception p0

    sget-object v0, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    invoke-static {p0}, Lkotlin/ResultKt;->createFailure(Ljava/lang/Throwable;)Ljava/lang/Object;

    move-result-object p0

    invoke-static {p0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;

    :goto_0
    return-void
.end method

.method private static final invoke$lambda$2(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V
    .locals 1

    const-string v0, "this$0"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    const-string v0, "$list"

    invoke-static {p1, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 138
    invoke-static {p0}, Lcom/lcs/esp/OverlayService;->access$getView$p(Lcom/lcs/esp/OverlayService;)Lcom/lcs/esp/EspView;

    move-result-object p0

    if-nez p0, :cond_0

    const-string p0, "view"

    invoke-static {p0}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    const/4 p0, 0x0

    :cond_0
    invoke-virtual {p0, p1, p2}, Lcom/lcs/esp/EspView;->updateFrame(Ljava/util/List;Lcom/lcs/esp/Guide;)V

    return-void
.end method


# virtual methods
.method public bridge synthetic invoke()Ljava/lang/Object;
    .locals 1

    .line 103
    invoke-virtual {p0}, Lcom/lcs/esp/OverlayService$startReceiver$1;->invoke()V

    sget-object v0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    return-object v0
.end method

.method public final invoke()V
    .locals 10

    const/high16 v0, 0x10000

    .line 104
    new-array v1, v0, [B

    .line 108
    new-instance v2, Ljava/net/DatagramPacket;

    invoke-direct {v2, v1, v0}, Ljava/net/DatagramPacket;-><init>([BI)V

    const-string v0, ""

    .line 109
    :cond_0
    :goto_0
    invoke-static {}, Ljava/lang/Thread;->currentThread()Ljava/lang/Thread;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/Thread;->isInterrupted()Z

    move-result v1

    if-nez v1, :cond_7

    .line 110
    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1}, Lcom/lcs/esp/OverlayService;->access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v1

    const-string v3, "ESP"

    if-eqz v1, :cond_1

    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1}, Lcom/lcs/esp/OverlayService;->access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v1

    invoke-static {v1}, Lkotlin/jvm/internal/Intrinsics;->checkNotNull(Ljava/lang/Object;)V

    invoke-virtual {v1}, Ljava/net/DatagramSocket;->isClosed()Z

    move-result v1

    if-eqz v1, :cond_2

    .line 111
    :cond_1
    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1}, Lcom/lcs/esp/OverlayService;->access$openSocket(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v4

    invoke-static {v1, v4}, Lcom/lcs/esp/OverlayService;->access$setSocket$p(Lcom/lcs/esp/OverlayService;Ljava/net/DatagramSocket;)V

    .line 112
    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1}, Lcom/lcs/esp/OverlayService;->access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v1

    if-nez v1, :cond_2

    .line 113
    const-string v0, "bind failed after retries, give up"

    invoke-static {v3, v0}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    .line 119
    :cond_2
    :try_start_0
    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1}, Lcom/lcs/esp/OverlayService;->access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v1

    invoke-static {v1}, Lkotlin/jvm/internal/Intrinsics;->checkNotNull(Ljava/lang/Object;)V

    invoke-virtual {v1, v2}, Ljava/net/DatagramSocket;->receive(Ljava/net/DatagramPacket;)V

    .line 121
    invoke-virtual {v2}, Ljava/net/DatagramPacket;->getData()[B

    move-result-object v1

    const-string v4, "getData(...)"

    invoke-static {v1, v4}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    invoke-virtual {v2}, Ljava/net/DatagramPacket;->getLength()I

    move-result v4

    sget-object v5, Lkotlin/text/Charsets;->UTF_8:Ljava/nio/charset/Charset;

    new-instance v6, Ljava/lang/String;

    const/4 v7, 0x0

    invoke-direct {v6, v1, v7, v4, v5}, Ljava/lang/String;-><init>([BIILjava/nio/charset/Charset;)V

    .line 122
    move-object v1, v6

    check-cast v1, Ljava/lang/CharSequence;

    const-string v4, "SPLASH"

    check-cast v4, Ljava/lang/CharSequence;

    const/4 v5, 0x2

    const/4 v8, 0x0

    invoke-static {v1, v4, v7, v5, v8}, Lkotlin/text/StringsKt;->contains$default(Ljava/lang/CharSequence;Ljava/lang/CharSequence;ZILjava/lang/Object;)Z

    move-result v1
    :try_end_0
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_0} :catch_1

    const-string v4, "view"

    if-eqz v1, :cond_4

    .line 124
    :try_start_1
    check-cast v6, Ljava/lang/CharSequence;

    invoke-static {v6}, Lkotlin/text/StringsKt;->trim(Ljava/lang/CharSequence;)Ljava/lang/CharSequence;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v1

    const/16 v6, 0x20

    invoke-static {v1, v6, v8, v5, v8}, Lkotlin/text/StringsKt;->substringAfter$default(Ljava/lang/String;CLjava/lang/String;ILjava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    check-cast v1, Ljava/lang/CharSequence;

    invoke-static {v1}, Lkotlin/text/StringsKt;->trim(Ljava/lang/CharSequence;)Ljava/lang/CharSequence;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v1

    .line 125
    move-object v5, v1

    check-cast v5, Ljava/lang/CharSequence;

    invoke-interface {v5}, Ljava/lang/CharSequence;->length()I

    move-result v5

    if-lez v5, :cond_0

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->areEqual(Ljava/lang/Object;Ljava/lang/Object;)Z

    move-result v5
    :try_end_1
    .catch Ljava/lang/Exception; {:try_start_1 .. :try_end_1} :catch_1

    if-nez v5, :cond_0

    .line 127
    :try_start_2
    iget-object v0, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v0}, Lcom/lcs/esp/OverlayService;->access$getView$p(Lcom/lcs/esp/OverlayService;)Lcom/lcs/esp/EspView;

    move-result-object v0

    if-nez v0, :cond_3

    invoke-static {v4}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    goto :goto_1

    :cond_3
    move-object v8, v0

    :goto_1
    iget-object v0, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    new-instance v4, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda0;

    invoke-direct {v4, v0}, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda0;-><init>(Lcom/lcs/esp/OverlayService;)V

    invoke-virtual {v8, v4}, Lcom/lcs/esp/EspView;->post(Ljava/lang/Runnable;)Z
    :try_end_2
    .catch Ljava/lang/Exception; {:try_start_2 .. :try_end_2} :catch_0

    goto :goto_4

    :catch_0
    move-exception v0

    goto :goto_3

    .line 131
    :cond_4
    :try_start_3
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J

    .line 136
    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v1, v6}, Lcom/lcs/esp/OverlayService;->access$parse(Lcom/lcs/esp/OverlayService;Ljava/lang/String;)Lkotlin/Pair;

    move-result-object v1

    invoke-virtual {v1}, Lkotlin/Pair;->component1()Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/util/List;

    invoke-virtual {v1}, Lkotlin/Pair;->component2()Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Lcom/lcs/esp/Guide;

    .line 138
    iget-object v6, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v6}, Lcom/lcs/esp/OverlayService;->access$getView$p(Lcom/lcs/esp/OverlayService;)Lcom/lcs/esp/EspView;

    move-result-object v6

    if-nez v6, :cond_5

    invoke-static {v4}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    goto :goto_2

    :cond_5
    move-object v8, v6

    :goto_2
    iget-object v4, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    new-instance v6, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;

    invoke-direct {v6, v4, v5, v1}, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;-><init>(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V

    invoke-virtual {v8, v6}, Lcom/lcs/esp/EspView;->post(Ljava/lang/Runnable;)Z
    :try_end_3
    .catch Ljava/lang/Exception; {:try_start_3 .. :try_end_3} :catch_1

    goto/16 :goto_0

    :catch_1
    move-exception v1

    move-object v9, v1

    move-object v1, v0

    move-object v0, v9

    .line 140
    :goto_3
    new-instance v4, Ljava/lang/StringBuilder;

    const-string v5, "rx err: "

    invoke-direct {v4, v5}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V

    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v4, " -> reopen"

    invoke-virtual {v0, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v3, v0}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    .line 141
    :try_start_4
    iget-object v0, p0, Lcom/lcs/esp/OverlayService$startReceiver$1;->this$0:Lcom/lcs/esp/OverlayService;

    invoke-static {v0}, Lcom/lcs/esp/OverlayService;->access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;

    move-result-object v0

    if-eqz v0, :cond_6

    invoke-virtual {v0}, Ljava/net/DatagramSocket;->close()V
    :try_end_4
    .catch Ljava/lang/Exception; {:try_start_4 .. :try_end_4} :catch_2

    :catch_2
    :cond_6
    const-wide/16 v3, 0x1f4

    .line 142
    :try_start_5
    invoke-static {v3, v4}, Ljava/lang/Thread;->sleep(J)V
    :try_end_5
    .catch Ljava/lang/InterruptedException; {:try_start_5 .. :try_end_5} :catch_3

    :goto_4
    move-object v0, v1

    goto/16 :goto_0

    :catch_3
    :cond_7
    return-void
.end method
