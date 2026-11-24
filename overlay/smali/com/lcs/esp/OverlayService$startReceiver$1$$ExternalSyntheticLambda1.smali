.class public final synthetic Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;
.super Ljava/lang/Object;
.source "D8$$SyntheticClass"

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field public final synthetic f$0:Lcom/lcs/esp/OverlayService;

.field public final synthetic f$1:Ljava/util/List;

.field public final synthetic f$2:Lcom/lcs/esp/Guide;


# direct methods
.method public synthetic constructor <init>(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V
    .locals 0

    .line 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$0:Lcom/lcs/esp/OverlayService;

    iput-object p2, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$1:Ljava/util/List;

    iput-object p3, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$2:Lcom/lcs/esp/Guide;

    return-void
.end method


# virtual methods
.method public final run()V
    .locals 3

    .line 0
    iget-object v0, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$0:Lcom/lcs/esp/OverlayService;

    iget-object v1, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$1:Ljava/util/List;

    iget-object v2, p0, Lcom/lcs/esp/OverlayService$startReceiver$1$$ExternalSyntheticLambda1;->f$2:Lcom/lcs/esp/Guide;

    invoke-static {v0, v1, v2}, Lcom/lcs/esp/OverlayService$startReceiver$1;->$r8$lambda$TYaGKNbWa25zjRHp_AeRTM1ZxBw(Lcom/lcs/esp/OverlayService;Ljava/util/List;Lcom/lcs/esp/Guide;)V

    return-void
.end method
