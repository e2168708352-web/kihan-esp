.class final Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;
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

    iput-object p1, p0, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;->this$0:Lcom/lcs/esp/MainActivity;

    const/4 p1, 0x0

    invoke-direct {p0, p1}, Lkotlin/jvm/internal/Lambda;-><init>(I)V

    return-void
.end method


# virtual methods
.method public bridge synthetic invoke()Ljava/lang/Object;
    .locals 1

    .line 63
    invoke-virtual {p0}, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;->invoke()V

    sget-object v0, Lkotlin/Unit;->INSTANCE:Lkotlin/Unit;

    return-object v0
.end method

.method public final invoke()V
    .locals 4

    .line 64
    sget-object v0, Lcom/lcs/esp/Setup;->INSTANCE:Lcom/lcs/esp/Setup;

    iget-object v1, p0, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;->this$0:Lcom/lcs/esp/MainActivity;

    check-cast v1, Landroid/content/Context;

    new-instance v2, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1$ok$1;

    iget-object v3, p0, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;->this$0:Lcom/lcs/esp/MainActivity;

    invoke-direct {v2, v3}, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1$ok$1;-><init>(Lcom/lcs/esp/MainActivity;)V

    check-cast v2, Lkotlin/jvm/functions/Function1;

    invoke-virtual {v0, v1, v2}, Lcom/lcs/esp/Setup;->deploy(Landroid/content/Context;Lkotlin/jvm/functions/Function1;)Z

    move-result v0

    .line 65
    iget-object v1, p0, Lcom/lcs/esp/MainActivity$onCreate$deploy$1$1$1;->this$0:Lcom/lcs/esp/MainActivity;

    if-eqz v0, :cond_0

    const-string v0, "==== \u90e8\u7f72\u6210\u529f ===="

    goto :goto_0

    :cond_0
    const-string v0, "==== \u90e8\u7f72\u5931\u8d25 ===="

    :goto_0
    invoke-static {v1, v0}, Lcom/lcs/esp/MainActivity;->access$log(Lcom/lcs/esp/MainActivity;Ljava/lang/String;)V

    return-void
.end method
