.class public final Lcom/lcs/esp/Setup$Mon;
.super Ljava/lang/Object;
.source "Setup.kt"


# annotations
.annotation system Ldalvik/annotation/EnclosingClass;
    value = Lcom/lcs/esp/Setup;
.end annotation

.annotation system Ldalvik/annotation/InnerClass;
    accessFlags = 0x19
    name = "Mon"
.end annotation

.annotation runtime Lkotlin/Metadata;
    d1 = {
        "\u0000\u0018\n\u0002\u0018\u0002\n\u0002\u0010\u0000\n\u0000\n\u0002\u0010\u000b\n\u0000\n\u0002\u0010\t\n\u0002\u0008\n\u0018\u00002\u00020\u0001B%\u0012\u0006\u0010\u0002\u001a\u00020\u0003\u0012\u0006\u0010\u0004\u001a\u00020\u0005\u0012\u0006\u0010\u0006\u001a\u00020\u0005\u0012\u0006\u0010\u0007\u001a\u00020\u0003\u00a2\u0006\u0002\u0010\u0008R\u0011\u0010\u0007\u001a\u00020\u0003\u00a2\u0006\u0008\n\u0000\u001a\u0004\u0008\t\u0010\nR\u0011\u0010\u0006\u001a\u00020\u0005\u00a2\u0006\u0008\n\u0000\u001a\u0004\u0008\u000b\u0010\u000cR\u0011\u0010\u0002\u001a\u00020\u0003\u00a2\u0006\u0008\n\u0000\u001a\u0004\u0008\r\u0010\nR\u0011\u0010\u0004\u001a\u00020\u0005\u00a2\u0006\u0008\n\u0000\u001a\u0004\u0008\u000e\u0010\u000c\u00a8\u0006\u000f"
    }
    d2 = {
        "Lcom/lcs/esp/Setup$Mon;",
        "",
        "gameOn",
        "",
        "txtAge",
        "",
        "gameAge",
        "cfgOk",
        "(ZJJZ)V",
        "getCfgOk",
        "()Z",
        "getGameAge",
        "()J",
        "getGameOn",
        "getTxtAge",
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
.field private final cfgOk:Z

.field private final gameAge:J

.field private final gameOn:Z

.field private final txtAge:J


# direct methods
.method public constructor <init>(ZJJZ)V
    .locals 0

    .line 109
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-boolean p1, p0, Lcom/lcs/esp/Setup$Mon;->gameOn:Z

    iput-wide p2, p0, Lcom/lcs/esp/Setup$Mon;->txtAge:J

    iput-wide p4, p0, Lcom/lcs/esp/Setup$Mon;->gameAge:J

    iput-boolean p6, p0, Lcom/lcs/esp/Setup$Mon;->cfgOk:Z

    return-void
.end method


# virtual methods
.method public final getCfgOk()Z
    .locals 1

    .line 109
    iget-boolean v0, p0, Lcom/lcs/esp/Setup$Mon;->cfgOk:Z

    return v0
.end method

.method public final getGameAge()J
    .locals 2

    .line 109
    iget-wide v0, p0, Lcom/lcs/esp/Setup$Mon;->gameAge:J

    return-wide v0
.end method

.method public final getGameOn()Z
    .locals 1

    .line 109
    iget-boolean v0, p0, Lcom/lcs/esp/Setup$Mon;->gameOn:Z

    return v0
.end method

.method public final getTxtAge()J
    .locals 2

    .line 109
    iget-wide v0, p0, Lcom/lcs/esp/Setup$Mon;->txtAge:J

    return-wide v0
.end method
