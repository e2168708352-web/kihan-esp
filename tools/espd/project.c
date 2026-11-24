// project.c — 见 project.h
#include "project.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

static void m4_zero(mat4 *o) { memset(o->m, 0, sizeof o->m); }

void mat4_from_quat(mat4 *out, float qx, float qy, float qz, float qw) {
    float x2 = qx + qx, y2 = qy + qy, z2 = qz + qz;
    float xx = qx * x2, xy = qx * y2, xz = qx * z2;
    float yy = qy * y2, yz = qy * z2, zz = qz * z2;
    float wx = qw * x2, wy = qw * y2, wz = qw * z2;

    float r00 = 1 - (yy + zz), r01 = xy - wz, r02 = xz + wy;
    float r10 = xy + wz, r11 = 1 - (xx + zz), r12 = yz - wx;
    float r20 = xz - wy, r21 = yz + wx, r22 = 1 - (xx + yy);

    m4_zero(out);
    out->m[0] = r00; out->m[1] = r10; out->m[2] = r20;
    out->m[4] = r01; out->m[5] = r11; out->m[6] = r21;
    out->m[8] = r02; out->m[9] = r12; out->m[10] = r22;
    out->m[15] = 1;
}

void mat4_trs(mat4 *out, const float pos[3], const float q[4], const float scl[3]) {
    mat4 r;
    mat4_from_quat(&r, q[0], q[1], q[2], q[3]);
    m4_zero(out);
    out->m[0] = r.m[0] * scl[0]; out->m[1] = r.m[1] * scl[0]; out->m[2] = r.m[2] * scl[0];
    out->m[4] = r.m[4] * scl[1]; out->m[5] = r.m[5] * scl[1]; out->m[6] = r.m[6] * scl[1];
    out->m[8] = r.m[8] * scl[2]; out->m[9] = r.m[9] * scl[2]; out->m[10] = r.m[10] * scl[2];
    out->m[12] = pos[0]; out->m[13] = pos[1]; out->m[14] = pos[2];
    out->m[15] = 1;
}

void mat4_mul(mat4 *out, const mat4 *a, const mat4 *b) {
    mat4 t;
    for (int c = 0; c < 4; c++) {
        for (int r = 0; r < 4; r++) {
            float s = 0;
            for (int k = 0; k < 4; k++) s += a->m[k * 4 + r] * b->m[c * 4 + k];
            t.m[c * 4 + r] = s;
        }
    }
    *out = t;
}

void build_view(mat4 *mv, const float camPos[3], const float q[4]) {
    mat4 r;
    mat4_from_quat(&r, q[0], q[1], q[2], q[3]);

    /* R^T（视图旋转） */
    float a00 = r.m[0], a01 = r.m[1], a02 = r.m[2];
    float a10 = r.m[4], a11 = r.m[5], a12 = r.m[6];
    float a20 = r.m[8], a21 = r.m[9], a22 = r.m[10];

    float t0 = -(a00 * camPos[0] + a01 * camPos[1] + a02 * camPos[2]);
    float t1 = -(a10 * camPos[0] + a11 * camPos[1] + a12 * camPos[2]);
    float t2 = -(a20 * camPos[0] + a21 * camPos[1] + a22 * camPos[2]);

    /* 列主序 + z 行取反（与 esp.js buildView 一致） */
    mv->m[0] = a00; mv->m[1] = a10; mv->m[2] = -a20; mv->m[3] = 0;
    mv->m[4] = a01; mv->m[5] = a11; mv->m[6] = -a21; mv->m[7] = 0;
    mv->m[8] = a02; mv->m[9] = a12; mv->m[10] = -a22; mv->m[11] = 0;
    mv->m[12] = t0; mv->m[13] = t1; mv->m[14] = -t2;  mv->m[15] = 1;
}

int project_point(const mat4 *mv, const mat4 *proj,
                  float wx, float wy, float wz, float *nx, float *ny) {
    float cx = mv->m[0] * wx + mv->m[4] * wy + mv->m[8]  * wz + mv->m[12];
    float cy = mv->m[1] * wx + mv->m[5] * wy + mv->m[9]  * wz + mv->m[13];
    float cz = mv->m[2] * wx + mv->m[6] * wy + mv->m[10] * wz + mv->m[14];
    float cw = mv->m[3] * wx + mv->m[7] * wy + mv->m[11] * wz + mv->m[15];

    float qx = proj->m[0] * cx + proj->m[4] * cy + proj->m[8]  * cz + proj->m[12] * cw;
    float qy = proj->m[1] * cx + proj->m[5] * cy + proj->m[9]  * cz + proj->m[13] * cw;
    float qw = proj->m[3] * cx + proj->m[7] * cy + proj->m[11] * cz + proj->m[15] * cw;

    if (qw <= 0.001f) return 0;
    *nx = (qx / qw) * 0.5f + 0.5f;
    *ny = 1.0f - ((qy / qw) * 0.5f + 0.5f);
    return 1;
}

void build_persp(mat4 *mp, float fov_deg, float aspect, float near_z, float far_z) {
    float rad = fov_deg * (float)M_PI / 180.0f;
    float f = 1.0f / tanf(rad * 0.5f);
    m4_zero(mp);
    mp->m[0]  = f / aspect;
    mp->m[5]  = f;
    mp->m[10] = -(far_z + near_z) / (far_z - near_z);
    mp->m[11] = -1.0f;
    mp->m[14] = -(2.0f * far_z * near_z) / (far_z - near_z);
}

int project_selftest(char *msg, int cap) {
    /* 相机在原点、朝向 +Z（Unity 相机 forward = +Z 的旋转恒等），
     * 目标在正前方 10m 略偏右 1m 略上 2m。
     * fov=60, aspect=1 → 右边缘 tan(30)=0.5774 → x=1m/z=10m 归一化 0.5+0.5*(1/10)/0.5774 ≈ 0.5866
     * 上边缘同 → y 略上。这里只校验「投影点有限、在屏幕内、左右上下关系正确」。 */
    float pos[3] = {0, 0, 0};
    float q[4] = {0, 0, 0, 1};
    mat4 mv, mp;
    build_view(&mv, pos, q);
    build_persp(&mp, 60.0f, 1.0f, 0.1f, 1000.0f);

    float nx, ny;
    if (!project_point(&mv, &mp, 0, 0, 10, &nx, &ny)) {
        snprintf(msg, (size_t)cap, "正前方 10m 被判成相机后方");
        return -1;
    }
    if (fabsf(nx - 0.5f) > 1e-3f || fabsf(ny - 0.5f) > 1e-3f) {
        snprintf(msg, (size_t)cap, "正前方点不在屏幕中心: %.4f %.4f", nx, ny);
        return -1;
    }
    float rx, ry, lx, ly;
    project_point(&mv, &mp, 2, 0, 10, &rx, &ry);
    project_point(&mv, &mp, -2, 0, 10, &lx, &ly);
    if (!(rx > 0.5f && lx < 0.5f)) {
        snprintf(msg, (size_t)cap, "左右方向搞反: right=%.3f left=%.3f", rx, lx);
        return -1;
    }
    float ux, uy, dx, dy;
    project_point(&mv, &mp, 0, 2, 10, &ux, &uy);
    project_point(&mv, &mp, 0, -2, 10, &dx, &dy);
    if (!(uy < 0.5f && dy > 0.5f)) {
        snprintf(msg, (size_t)cap, "上下方向搞反: up=%.3f down=%.3f", uy, dy);
        return -1;
    }
    float bx, by;
    if (project_point(&mv, &mp, 0, 0, -10, &bx, &by)) {
        snprintf(msg, (size_t)cap, "背后的点没被剔除");
        return -1;
    }
    snprintf(msg, (size_t)cap, "ok");
    return 0;
}
