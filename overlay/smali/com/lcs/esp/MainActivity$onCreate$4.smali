.class final Lcom/lcs/esp/MainActivity$onCreate$4;
.super Lkotlin/jvm/internal/Lambda;
.source "MainActivity.kt"

# interfaces
.implements Lkotlin/jvm/functions/Function0;


# annotations
.annotation system Ldalvik/annotation/EnclosingMethod;
    value = Lcom/lcs/esp/MainActivity;->onCreate(Landroid/os/Bundle;)V
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
.field final synthetic this$0:Lcom/lcs/esp/MainActivity;


# direct methods
.method constructor <init>(Lcom/lcs/esp/MainActivity;)V
    .locals 0

    iput-object p1, p0, Lcom/lcs/esp/MainActivity$onCreate$4;->this$0:Lcom/lcs/esp/MainActivity;

    const/4 p1, 0x0

    invoke-direct {p0, p1}, Lkotlin/jvm/internal/Lambda;-><init>(I)V

    return-void
.end method


# virtual methods
.method public bridge synthetic invoke()Ljava/lang/Object;
    .locals 1

    .line 121
    invoke-virtual {p0}, Lcom/lcs/esp/MainActivity$onCreate$4;->invoke()V

    sget-object v0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    return-object v0
.end method

.method public final invoke()V
    .locals 6

    .line 122
    :goto_0
    invoke-static {}, Ljava/lang/Thread;->currentThread()Ljava/lang/Thread;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/Thread;->isInterrupted()Z

    move-result v0

    if-nez v0, :cond_4

    .line 124
    :try_start_0
    sget-object v0, Lcom/lcs/esp/Setup;->INSTANCE:Lcom/lcs/esp/Setup;

    invoke-virtual {v0}, Lcom/lcs/esp/Setup;->hasRoot()Z

    move-result v0

    .line 125
    sget-object v1, Lcom/lcs/esp/Setup;->INSTANCE:Lcom/lcs/esp/Setup;

    invoke-virtual {v1}, Lcom/lcs/esp/Setup;->monitor()Lcom/lcs/esp/Setup$Mon;

    move-result-object v1

    if-nez v0, :cond_0

    .line 127
    const-string v0, "root: \u672a\u6388\u6743\uff08\u70b9\u2461\u65f6 KernelSU \u4f1a\u5f39\u7a97\uff0c\u8bf7\u5141\u8bb8\uff09"

    goto :goto_4

    .line 128
    :cond_0
    invoke-virtual {v1}, Lcom/lcs/esp/Setup$Mon;->getGameOn()Z

    move-result v0

    if-nez v0, :cond_1

    const-string v0, "root: ok   \u6e38\u620f: \u672a\u8fd0\u884c\uff08\u5f00\u4e86\u5c31\u4f1a\u81ea\u52a8\u51fa\u6846\uff09"

    goto :goto_4

    .line 130
    :cond_1
    invoke-virtual {v1}, Lcom/lcs/esp/Setup$Mon;->getTxtAge()J

    move-result-wide v2

    const-wide/16 v4, 0x0

    cmp-long v0, v4, v2

    if-gtz v0, :cond_2

    const-wide/16 v4, 0x3c

    cmp-long v0, v2, v4

    if-gez v0, :cond_2

    invoke-virtual {v1}, Lcom/lcs/esp/Setup$Mon;->getTxtAge()J

    move-result-wide v2

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v2, "s \u524d \u2705 \u6b63\u5728\u5199"

    :goto_1
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    goto :goto_2

    :cond_2
    invoke-virtual {v1}, Lcom/lcs/esp/Setup$Mon;->getTxtAge()J

    move-result-wide v2

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v2, "s \u524d \u26a0\ufe0f \u53ef\u80fd\u505c\u4e86"

    goto :goto_1

    .line 131
    :goto_2
    invoke-virtual {v1}, Lcom/lcs/esp/Setup$Mon;->getCfgOk()Z

    move-result v1

    if-eqz v1, :cond_3

    const-string v1, "script(\u81ea\u52a0\u8f7d) \u2705"

    goto :goto_3

    :cond_3
    const-string v1, "listen \u274c \u70b9\u2461\u4fee"

    :goto_3
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "root: ok   \u6e38\u620f: pid \u5728\u8dd1   \u5fc3\u8df3: "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v2

    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v2, "   \u914d\u7f6e: "

    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    .line 133
    :goto_4
    iget-object v1, p0, Lcom/lcs/esp/MainActivity$onCreate$4;->this$0:Lcom/lcs/esp/MainActivity;

    new-instance v2, Lcom/lcs/esp/MainActivity$onCreate$4$1;

    iget-object v3, p0, Lcom/lcs/esp/MainActivity$onCreate$4;->this$0:Lcom/lcs/esp/MainActivity;

    invoke-direct {v2, v3, v0}, Lcom/lcs/esp/MainActivity$onCreate$4$1;-><init>(Lcom/lcs/esp/MainActivity;Ljava/lang/String;)V

    check-cast v2, Lkotlin/jvm/functions/Function0;

    invoke-static {v1, v2}, Lcom/lcs/esp/MainActivity;->access$ui(Lcom/lcs/esp/MainActivity;Lkotlin/jvm/functions/Function0;)V
    :try_end_0
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_0} :catch_0

    :catch_0
    const-wide/16 v0, 0x1388

    .line 136
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V

    goto/16 :goto_0

    :cond_4
    return-void
.end method
