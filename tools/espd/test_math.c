// test_math.c — 数学往返测试（交叉编译到真机跑，验证 project.c 的核心算法）
// 这些是「画不出线 / 线画歪」类 bug 的高发区，必须数值验证，不能只靠肉眼审代码。
#include <stdio.h>
#include <math.h>
#include <string.h>
#include "project.h"

static int fails = 0;
#define CHECK(cond, fmt, ...) do { \
    if (!(cond)) { printf("FAIL: " fmt "\n", ##__VA_ARGS__); fails++; } \
    else printf("ok  : " fmt "\n", ##__VA_ARGS__); \
} while (0)

/* 从 4x4 旋转矩阵反推四元数（与 main.c transform_world 末尾完全一致的算法） */
static void mat_to_quat(const mat4 *w, float q[4]) {
    float m00=w->m[0], m01=w->m[4], m02=w->m[8];
    float m10=w->m[1], m11=w->m[5], m12=w->m[9];
    float m20=w->m[2], m21=w->m[6], m22=w->m[10];
    float t = m00 + m11 + m22, s;
    if (t > 0) {
        s = sqrtf(t + 1.0f) * 2.0f;
        q[3] = 0.25f*s; q[0] = (m21-m12)/s; q[1] = (m02-m20)/s; q[2] = (m10-m01)/s;
    } else if (m00>m11 && m00>m22) {
        s = sqrtf(1.0f+m00-m11-m22)*2.0f;
        q[0]=0.25f*s; q[3]=(m21-m12)/s; q[1]=(m01+m10)/s; q[2]=(m02+m20)/s;
    } else if (m11>m22) {
        s = sqrtf(1.0f+m11-m00-m22)*2.0f;
        q[1]=0.25f*s; q[3]=(m02-m20)/s; q[0]=(m01+m10)/s; q[2]=(m12+m21)/s;
    } else {
        s = sqrtf(1.0f+m22-m00-m11)*2.0f;
        q[2]=0.25f*s; q[3]=(m10-m01)/s; q[0]=(m02+m20)/s; q[1]=(m12+m21)/s;
    }
}

static float quat_dot(float a[4], float b[4]) {
    return fabsf(a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3]);
}

int main(void) {
    printf("=== test_math start ===\n");

    /* 1. 四元数 → 矩阵 → 四元数 往返。覆盖各象限（含 t<=0 的三个分支） */
    float qs[][4] = {
        {0,0,0,1},                 /* 单位 */
        {0.7071f,0,0,0.7071f},     /* X 90°，trace=0 边界 */
        {0,0.7071f,0,0.7071f},     /* Y 90° */
        {0,0,0.7071f,0.7071f},     /* Z 90° */
        {0,0,1,0},                 /* Z 180°，trace=-1 → else 分支 */
        {1,0,0,0},                 /* X 180° → m00 分支 */
        {0,1,0,0},                 /* Y 180° → m11 分支 */
        {0.5f,0.5f,0.5f,0.5f},     /* 一般旋转，trace>0 */
        {-0.3f,0.4f,-0.5f,0.7f},   /* 混合符号 */
    };
    for (unsigned i=0; i<sizeof(qs)/sizeof(qs[0]); i++) {
        /* 归一化输入（保证是单位四元数） */
        float q[4]; memcpy(q, qs[i], sizeof q);
        float n = sqrtf(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
        for (int k=0;k<4;k++) q[k]/=n;

        mat4 m; mat4_from_quat(&m, q[0],q[1],q[2],q[3]);
        float back[4]; mat_to_quat(&m, back);
        float d = quat_dot(q, back);   /* q 与 -q 等价，取绝对值 */
        CHECK(d > 0.999f, "quat roundtrip[%u] dot=%.5f (q=%.2f,%.2f,%.2f,%.2f)",
              i, d, q[0],q[1],q[2],q[3]);
    }

    /* 2. 单位四元数的旋转矩阵必须是单位阵 */
    mat4 I; mat4_from_quat(&I, 0,0,0,1);
    CHECK(fabsf(I.m[0]-1)<1e-6f && fabsf(I.m[5]-1)<1e-6f && fabsf(I.m[10]-1)<1e-6f
          && fabsf(I.m[15]-1)<1e-6f, "identity quat -> identity matrix");

    /* 3. TRS 累乘：两个平移子链，父 (10,0,0) + 子局部 (0,5,0) → 世界 (10,5,0) */
    float p1[3]={10,0,0}, q1[4]={0,0,0,1}, s1[3]={1,1,1};
    float p2[3]={0,5,0}, q2[4]={0,0,0,1}, s2[3]={1,1,1};
    mat4 m1,m2,prod;
    mat4_trs(&m1,p1,q1,s1);
    mat4_trs(&m2,p2,q2,s2);
    mat4_mul(&prod,&m1,&m2);
    CHECK(fabsf(prod.m[12]-10)<1e-5f && fabsf(prod.m[13]-5)<1e-5f,
          "TRS chain world pos = (%.3f, %.3f, %.3f)", prod.m[12],prod.m[13],prod.m[14]);

    /* 4. build_view + project：相机原点朝 +Z，正前方点应在屏幕中心 */
    mat4 mv, mp; float cp[3]={0,0,0}, cq[4]={0,0,0,1};
    build_view(&mv, cp, cq);
    build_persp(&mp, 60, 1, 0.1f, 1000);
    float nx,ny;
    CHECK(project_point(&mv,&mp,0,0,10,&nx,&ny) && fabsf(nx-0.5f)<1e-4f && fabsf(ny-0.5f)<1e-4f,
          "center point -> (%.4f, %.4f)", nx, ny);

    /* 5. 相机自身旋转 90° 绕 Y：正前方（世界 +X）的点应映射到屏幕中心。
     *    这验证「相机朝向参与投影」——原来朝向写死单位阵就会在这里挂。 */
    float cq90[4]={0,0.70710678f,0,0.70710678f};  /* Y 90° */
    mat4 mv90; build_view(&mv90, cp, cq90);
    /* Y+90° 相机 forward 从 +Z 转到 +X，所以世界 (10,0,0) 是正前方 */
    float x2,y2;
    int vis = project_point(&mv90,&mp,10,0,0,&x2,&y2);
    CHECK(vis && fabsf(x2-0.5f)<0.02f && fabsf(y2-0.5f)<0.02f,
          "camera yaw90: world +X point -> screen (%.4f, %.4f) vis=%d", x2,y2,vis);

    printf("=== test_math done, fails=%d ===\n", fails);
    return fails ? 1 : 0;
}
