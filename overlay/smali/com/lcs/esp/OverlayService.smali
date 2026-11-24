.class public final Lcom/lcs/esp/OverlayService;
.super Landroid/app/Service;
.source "OverlayService.kt"


# annotations
.annotation system Ldalvik/annotation/SourceDebugExtension;
    value = "SMAP\nOverlayService.kt\nKotlin\n*S Kotlin\n*F\n+ 1 OverlayService.kt\ncom/lcs/esp/OverlayService\n+ 2 fake.kt\nkotlin/jvm/internal/FakeKt\n*L\n1#1,191:1\n1#2:192\n*E\n"
.end annotation

.annotation runtime Lkotlin/Metadata;
    d1 = {
        "\u0000L\n\u0002\u0018\u0002\n\u0002\u0018\u0002\n\u0002\u0008\u0002\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0010\u0002\n\u0002\u0008\u0003\n\u0002\u0018\u0002\n\u0002\u0010 \n\u0002\u0018\u0002\n\u0002\u0018\u0002\n\u0000\n\u0002\u0010\u000e\n\u0002\u0008\u0003\u0018\u00002\u00020\u0001B\u0005\u00a2\u0006\u0002\u0010\u0002J\u0014\u0010\t\u001a\u0004\u0018\u00010\n2\u0008\u0010\u000b\u001a\u0004\u0018\u00010\u000cH\u0016J\u0008\u0010\r\u001a\u00020\u000eH\u0016J\u0008\u0010\u000f\u001a\u00020\u000eH\u0016J\n\u0010\u0010\u001a\u0004\u0018\u00010\u0004H\u0002J$\u0010\u0011\u001a\u0016\u0012\n\u0012\u0008\u0012\u0004\u0012\u00020\u00140\u0013\u0012\u0006\u0012\u0004\u0018\u00010\u00150\u00122\u0006\u0010\u0016\u001a\u00020\u0017H\u0002J\u0008\u0010\u0018\u001a\u00020\u000eH\u0002J\u0008\u0010\u0019\u001a\u00020\u000eH\u0002R\u0010\u0010\u0003\u001a\u0004\u0018\u00010\u0004X\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0005\u001a\u00020\u0006X\u0082.\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0007\u001a\u00020\u0008X\u0082.\u00a2\u0006\u0002\n\u0000\u00a8\u0006\u001a"
    }
    d2 = {
        "Lcom/lcs/esp/OverlayService;",
        "Landroid/app/Service;",
        "()V",
        "socket",
        "Ljava/net/DatagramSocket;",
        "view",
        "Lcom/lcs/esp/EspView;",
        "wm",
        "Landroid/view/WindowManager;",
        "onBind",
        "Landroid/os/IBinder;",
        "intent",
        "Landroid/content/Intent;",
        "onCreate",
        "",
        "onDestroy",
        "openSocket",
        "parse",
        "Lkotlin/Pair;",
        "",
        "Lcom/lcs/esp/Blip;",
        "Lcom/lcs/esp/Guide;",
        "text",
        "",
        "startForegroundWithChannel",
        "startReceiver",
        "app_debug"
    }
    k = 0x1
    mv = {
        0x1,
        0x9,
        0x0
    }
    xi = 0x30
.end annotation


# instance fields
.field private socket:Ljava/net/DatagramSocket;

.field private view:Lcom/lcs/esp/EspView;

.field private wm:Landroid/view/WindowManager;


# direct methods
.method public constructor <init>()V
    .locals 0

    .line 17
    invoke-direct {p0}, Landroid/app/Service;-><init>()V

    return-void
.end method

.method public static final synthetic access$getSocket$p(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;
    .locals 0

    .line 17
    iget-object p0, p0, Lcom/lcs/esp/OverlayService;->socket:Ljava/net/DatagramSocket;

    return-object p0
.end method

.method public static final synthetic access$getView$p(Lcom/lcs/esp/OverlayService;)Lcom/lcs/esp/EspView;
    .locals 0

    .line 17
    iget-object p0, p0, Lcom/lcs/esp/OverlayService;->view:Lcom/lcs/esp/EspView;

    return-object p0
.end method

.method public static final synthetic access$openSocket(Lcom/lcs/esp/OverlayService;)Ljava/net/DatagramSocket;
    .locals 0

    .line 17
    invoke-direct {p0}, Lcom/lcs/esp/OverlayService;->openSocket()Ljava/net/DatagramSocket;

    move-result-object p0

    return-object p0
.end method

.method public static final synthetic access$parse(Lcom/lcs/esp/OverlayService;Ljava/lang/String;)Lkotlin/Pair;
    .locals 0

    .line 17
    invoke-direct {p0, p1}, Lcom/lcs/esp/OverlayService;->parse(Ljava/lang/String;)Lkotlin/Pair;

    move-result-object p0

    return-object p0
.end method

.method public static final synthetic access$setSocket$p(Lcom/lcs/esp/OverlayService;Ljava/net/DatagramSocket;)V
    .locals 0

    .line 17
    iput-object p1, p0, Lcom/lcs/esp/OverlayService;->socket:Ljava/net/DatagramSocket;

    return-void
.end method

.method private final openSocket()Ljava/net/DatagramSocket;
    .locals 6

    const/4 v0, 0x0

    :goto_0
    const/16 v1, 0x258

    const/4 v2, 0x0

    if-ge v0, v1, :cond_1

    .line 90
    :try_start_0
    new-instance v1, Ljava/net/DatagramSocket;

    invoke-direct {v1, v2}, Ljava/net/DatagramSocket;-><init>(Ljava/net/SocketAddress;)V

    const/4 v3, 0x1

    .line 91
    invoke-virtual {v1, v3}, Ljava/net/DatagramSocket;->setReuseAddress(Z)V

    .line 92
    new-instance v3, Ljava/net/InetSocketAddress;

    const-string v4, "127.0.0.1"

    invoke-static {v4}, Ljava/net/InetAddress;->getByName(Ljava/lang/String;)Ljava/net/InetAddress;

    move-result-object v4

    const/16 v5, 0x7148

    invoke-direct {v3, v4, v5}, Ljava/net/InetSocketAddress;-><init>(Ljava/net/InetAddress;I)V

    check-cast v3, Ljava/net/SocketAddress;

    invoke-virtual {v1, v3}, Ljava/net/DatagramSocket;->bind(Ljava/net/SocketAddress;)V
    :try_end_0
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_0} :catch_0

    return-object v1

    :catch_0
    move-exception v1

    .line 95
    new-instance v3, Ljava/lang/StringBuilder;

    const-string v4, "bind retry "

    invoke-direct {v3, v4}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V

    invoke-virtual {v3, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v3

    const-string v4, ": "

    invoke-virtual {v3, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v3

    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    const-string v3, "ESP"

    invoke-static {v3, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    const/16 v1, 0x28

    if-ge v0, v1, :cond_0

    const-wide/16 v3, 0x1f4

    goto :goto_1

    :cond_0
    const-wide/16 v3, 0x7d0

    .line 96
    :goto_1
    :try_start_1
    invoke-static {v3, v4}, Ljava/lang/Thread;->sleep(J)V
    :try_end_1
    .catch Ljava/lang/InterruptedException; {:try_start_1 .. :try_end_1} :catch_1

    add-int/lit8 v0, v0, 0x1

    goto :goto_0

    :catch_1
    :cond_1
    return-object v2
.end method

.method private final parse(Ljava/lang/String;)Lkotlin/Pair;
    .locals 24
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(",
            "Ljava/lang/String;",
            ")",
            "Lkotlin/Pair<",
            "Ljava/util/List<",
            "Lcom/lcs/esp/Blip;",
            ">;",
            "Lcom/lcs/esp/Guide;",
            ">;"
        }
    .end annotation

    .line 155
    new-instance v0, Ljava/util/ArrayList;

    const/16 v1, 0x8

    invoke-direct {v0, v1}, Ljava/util/ArrayList;-><init>(I)V

    .line 156
    move-object/from16 v1, p1

    check-cast v1, Ljava/lang/CharSequence;

    invoke-static {v1}, Lkotlin/text/StringsKt;->lineSequence(Ljava/lang/CharSequence;)Lkotlin/sequences/Sequence;

    move-result-object v1

    invoke-interface {v1}, Lkotlin/sequences/Sequence;->iterator()Ljava/util/Iterator;

    move-result-object v1

    const/4 v2, 0x0

    move-object v3, v2

    :cond_0
    :goto_0
    invoke-interface {v1}, Ljava/util/Iterator;->hasNext()Z

    move-result v4

    if-eqz v4, :cond_b

    invoke-interface {v1}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v4

    check-cast v4, Ljava/lang/String;

    .line 157
    const-string v5, "A "

    const/4 v6, 0x0

    const/4 v7, 0x2

    invoke-static {v4, v5, v6, v7, v2}, Lkotlin/text/StringsKt;->startsWith$default(Ljava/lang/String;Ljava/lang/String;ZILjava/lang/Object;)Z

    move-result v5

    const/4 v8, 0x0

    const/4 v9, 0x4

    const v10, -0x3b864000    # -999.0f

    const/16 v11, 0x20

    const-string v12, "substring(...)"

    const/4 v13, 0x3

    const/4 v14, 0x1

    if-eqz v5, :cond_3

    .line 158
    invoke-virtual {v4, v7}, Ljava/lang/String;->substring(I)Ljava/lang/String;

    move-result-object v4

    invoke-static {v4, v12}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    move-object v15, v4

    check-cast v15, Ljava/lang/CharSequence;

    new-array v4, v14, [C

    aput-char v11, v4, v6

    const/16 v19, 0x6

    const/16 v20, 0x0

    const/16 v17, 0x0

    const/16 v18, 0x0

    move-object/from16 v16, v4

    invoke-static/range {v15 .. v20}, Lkotlin/text/StringsKt;->split$default(Ljava/lang/CharSequence;[CZIILjava/lang/Object;)Ljava/util/List;

    move-result-object v4

    .line 159
    invoke-interface {v4}, Ljava/util/List;->size()I

    move-result v5

    if-lt v5, v13, :cond_0

    .line 160
    invoke-interface {v4, v6}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    invoke-interface {v4, v14}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v6

    check-cast v6, Ljava/lang/String;

    invoke-static {v6}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v6

    invoke-interface {v4, v7}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v7

    check-cast v7, Ljava/lang/String;

    invoke-static {v7}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v7

    .line 161
    invoke-static {v4, v13}, Lkotlin/collections/CollectionsKt;->getOrNull(Ljava/util/List;I)Ljava/lang/Object;

    move-result-object v11

    check-cast v11, Ljava/lang/String;

    if-eqz v11, :cond_1

    invoke-static {v11}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v11

    if-eqz v11, :cond_1

    invoke-virtual {v11}, Ljava/lang/Float;->floatValue()F

    move-result v10

    :cond_1
    move v15, v10

    .line 162
    invoke-static {v4, v9}, Lkotlin/collections/CollectionsKt;->getOrNull(Ljava/util/List;I)Ljava/lang/Object;

    move-result-object v4

    check-cast v4, Ljava/lang/String;

    if-eqz v4, :cond_2

    invoke-static {v4}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v4

    if-eqz v4, :cond_2

    invoke-virtual {v4}, Ljava/lang/Float;->floatValue()F

    move-result v8

    :cond_2
    move/from16 v16, v8

    if-eqz v5, :cond_0

    if-eqz v6, :cond_0

    if-eqz v7, :cond_0

    .line 163
    new-instance v3, Lcom/lcs/esp/Guide;

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v12

    invoke-virtual {v6}, Ljava/lang/Float;->floatValue()F

    move-result v13

    invoke-virtual {v7}, Ljava/lang/Float;->floatValue()F

    move-result v14

    move-object v11, v3

    invoke-direct/range {v11 .. v16}, Lcom/lcs/esp/Guide;-><init>(FFFFF)V

    goto/16 :goto_0

    .line 167
    :cond_3
    const-string v5, "U "

    invoke-static {v4, v5, v6, v7, v2}, Lkotlin/text/StringsKt;->startsWith$default(Ljava/lang/String;Ljava/lang/String;ZILjava/lang/Object;)Z

    move-result v5

    if-eqz v5, :cond_0

    .line 168
    invoke-virtual {v4, v7}, Ljava/lang/String;->substring(I)Ljava/lang/String;

    move-result-object v4

    invoke-static {v4, v12}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    move-object v15, v4

    check-cast v15, Ljava/lang/CharSequence;

    new-array v4, v14, [C

    aput-char v11, v4, v6

    const/16 v19, 0x6

    const/16 v20, 0x0

    const/16 v17, 0x0

    const/16 v18, 0x0

    move-object/from16 v16, v4

    invoke-static/range {v15 .. v20}, Lkotlin/text/StringsKt;->split$default(Ljava/lang/CharSequence;[CZIILjava/lang/Object;)Ljava/util/List;

    move-result-object v4

    .line 169
    invoke-interface {v4}, Ljava/util/List;->size()I

    move-result v5

    const/4 v11, 0x6

    if-lt v5, v11, :cond_0

    .line 170
    invoke-interface {v4, v6}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    if-eqz v5, :cond_0

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v16

    .line 171
    invoke-interface {v4, v14}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    if-eqz v5, :cond_0

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v17

    .line 172
    invoke-interface {v4, v7}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    const/high16 v7, -0x40800000    # -1.0f

    if-eqz v5, :cond_4

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v5

    move/from16 v18, v5

    goto :goto_1

    :cond_4
    move/from16 v18, v7

    .line 173
    :goto_1
    invoke-interface {v4, v13}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    if-eqz v5, :cond_5

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v5

    move/from16 v19, v5

    goto :goto_2

    :cond_5
    move/from16 v19, v7

    .line 174
    :goto_2
    invoke-interface {v4, v9}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    invoke-static {v5}, Lkotlin/text/StringsKt;->toIntOrNull(Ljava/lang/String;)Ljava/lang/Integer;

    move-result-object v5

    if-eqz v5, :cond_6

    invoke-virtual {v5}, Ljava/lang/Integer;->intValue()I

    move-result v5

    goto :goto_3

    :cond_6
    move v5, v6

    :goto_3
    if-eqz v5, :cond_7

    move/from16 v20, v14

    goto :goto_4

    :cond_7
    move/from16 v20, v6

    :goto_4
    const/4 v5, 0x5

    .line 175
    invoke-static {v4, v5}, Lkotlin/collections/CollectionsKt;->getOrNull(Ljava/util/List;I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    if-eqz v5, :cond_8

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    if-eqz v5, :cond_8

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v5

    move/from16 v21, v5

    goto :goto_5

    :cond_8
    move/from16 v21, v7

    .line 176
    :goto_5
    invoke-static {v4, v11}, Lkotlin/collections/CollectionsKt;->getOrNull(Ljava/util/List;I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/String;

    if-eqz v5, :cond_9

    invoke-static {v5}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v5

    if-eqz v5, :cond_9

    invoke-virtual {v5}, Ljava/lang/Float;->floatValue()F

    move-result v8

    :cond_9
    move/from16 v23, v8

    const/4 v5, 0x7

    .line 177
    invoke-static {v4, v5}, Lkotlin/collections/CollectionsKt;->getOrNull(Ljava/util/List;I)Ljava/lang/Object;

    move-result-object v4

    check-cast v4, Ljava/lang/String;

    if-eqz v4, :cond_a

    invoke-static {v4}, Lkotlin/text/StringsKt;->toFloatOrNull(Ljava/lang/String;)Ljava/lang/Float;

    move-result-object v4

    if-eqz v4, :cond_a

    invoke-virtual {v4}, Ljava/lang/Float;->floatValue()F

    move-result v10

    :cond_a
    move/from16 v22, v10

    .line 178
    new-instance v4, Lcom/lcs/esp/Blip;

    move-object v15, v4

    invoke-direct/range {v15 .. v23}, Lcom/lcs/esp/Blip;-><init>(FFFFZFFF)V

    invoke-virtual {v0, v4}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z

    goto/16 :goto_0

    .line 180
    :cond_b
    new-instance v1, Lkotlin/Pair;

    invoke-direct {v1, v0, v3}, Lkotlin/Pair;-><init>(Ljava/lang/Object;Ljava/lang/Object;)V

    return-object v1
.end method

.method private final startForegroundWithChannel()V
    .locals 6

    .line 66
    const-class v0, Landroid/app/NotificationManager;

    invoke-virtual {p0, v0}, Lcom/lcs/esp/OverlayService;->getSystemService(Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/app/NotificationManager;

    .line 68
    new-instance v1, Landroid/app/NotificationChannel;

    const-string v2, "Background sync"

    move-object v3, v2

    check-cast v3, Ljava/lang/CharSequence;

    const/4 v4, 0x2

    const-string v5, "sync"

    invoke-direct {v1, v5, v3, v4}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V

    .line 67
    invoke-virtual {v0, v1}, Landroid/app/NotificationManager;->createNotificationChannel(Landroid/app/NotificationChannel;)V

    .line 72
    new-instance v0, Landroid/app/Notification$Builder;

    move-object v1, p0

    check-cast v1, Landroid/content/Context;

    invoke-direct {v0, v1, v5}, Landroid/app/Notification$Builder;-><init>(Landroid/content/Context;Ljava/lang/String;)V

    .line 73
    check-cast v2, Ljava/lang/CharSequence;

    invoke-virtual {v0, v2}, Landroid/app/Notification$Builder;->setContentTitle(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;

    move-result-object v0

    const v1, 0x1080057

    .line 74
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setSmallIcon(I)Landroid/app/Notification$Builder;

    move-result-object v0

    .line 75
    invoke-virtual {v0}, Landroid/app/Notification$Builder;->build()Landroid/app/Notification;

    move-result-object v0

    const-string v1, "build(...)"

    invoke-static {v0, v1}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    const/16 v1, 0x1f5

    .line 82
    invoke-virtual {p0, v1, v0}, Lcom/lcs/esp/OverlayService;->startForeground(ILandroid/app/Notification;)V

    return-void
.end method

.method private final startReceiver()V
    .locals 9

    .line 103
    new-instance v0, Lcom/lcs/esp/OverlayService$startReceiver$1;

    invoke-direct {v0, p0}, Lcom/lcs/esp/OverlayService$startReceiver$1;-><init>(Lcom/lcs/esp/OverlayService;)V

    move-object v6, v0

    check-cast v6, Lkotlin/jvm/functions/Function0;

    const/16 v7, 0x15

    const/4 v8, 0x0

    const/4 v1, 0x0

    const/4 v2, 0x1

    const/4 v3, 0x0

    const-string v4, "esp-udp"

    const/4 v5, 0x0

    invoke-static/range {v1 .. v8}, Lkotlin/concurrent/ThreadsKt;->thread$default(ZZLjava/lang/ClassLoader;Ljava/lang/String;ILkotlin/jvm/functions/Function0;ILjava/lang/Object;)Ljava/lang/Thread;

    return-void
.end method


# virtual methods
.method public onBind(Landroid/content/Intent;)Landroid/os/IBinder;
    .locals 0

    const/4 p1, 0x0

    return-object p1
.end method

.method public onCreate()V
    .locals 8

    .line 24
    invoke-super {p0}, Landroid/app/Service;->onCreate()V

    .line 25
    invoke-direct {p0}, Lcom/lcs/esp/OverlayService;->startForegroundWithChannel()V

    .line 27
    const-string v0, "window"

    invoke-virtual {p0, v0}, Lcom/lcs/esp/OverlayService;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v0

    const-string v1, "null cannot be cast to non-null type android.view.WindowManager"

    invoke-static {v0, v1}, Lkotlin/jvm/internal/Intrinsics;->checkNotNull(Ljava/lang/Object;Ljava/lang/String;)V

    check-cast v0, Landroid/view/WindowManager;

    iput-object v0, p0, Lcom/lcs/esp/OverlayService;->wm:Landroid/view/WindowManager;

    .line 28
    new-instance v0, Lcom/lcs/esp/EspView;

    move-object v1, p0

    check-cast v1, Landroid/content/Context;

    invoke-direct {v0, v1}, Lcom/lcs/esp/EspView;-><init>(Landroid/content/Context;)V

    iput-object v0, p0, Lcom/lcs/esp/OverlayService;->view:Lcom/lcs/esp/EspView;

    .line 30
    new-instance v0, Landroid/view/WindowManager$LayoutParams;

    const/16 v6, 0x318

    const/4 v7, -0x3

    const/4 v3, -0x1

    const/4 v4, -0x1

    const/16 v5, 0x7f6

    move-object v2, v0

    invoke-direct/range {v2 .. v7}, Landroid/view/WindowManager$LayoutParams;-><init>(IIIII)V

    const v1, 0x800033

    .line 43
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->gravity:I

    const/4 v1, 0x0

    .line 44
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->x:I

    .line 45
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->y:I

    .line 48
    sget v2, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v3, 0x1e

    if-lt v2, v3, :cond_0

    .line 49
    invoke-virtual {v0, v1}, Landroid/view/WindowManager$LayoutParams;->setFitInsetsTypes(I)V

    const/4 v1, 0x3

    .line 50
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->layoutInDisplayCutoutMode:I

    goto :goto_0

    .line 52
    :cond_0
    sget v1, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v2, 0x1c

    if-lt v1, v2, :cond_1

    const/4 v1, 0x1

    .line 53
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->layoutInDisplayCutoutMode:I

    .line 58
    :cond_1
    :goto_0
    :try_start_0
    sget-object v1, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    move-object v1, p0

    check-cast v1, Lcom/lcs/esp/OverlayService;

    iget-object v1, p0, Lcom/lcs/esp/OverlayService;->wm:Landroid/view/WindowManager;

    const/4 v2, 0x0

    if-nez v1, :cond_2

    const-string v1, "wm"

    invoke-static {v1}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    move-object v1, v2

    :cond_2
    iget-object v3, p0, Lcom/lcs/esp/OverlayService;->view:Lcom/lcs/esp/EspView;

    if-nez v3, :cond_3

    const-string v3, "view"

    invoke-static {v3}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    goto :goto_1

    :cond_3
    move-object v2, v3

    :goto_1
    check-cast v2, Landroid/view/View;

    check-cast v0, Landroid/view/ViewGroup$LayoutParams;

    invoke-interface {v1, v2, v0}, Landroid/view/WindowManager;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V

    sget-object v0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    invoke-static {v0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    goto :goto_2

    :catchall_0
    move-exception v0

    sget-object v1, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    invoke-static {v0}, Lkotlin/ResultKt;->createFailure(Ljava/lang/Throwable;)Ljava/lang/Object;

    move-result-object v0

    invoke-static {v0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;

    .line 60
    :goto_2
    invoke-direct {p0}, Lcom/lcs/esp/OverlayService;->startReceiver()V

    return-void
.end method

.method public onDestroy()V
    .locals 3

    const/4 v0, 0x0

    .line 184
    :try_start_0
    sget-object v1, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    move-object v1, p0

    check-cast v1, Lcom/lcs/esp/OverlayService;

    iget-object v1, p0, Lcom/lcs/esp/OverlayService;->socket:Ljava/net/DatagramSocket;

    if-eqz v1, :cond_0

    invoke-virtual {v1}, Ljava/net/DatagramSocket;->close()V

    sget-object v1, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    goto :goto_0

    :cond_0
    move-object v1, v0

    :goto_0
    invoke-static {v1}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    goto :goto_1

    :catchall_0
    move-exception v1

    sget-object v2, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    invoke-static {v1}, Lkotlin/ResultKt;->createFailure(Ljava/lang/Throwable;)Ljava/lang/Object;

    move-result-object v1

    invoke-static {v1}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;

    .line 185
    :goto_1
    :try_start_1
    sget-object v1, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    move-object v1, p0

    check-cast v1, Lcom/lcs/esp/OverlayService;

    iget-object v1, p0, Lcom/lcs/esp/OverlayService;->view:Lcom/lcs/esp/EspView;

    if-eqz v1, :cond_3

    iget-object v1, p0, Lcom/lcs/esp/OverlayService;->wm:Landroid/view/WindowManager;

    if-nez v1, :cond_1

    const-string v1, "wm"

    invoke-static {v1}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    move-object v1, v0

    :cond_1
    iget-object v2, p0, Lcom/lcs/esp/OverlayService;->view:Lcom/lcs/esp/EspView;

    if-nez v2, :cond_2

    const-string v2, "view"

    invoke-static {v2}, Lkotlin/jvm/internal/Intrinsics;->throwUninitializedPropertyAccessException(Ljava/lang/String;)V

    goto :goto_2

    :cond_2
    move-object v0, v2

    :goto_2
    check-cast v0, Landroid/view/View;

    invoke-interface {v1, v0}, Landroid/view/WindowManager;->removeView(Landroid/view/View;)V

    :cond_3
    sget-object v0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    invoke-static {v0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_1
    .catchall {:try_start_1 .. :try_end_1} :catchall_1

    goto :goto_3

    :catchall_1
    move-exception v0

    sget-object v1, Lkotlin/Result;->Companion:Lkotlin/Result$Companion;

    invoke-static {v0}, Lkotlin/ResultKt;->createFailure(Ljava/lang/Throwable;)Ljava/lang/Object;

    move-result-object v0

    invoke-static {v0}, Lkotlin/Result;->constructor-impl(Ljava/lang/Object;)Ljava/lang/Object;

    .line 186
    :goto_3
    invoke-super {p0}, Landroid/app/Service;->onDestroy()V

    return-void
.end method
