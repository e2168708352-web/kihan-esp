// project.h — 投影与变换数学（纯函数，无 IO，可在任意 host 上单测）
//
// 与 esp/esp.js 里的 buildView()/project() 完全等价，只是从 JS 搬到了 C。
// 之所以不用 Unity 的 worldToCameraMatrix：这套渲染管线下实测返回近似单位
// 矩阵，用它投影会把世界坐标当相机坐标（线钉死）。这里一律用相机 Transform
// 的位置 + 旋转自建视图矩阵。
#ifndef ESPD_PROJECT_H
#define ESPD_PROJECT_H

typedef struct { float m[16]; } mat4;   /* 列主序，m[col*4+row] */

/* Unity 四元数 (x,y,z,w) → 4x4 旋转矩阵（列主序） */
void mat4_from_quat(mat4 *out, float qx, float qy, float qz, float qw);

/* TRS(pos, quat, scale) → 列主序矩阵 */
void mat4_trs(mat4 *out, const float pos[3], const float q[4], const float scl[3]);

/* a * b（列主序，等价 Unity 的 a.MultiplyPoint3x4 语义） */
void mat4_mul(mat4 *out, const mat4 *a, const mat4 *b);

/* 视图矩阵：Scale(1,1,-1) · TRS(camPos, camRot, 1)^-1，列主序 */
void build_view(mat4 *mv, const float camPos[3], const float q[4]);

/* 世界坐标 → 归一化屏幕坐标。返回 0 表示在相机后方（w<=eps）。 */
int project_point(const mat4 *mv, const mat4 *proj,
                  float wx, float wy, float wz, float *nx, float *ny);

/* 透视投影矩阵（自建，fov 需一次性校准；单位：度） */
void build_persp(mat4 *mp, float fov_deg, float aspect, float near_z, float far_z);

/* 生成一个已知答案的用例，校验 build_view/project_point 与 esp.js 一致 */
int project_selftest(char *msg, int cap);

#endif
