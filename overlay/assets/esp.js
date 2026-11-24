// esp.js —— 火影忍者(com.tencent.KiHan) 取样器
//   * 值类型返回一律走 il2cpp 的 *_Injected(ref T) 变体：
//     ABI = void fn(T* ret, void* self, MethodInfo*)
//     （直接调 get_position 会崩：12 字节结构体在 AAPCS64 走寄存器返回，没有 sret）
//   * 实体来源 = hook VActor.LateUpdate 白拿 this（不调 FindObjectsOfType，零托管分配）
//   * 驱动 = hook KHMainCameraController.LateUpdate 跑 tick（相机每帧必跑，最稳的节拍）
//   * attach 全部在 setTimeout 里（模块级 attach 会让计时器假死）
//   * 输出：UDP 127.0.0.1:29000 → 悬浮窗 APK；/data/user/0/.../.dh 心跳给开机守护判活
//
// 屏幕投影（本版关键修复）：
//   实测 get_worldToCameraMatrix_Injected / get_worldToLocalMatrix_Injected 在这套渲染管线下
//   返回的都是近似单位矩阵（假值），拿它投影会把世界坐标当相机坐标 → 线钉在错误位置。
//   改为用相机 Transform 的 position + rotation 自建视图矩阵：
//     worldToCameraMatrix = Scale(1,1,-1) * TRS(camPos, camRot, 1)^-1
//
// 文件日志默认关闭：游戏进程里留下任何 esp*.txt（文件 + fd）都是 ACE 最容易抓的硬证据。
// 调试时把 FILE_LOG 改 true 再重载；日常保持 false，诊断只走 console.log（logcat/Frida tag）。
var FILE_LOG = false;
var OUT = "/data/user/0/com.tencent.KiHan/files/esp7.txt";
// 极小心跳（约 5s 一次），给开机守护判活用；名字刻意低调
var HB = "/data/user/0/com.tencent.KiHan/files/.dh";
var hbF = null; try { hbF = new File(HB, "w"); } catch (e) {}
function hb(s){ try{ if(hbF){ hbF.write(s+"\n"); hbF.flush(); } }catch(e){} }

var gLast = null, gLastT = 0;
// 屏幕速度（vang/spd）+ 平滑方位，给脚下指向箭头用
var enPrev = null, enPrevT = 0, mvAng = -999, mvSpd = 0, gAngS = -999;
var ONLY_ENEMY = true;   // 只显示敌方（PVPStatis 已知敌方时生效；练习场/PVE 没有敌方指针 → 自动回落到全部）
var HP_READ = false;     // 不画血量就别读血条：每帧每实体省一条三级指针链（VActor→VEntity→VDisplayObj→KHHeadHpBar）
var UDP_PORT = 29000, EVERY = 2, MAX_ENT = 64, STALE = 60;

var f = null;
if (FILE_LOG) { try { f = new File(OUT, "w"); } catch (e) {} }
function w(s) { if (f) { try { f.write(s + "\n"); } catch (e) {} } }
function flush() { if (f) { try { f.flush(); } catch (e) {} } }

// ---------- il2cpp / 通用工具 ----------
function exp(n){ var m=Process.findModuleByName("libil2cpp.so"); if(!m) return null; try{ return m.getExportByName(n);}catch(e){} return null; }
function fn(n,r,a){ var p=exp(n); return p? new NativeFunction(p,r,a):null; }
function ss(p){ try{ return p.readUtf8String()||"";}catch(e){return "";} }
function u8(p,o){ try{ return p.add(o).readPointer();}catch(e){ return ptr(0);} }
function isExe(p){ if(!p||p.isNull()) return false; try{ var r=Process.findRangeByAddress(p); return !!(r&&(r.protection||"").indexOf("x")>=0);}catch(e){return false;} }
function mp(mi){ if(!mi||mi.isNull()) return null; var c=[0,8,16]; for(var i=0;i<3;i++){ var p=u8(mi,c[i]); if(isExe(p)) return p;} return null; }
function alive(o){ try{ return !o.isNull() && !u8(o,0x10).isNull(); }catch(e){ return false; } }
function i32of(p,o){ try{ return p.add(o).readS32(); }catch(e){ return 0; } }
function findClass(img,ns,name){
  if(!img||img.isNull()) return null;
  var n=pCC(img);
  for(var i=0;i<n;i++){ var k=pIC(img,i); if(k.isNull()) continue;
    if(ss(pCN(k))!==name) continue; if(ns!==null&&ss(pNS(k))!==ns) continue; return k; }
  return null;
}
function methodsOf(k,max){
  var out=[],it=Memory.alloc(Process.pointerSize); it.writePointer(ptr(0)); var g=0;
  while(g++<5000){ var mi=pCM(k,it); if(mi.isNull()) break; if(out.length>=max) break;
    out.push({n:ss(pMN(mi)),a:pPC(mi),mi:mi}); }
  return out;
}

var pDomain=fn("il2cpp_domain_get","pointer",[]), pTA=fn("il2cpp_thread_attach","pointer",["pointer"]);
var pOpen=fn("il2cpp_domain_assembly_open","pointer",["pointer","pointer"]), pImg=fn("il2cpp_assembly_get_image","pointer",["pointer"]);
var pCC=fn("il2cpp_image_get_class_count","uint32",["pointer"]), pIC=fn("il2cpp_image_get_class","pointer",["pointer","uint32"]);
var pCN=fn("il2cpp_class_get_name","pointer",["pointer"]), pNS=fn("il2cpp_class_get_namespace","pointer",["pointer"]);
var pMFN=fn("il2cpp_class_get_method_from_name","pointer",["pointer","pointer","int32"]);
var pCM=fn("il2cpp_class_get_methods","pointer",["pointer","pointer"]), pMN=fn("il2cpp_method_get_name","pointer",["pointer"]);
var pPC=fn("il2cpp_method_get_param_count","uint32",["pointer"]);
var pCF=fn("il2cpp_class_get_fields","pointer",["pointer","pointer"]);
var pFN=fn("il2cpp_field_get_name","pointer",["pointer"]), pFO=fn("il2cpp_field_get_offset","int32",["pointer"]);
var pFSV=fn("il2cpp_field_static_get_value","void",["pointer","pointer"]);

// ---------- PVPStatis：客户端唯一持有"敌方替身状态"的地方 ----------
//   m_myPlayerCtrl@0x78 / m_enemyPlayerCtrl@0x80 : KHPlayerActor
//   mySubstituteCurStateFlag@0xc8 / enemySubstituteCurStateFlag@0xd0
//   实例随回合重建/回收，静态字段可能指向已废弃对象。
//   采信规则：对象头 klass 正确，且 0x78/0x80 至少一个落在"上一帧场上存活角色(VActor+0x30)"集合里。
//   全内存扫描那套（掉帧、会扫崩游戏）已证伪并移除，实例来源只走静态字段。
var pvpInst=ptr(0), enemyPtr=ptr(0), myPtr=ptr(0), statisField=null, statisBuf=null, pvpKlass=null;
var pvpOk=false, pvpMiss=0, ownSetPrev={};
var lastEnS=-1, lastMyS=-1, cdEnemyT=0, SUBLOG=0, edT=0, mdT=0, subCdMs=15000;
var ownSeen={}, lastDrawn={};
var guideOk=0;   // 模块级：心跳定时器要读它（放在 tick 内会被当局部变量，心跳那行会抛错）

function pvpResolve(cs){
  try{
    var k=findClass(cs,"KH","PVPStatis"); if(!k){ w("pvp: no class"); return; }
    pvpKlass=k;
    var fd=null, it=Memory.alloc(Process.pointerSize); it.writePointer(ptr(0));
    for(var g=0;g<400;g++){ var ff=pCF(k,it); if(ff.isNull()) break; if(ss(pFN(ff))==="statis"){ fd=ff; break; } }
    if(!fd){ w("pvp: no statis field"); return; }
    statisField=fd; statisBuf=Memory.alloc(8);
    w("pvp: field off="+pFO(fd)+" klass="+k);
  }catch(e){ w("pvp ERR "+e); }
}
function pvpStatic(){
  if(!statisField || !statisBuf || !pvpKlass) return ptr(0);
  try{
    statisBuf.writePointer(ptr(0));
    pFSV(statisField, statisBuf);
    var v=statisBuf.readPointer();
    if(v.isNull() || !u8(v,0).equals(pvpKlass)) return ptr(0);
    return v;
  }catch(e){ return ptr(0); }
}
function pvpScore(v){
  if(v.isNull() || !pvpKlass) return 0;
  try{
    if(!u8(v,0).equals(pvpKlass)) return 0;
    var my=u8(v,0x78), en=u8(v,0x80), hit=0;
    if(!my.isNull() && ownSetPrev[""+my]===1) hit++;
    if(!en.isNull() && ownSetPrev[""+en]===1) hit++;
    return hit;
  }catch(e){ return 0; }
}
function pvpAdopt(v, tag){
  var s=pvpScore(v);
  var same=v.equals(pvpInst);
  pvpInst=v; pvpOk=s>0;
  lastEnS=-1; lastMyS=-1; edT=0; mdT=0;
  if(!same || SUBLOG<40){ SUBLOG++; w("pvp: adopt"+(tag?"["+tag+"]":"")+" "+v+" score="+s+" ok="+pvpOk+" my="+u8(v,0x78)+" en="+u8(v,0x80)); }
}
function pvpRebind(){
  if(!statisField || !pvpKlass) return;
  var v=pvpStatic();
  if(!v.isNull()){
    if(!v.equals(pvpInst)) pvpAdopt(v, "static");
    else if(!pvpOk){ var s=pvpScore(v); if(s>0){ pvpOk=true; pvpMiss=0; w("pvp: confirm "+v+" score="+s); } }
  } else if(!pvpInst.isNull()){
    pvpInst=ptr(0); pvpOk=false; myPtr=ptr(0); enemyPtr=ptr(0); cdEnemyT=0; lastEnS=-1; lastMyS=-1;
    w("pvp: static null, drop f="+FRAME);
  }
  if(pvpOk) pvpMiss=0; else pvpMiss++;
}
function pvpTick(){
  if((FRAME%20)===0) pvpRebind();
  if(!pvpOk || pvpInst.isNull()) return;
  try{
    var my=u8(pvpInst,0x78), en=u8(pvpInst,0x80);
    if(!my.isNull()) myPtr=my;
    if(!en.isNull()) enemyPtr=en;
    var enS=i32of(pvpInst,0xd0), myS=i32of(pvpInst,0xc8);
    if(lastEnS<0){
      lastEnS=enS; lastMyS=myS;
      w("pvp first: enSub="+enS+" mySub="+myS+" (1=可用 0=冷却中) my="+myPtr+" en="+enemyPtr);
      return;
    }
    // 实测语义：1=替身可用，0=冷却中
    //   1 -> 0 = 对面刚发动替身 → 开始倒计时
    //   0 -> 1 = 冷却结束       → 清计时，并用实测间隔自校准 subCdMs
    if(enS!==lastEnS){
      if(lastEnS===1 && enS===0){
        if(!(edT>0 && nowMs()-edT<2000)){          // 2s 内重复只当抖动
          cdEnemyT=nowMs()+subCdMs; edT=nowMs();
          if(SUBLOG<40){ SUBLOG++; w("ENEMY-SUB 发动(1->0) 记 "+subCdMs+"ms"); }
        }
      } else if(lastEnS===0 && enS===1){
        if(edT>0){
          var real=nowMs()-edT;
          if(real>13000 && real<16000 && Math.abs(real-subCdMs)>300){ w("ENEMY-SUB 校准 real="+real+"ms (原 "+subCdMs+")"); subCdMs=real; }
          if(SUBLOG<40){ SUBLOG++; w("ENEMY-SUB 冷却结束(0->1) 实测="+(real/1000).toFixed(2)+"s"); }
        }
        cdEnemyT=0; edT=0;
      }
      lastEnS=enS;
    }
    if(myS!==lastMyS){
      if(lastMyS===1 && myS===0) mdT=nowMs();
      else if(lastMyS===0 && myS===1 && mdT>0){ if(SUBLOG<40){ SUBLOG++; w("MY-SUB 冷却结束 实测="+((nowMs()-mdT)/1000).toFixed(2)+"s"); } mdT=0; }
      lastMyS=myS;
    }
  }catch(e){}
}
function nowMs(){ return Date.now(); }

// ---------- UDP ----------
// 预分配发送缓冲：每帧 Memory.allocUtf8String 会持续产生 native 分配，固定缓冲更稳
var udpFd=-1, sa=null, pSend=null, sent=0, serr=0, ubuf=null;
function udpInit(){
  var lc=Process.findModuleByName("libc.so"); if(!lc) return false;
  var ps=lc.getExportByName("socket"), pd=lc.getExportByName("sendto");
  if(!ps||!pd) return false;
  var fs=new NativeFunction(ps,"int",["int","int","int"]);
  pSend=new NativeFunction(pd,"long",["int","pointer","ulong","int","pointer","int"]);
  udpFd=fs(2,2,0); if(udpFd<0) return false;
  sa=Memory.alloc(16); sa.writeU16(2);
  sa.add(2).writeU16(((UDP_PORT&0xff)<<8)|((UDP_PORT>>8)&0xff));
  sa.add(4).writeU32(0x0100007f); sa.add(8).writeU32(0);
  ubuf=Memory.alloc(16384);
  return true;
}
function udpSend(t){ if(udpFd<0||!pSend||!ubuf) return; try{ ubuf.writeUtf8String(t); if(pSend(udpFd,ubuf,t.length,0x40,sa,16)<0) serr++; else sent++; }catch(e){ serr++; } }

// ---------- 原生函数 / 缓冲 ----------
var fTf=null,fPos=null,fCam=null,fProj=null,fRot=null,fSW=null,fSH=null;
var miTf=null,miPos=null,miCam=null,miProj=null,miRot=null,miSW=null,miSH=null;
var bufV=Memory.alloc(16), bufV2=Memory.alloc(16), bufM=Memory.alloc(64), bufQ=Memory.alloc(16);
var cam=ptr(0), camPos=[0,0,0], scrW=0, scrH=0, lastMat=-999;
var FRAME=0, TICKS=0, ERR=0, ents=[];
var MV=new Float32Array(16), MP=new Float32Array(16);

// ---------- 投影 ----------
// Unity: Camera.worldToCameraMatrix = Scale(1,1,-1) * TRS(camPos, camRot, 1)^-1
// q=(x,y,z,w) → 世界旋转 R（行主序）；视图矩阵 = [R^T | -R^T*p]，再把 z 行取反。
function buildView(px,py,pz,qx,qy,qz,qw){
  var x2=qx+qx, y2=qy+qy, z2=qz+qz;
  var xx=qx*x2, xy=qx*y2, xz=qx*z2;
  var yy=qy*y2, yz=qy*z2, zz=qz*z2;
  var wx=qw*x2, wy=qw*y2, wz=qw*z2;
  var r00=1-(yy+zz), r01=xy-wz,     r02=xz+wy;
  var r10=xy+wz,     r11=1-(xx+zz), r12=yz-wx;
  var r20=xz-wy,     r21=yz+wx,     r22=1-(xx+yy);
  // R^T（视图旋转）
  var a00=r00, a01=r10, a02=r20;
  var a10=r01, a11=r11, a12=r21;
  var a20=r02, a21=r12, a22=r22;
  var t0=-(a00*px+a01*py+a02*pz);
  var t1=-(a10*px+a11*py+a12*pz);
  var t2=-(a20*px+a21*py+a22*pz);
  // 列主序 + z 行取反
  MV[0]=a00; MV[1]=a10; MV[2]=-a20; MV[3]=0;
  MV[4]=a01; MV[5]=a11; MV[6]=-a21; MV[7]=0;
  MV[8]=a02; MV[9]=a12; MV[10]=-a22; MV[11]=0;
  MV[12]=t0; MV[13]=t1; MV[14]=-t2; MV[15]=1;
}
function loadMat(dst,buf){ for(var i=0;i<16;i++) dst[i]=buf.add(i*4).readFloat(); }
function project(wx,wy,wz){
  var cx=MV[0]*wx+MV[4]*wy+MV[8]*wz+MV[12], cy=MV[1]*wx+MV[5]*wy+MV[9]*wz+MV[13];
  var cz=MV[2]*wx+MV[6]*wy+MV[10]*wz+MV[14], cw=MV[3]*wx+MV[7]*wy+MV[11]*wz+MV[15];
  var qx=MP[0]*cx+MP[4]*cy+MP[8]*cz+MP[12]*cw, qy=MP[1]*cx+MP[5]*cy+MP[9]*cz+MP[13]*cw;
  var qw=MP[3]*cx+MP[7]*cy+MP[11]*cz+MP[15]*cw;
  if(qw<=0.001) return null;
  return { nx:(qx/qw)*0.5+0.5, ny:1-((qy/qw)*0.5+0.5) };
}
function hpOf(e){
  // VEntity.m_displayObject @0x60 -> VDisplayObj.m_headHpBar @0x28 (KH.KHHeadHpBar)
  // KHHeadHpBar: isVisible@0xa8  curHP@0xb8(Int32)  totalHP@0xbc(Int32)
  try{
    var d=u8(e,0x60); if(d.isNull()) return null;
    var hb=u8(d,0x28); if(hb.isNull()) return null;
    if(hb.add(0xa8).readU8()===0) return null;
    var c=hb.add(0xb8).readS32(), t=hb.add(0xbc).readS32();
    if(t>0 && t<200000000 && c>=0 && c<=t) return {hp:c,max:t};
  }catch(er){}
  return null;
}

// ---------- 实体收集 ----------
// 对象头 klass 白名单：hook 里见到的才算"合法的活对象"。
// 对象被回收后内存可能被复用，直接调 get_transform 会原生崩溃（闪退），所以先校验 klass。
var vKlassArr=[];
function vKlassOk(p){
  if(!vKlassArr.length) return true;
  var k=u8(p,0); if(k.isNull()) return false;
  for(var i=0;i<vKlassArr.length;i++){ if(vKlassArr[i].equals(k)) return true; }
  return false;
}
function addEnt(p){
  try{
    var k=u8(p,0);
    if(!k.isNull()){
      var has=false;
      for(var i=0;i<vKlassArr.length;i++){ if(vKlassArr[i].equals(k)){ has=true; break; } }
      if(!has && vKlassArr.length<12){ vKlassArr.push(k); w("vklass+"+k); }
    }
  }catch(e){}
  for(var i2=0;i2<ents.length;i2++){ if(ents[i2].p.equals(p)){ ents[i2].last=FRAME; return; } }
  if(ents.length<MAX_ENT) ents.push({p:p,last:FRAME,hp:-1,mx:-1});
}

// ---------- 非 PVP 场景兜底：PVPStatis 不存在时用"离相机最近 = 自己"挑人 ----------
var mySrc="pvp";
function collectAll(){
  var arr=[];
  for(var i=0;i<ents.length;i++){
    var e=ents[i]; if(FRAME-e.last>STALE) continue;
    try{
      if(!vKlassOk(e.p)||!alive(e.p)) continue;
      var own=u8(e.p,0x30); if(own.isNull()) continue;
      var tr=fTf(e.p,miTf); if(!tr||tr.isNull()) continue;
      fPos(tr,bufV,miPos);
      var x=bufV.readFloat(), y=bufV.add(4).readFloat(), z=bufV.add(8).readFloat();
      if(Math.abs(y)>6 || Math.abs(x)>60 || Math.abs(z)>60) continue;
      arr.push({p:e.p, own:own, x:x, y:y, z:z});
    }catch(_e){}
  }
  return arr;
}
function pickByCam(list){
  var bestMe=null, bestD=1e9, bestPos=null;
  for(var i=0;i<list.length;i++){
    var it=list[i];
    it.d2=(it.x-camPos[0])*(it.x-camPos[0])+(it.y-camPos[1])*(it.y-camPos[1])+(it.z-camPos[2])*(it.z-camPos[2]);
    if(it.d2<bestD){ bestD=it.d2; bestMe=it.own; bestPos=[it.x,it.y,it.z]; }
  }
  if(!bestMe || bestD>196) return;            // 自己离相机 >14m → 不可信，放弃
  // 敌方 = 离"自己"最近的那个（不是离相机最近，避免选到身后的目标）
  var bestEn=null, bd=1e9;
  for(var j=0;j<list.length;j++){
    if(list[j].own.equals(bestMe)) continue;
    var ex=list[j].x-bestPos[0], ey=list[j].y-bestPos[1], ez=list[j].z-bestPos[2];
    var dd=ex*ex+ey*ey+ez*ez;
    if(dd<bd){ bd=dd; bestEn=list[j].own; }
  }
  if(bestEn){ myPtr=bestMe; enemyPtr=bestEn; mySrc="cam"; }
}

// ---------- 主循环 ----------
function tick(){
  FRAME++;
  if(FRAME % EVERY !== 0) return;
  // 角色实例指针会被回收复用，长期挂机时 lastDrawn 只增不减 → 定期清（约 40s 一次）
  if(FRAME % 600 === 0) lastDrawn={};
  try{
    if(fCam && (cam.isNull() || !alive(cam))) cam = fCam(miCam);
    if(!cam.isNull()){
      var ctr=fTf(cam,miTf);
      if(ctr && !ctr.isNull()){
        fPos(ctr,bufV2,miPos);
        camPos=[bufV2.readFloat(),bufV2.add(4).readFloat(),bufV2.add(8).readFloat()];
        // 视图矩阵自建（见文件头）；投影矩阵取游戏自己的（fov/aspect 才准）
        if(FRAME-lastMat>=15 && fProj && fRot){
          try{
            fRot(ctr,bufQ,miRot);
            var qx=bufQ.readFloat(), qy=bufQ.add(4).readFloat(), qz=bufQ.add(8).readFloat(), qw=bufQ.add(12).readFloat();
            if(isFinite(qx)&&isFinite(qy)&&isFinite(qz)&&isFinite(qw)&&(Math.abs(qx)+Math.abs(qy)+Math.abs(qz)+Math.abs(qw))>0.5){
              buildView(camPos[0],camPos[1],camPos[2],qx,qy,qz,qw);
              fProj(cam,bufM,miProj); loadMat(MP,bufM);
              lastMat=FRAME;
            }
          }catch(eq){}
        }
      }
    }
    if(FRAME % 120 === 0 || scrW === 0){ if(fSW) scrW=fSW(miSW); if(fSH) scrH=fSH(miSH); }
    var hasMat = lastMat>-900 && !cam.isNull() && scrW>0;
    pvpTick();

    var lines=[], dbg=[], keep=[], outPts=[];
    ownSeen={};
    // 预选：同一逻辑角色上一帧用的是哪个实例，优先继续用它（避免残影抢位）
    var claim={};
    try{
      for(var ci=0;ci<ents.length;ci++){
        var ce=ents[ci]; if(!ce||!ce.p) continue;
        var co=u8(ce.p,0x30); if(co.isNull()) continue;
        var ck=""+co, ld=lastDrawn[ck];
        if(ld && ld===""+ce.p) claim[ck]=ld;
      }
    }catch(ecc){}
    // 非 PVP：本帧一次性采集全部坐标，免重复 get_transform/get_position
    var posMap=null;
    if(!pvpOk){ var pl=collectAll(); pickByCam(pl); posMap={}; for(var pi=0;pi<pl.length;pi++) posMap[""+pl[pi].p]=pl[pi]; }

    guideOk=0;
    var known = !myPtr.isNull() || !enemyPtr.isNull();
    var myScr=null, enScr=null, enBehind=0, myW=null, enW=null;
    for(var i=0;i<ents.length;i++){
      var e=ents[i]; if(FRAME-e.last>STALE) continue; keep.push(e);
      try{
        var pc = posMap ? posMap[""+e.p] : null;
        var own, x=0, y=0, z=0, havePos=false;
        if(posMap){
          if(!pc) continue;                       // 采集阶段已过滤 klass/alive/own/transform/越界
          own=pc.own; x=pc.x; y=pc.y; z=pc.z; havePos=true;
        } else {
          if(!vKlassOk(e.p)) continue;
          if(!alive(e.p)) continue;
          own=u8(e.p,0x30);
          if(own.isNull()) continue;
        }
        var isMe2 = !myPtr.isNull() && own.equals(myPtr);
        var isEn2 = !enemyPtr.isNull() && own.equals(enemyPtr);
        if(known && !isMe2 && !isEn2) continue;
        var ok2=""+own;
        if(ownSeen[ok2]) continue;
        ownSeen[ok2]=1;
        var onlyEn = ONLY_ENEMY && !enemyPtr.isNull();
        var skipDraw = isMe2 || (onlyEn && !isEn2);   // 只画敌方；自己也要走一遍拿坐标（脚下指向箭头要用）
        var want=claim[ok2];
        if(want && want!==(""+e.p)) continue;
        if(!havePos){
          var tr=fTf(e.p,miTf); if(!tr||tr.isNull()) continue;
          fPos(tr,bufV,miPos);
          x=bufV.readFloat(); y=bufV.add(4).readFloat(); z=bufV.add(8).readFloat();
          if(Math.abs(y)>6 || Math.abs(x)>60 || Math.abs(z)>60) continue;
        }
        lastDrawn[ok2]=""+e.p;
        var dx=x-camPos[0], dy=y-camPos[1], dz=z-camPos[2], dist=Math.sqrt(dx*dx+dy*dy+dz*dz);
        var h=HP_READ?hpOf(e.p):null, hp=h?h.hp:-1, mx=h?h.max:-1;
        var sc=hasMat?project(x,y,z):null;
        if(isMe2){ if(sc) myScr=sc; if(!myW) myW=[x,y,z]; }
        if(isEn2){ if(sc) enScr=sc; else if(hasMat) enBehind=1; enW=[x,y,z]; }
        // 敌方屏幕速度（给脚下指向箭头）
        if(isEn2 && sc){
          var ep=[sc.nx*scrW, sc.ny*scrH], et=nowMs();
          if(enPrev && et>enPrevT && et-enPrevT<400){
            var dvx=ep[0]-enPrev[0], dvy=ep[1]-enPrev[1], ds=Math.sqrt(dvx*dvx+dvy*dvy);
            if(ds>0.6 && ds<400){
              var ma=Math.atan2(dvy,dvx)*180/Math.PI;
              if(mvAng<-900) mvAng=ma;
              else { var dm=((ma-mvAng+540)%360)-180; mvAng+=dm*0.35; mvAng=((mvAng+180)%360+360)%360-180; }
              mvSpd=mvSpd*0.7+ds*0.3;
            } else mvSpd*=0.8;
          }
          enPrev=ep; enPrevT=et;
        } else if(isEn2 && !sc){
          mvSpd*=0.8; if(mvSpd<0.5) mvAng=-999;
        }
        if(sc && !skipDraw){
          var dup=false;
          for(var q2=0;q2<outPts.length;q2++){ if(Math.abs(outPts[q2][0]-sc.nx)*scrW<28 && Math.abs(outPts[q2][1]-sc.ny)*scrH<28){ dup=true; break; } }
          if(dup) continue;
          outPts.push([sc.nx,sc.ny]);
          // 敌方实体（VActor+0x30 == PVPStatis.m_enemyPlayerCtrl）→ 权威替身计时；其他框一律不显示
          var cdv = -1;
          if(isEn2){
            var e2=(cdEnemyT-nowMs())/1000;
            cdv = e2>0 ? e2 : -1;
          }
          // 视野外也发 U 行：用越界 nx/ny 保留敌人相对屏幕的真实方位（clamp 会把所有屏外目标压到同一点，方位全丢）
          var oa=-999;
          if(sc.nx<0.02||sc.nx>0.98||sc.ny<0.02||sc.ny>0.98){
            oa=Math.atan2((sc.ny-0.5)*(scrH||720),(sc.nx-0.5)*(scrW||1569))*180/Math.PI;
          }
          lines.push("U "+sc.nx.toFixed(4)+" "+sc.ny.toFixed(4)+" "+hp+" "+mx+" 0 "+(cdv>0?cdv.toFixed(1):"-1")+" "+dist.toFixed(1)+" "+oa.toFixed(0));
          if(FILE_LOG && dbg.length<4) dbg.push("("+x.toFixed(1)+","+y.toFixed(1)+","+z.toFixed(1)+")->px("+(sc.nx*scrW).toFixed(0)+","+(sc.ny*scrH).toFixed(0)+") d"+dist.toFixed(1)+" hp"+hp+" cd"+(cdv>0?cdv.toFixed(1):"-"));
        } else if(FILE_LOG && dbg.length<4) dbg.push("("+x.toFixed(1)+","+y.toFixed(1)+","+z.toFixed(1)+") d"+dist.toFixed(1)+(hasMat?" behind":" nomat"));
      }catch(eEnt){}
    }

    // ---- 脚下指向箭头：自己脚下 → 敌方 ----
    if(myScr && (enScr || enBehind)){
      var gAng=-999;
      if(enScr){
        var vx=(enScr.nx-myScr.nx)*scrW, vy=(enScr.ny-myScr.ny)*scrH;
        if(Math.abs(vx)+Math.abs(vy)>1) gAng=Math.atan2(vy,vx)*180/Math.PI;
      } else if(myW && enW){
        var bx=myW[0]-(enW[0]-myW[0]), by=myW[1]-(enW[1]-myW[1]), bz=myW[2]-(enW[2]-myW[2]);
        var mm=project(bx,by,bz);
        if(mm){
          var vx2=(mm.nx-myScr.nx)*scrW, vy2=(mm.ny-myScr.ny)*scrH;
          if(Math.abs(vx2)+Math.abs(vy2)>1) gAng=Math.atan2(vy2,vx2)*180/Math.PI+180;
        }
      }
      if(gAng>-900){
        if(gAngS>-900){ var da=((gAng-gAngS+540)%360)-180; gAng=gAngS+da*0.45; }
        gAng=((gAng+180)%360+360)%360-180; gAngS=gAng; gLast={nx:myScr.nx, ny:myScr.ny, ang:gAng}; gLastT=nowMs();
      } else if(gLast && (nowMs()-gLastT)<800){
        gAng=gLast.ang;
      }
      if(gAng>-900){
        var gx2 = (gLast && (nowMs()-gLastT)<800) ? gLast.nx : myScr.nx;
        var gy2 = (gLast && (nowMs()-gLastT)<800) ? gLast.ny : myScr.ny;
        lines.push("A "+gx2.toFixed(4)+" "+gy2.toFixed(4)+" "+gAng.toFixed(0)+" "+(mvAng>-900?mvAng.toFixed(0):"-999")+" "+mvSpd.toFixed(1)); guideOk=1;
      }
    } else { gAngS=-999; enPrev=null; mvSpd=0; mvAng=-999; }

    ents=keep;
    ownSetPrev=ownSeen;

    udpSend("FRAME\n"+(lines.length?lines.join("\n")+"\n":"")+"END\n");

    if(FILE_LOG){
      if(TICKS<30 || TICKS%20===0){
        w("f="+FRAME+" tk="+TICKS+" ent="+ents.length+" out="+lines.length+" cam=("+camPos[0].toFixed(1)+","+camPos[1].toFixed(1)+","+camPos[2].toFixed(1)+") scr="+scrW+"x"+scrH+" mat="+hasMat+" udp="+sent+"/"+serr+" | en="+enemyPtr+" enSub="+lastEnS+" mySub="+lastMyS);
        for(var k=0;k<dbg.length;k++) w("   "+dbg[k]);
        w("   me="+myPtr+" en="+enemyPtr+" known="+known+" src="+mySrc);
        w("   PVP ok="+pvpOk+" inst="+pvpInst+" score="+pvpScore(pvpInst)+" miss="+pvpMiss);
        if(lines.length) w("   "+lines[0]);
        for(var kk=0;kk<lines.length;kk++){ if(lines[kk].indexOf(" 0 -1 ")<0){ w("   !CD "+lines[kk]); break; } }
        flush();
      }
    }
    TICKS++;
  }catch(e){ ERR++; if(ERR<6){ w("!! tick ERR "+e); flush(); } }
}

// ---------- 初始化 ----------
var INITTRY=0, HENT=false, HTICK=false, BEAT=false;
function init(){
  INITTRY++;
  if(INITTRY===1) w("##### ESP "+new Date().toISOString()+" pid="+Process.id);
  // il2cpp 未初始化时 il2cpp_domain_assembly_open 会把 null 喂给 il2cpp_assembly_get_image → access violation
  // （ACE 清进程后新进程刚起来就 attach 会撞上）。这里只探测、不崩，2s 重试探 30 次。
  var D=null; try{ D=pDomain(); }catch(eD){ w("init: domain ERR "+eD); }
  if(D && pTA){ try{ pTA(D); }catch(eT){} }
  var cs=null;
  if(D && pOpen && pImg){
    try{ var asm=pOpen(D,Memory.allocUtf8String("Assembly-CSharp")); if(asm && !asm.isNull()) cs=pImg(asm); }
    catch(eO){ w("init: open ERR "+eO); }
  }
  if(!cs){
    w("init: il2cpp not ready try="+INITTRY+" D="+D+" cs="+cs); flush();
    if(INITTRY<30) setTimeout(function(){ try{ init(); }catch(e2){ w("init ERR "+e2); flush(); } }, 2000);
    return;
  }
  w("init: il2cpp ready try="+INITTRY+" img="+cs);
  try{ initTail(cs,D); }
  catch(eH){ w("init ERR("+INITTRY+") "+eH); flush(); if(INITTRY<30) setTimeout(function(){ try{ init(); }catch(e4){ w("init ERR2 "+e4); flush(); } }, 2000); }
}
function initTail(cs,D){
  try{ pvpResolve(cs); }catch(e0){ w("pvpResolve ERR "+e0); }
  var core=pImg(pOpen(D,Memory.allocUtf8String("UnityEngine.CoreModule")));
  var compK=findClass(core,"UnityEngine","Component"), trK=findClass(core,"UnityEngine","Transform");
  var camK=findClass(core,"UnityEngine","Camera"), scrK=findClass(core,"UnityEngine","Screen");

  miTf=pMFN(compK,Memory.allocUtf8String("get_transform"),0);
  miPos=pMFN(trK,Memory.allocUtf8String("get_position_Injected"),1);
  miRot=pMFN(trK,Memory.allocUtf8String("get_rotation_Injected"),1);
  miCam=pMFN(camK,Memory.allocUtf8String("get_main"),0);
  miProj=pMFN(camK,Memory.allocUtf8String("get_projectionMatrix_Injected"),1);
  miSW=pMFN(scrK,Memory.allocUtf8String("get_width"),0);
  miSH=pMFN(scrK,Memory.allocUtf8String("get_height"),0);
  var a;
  if(a=mp(miTf)) fTf=new NativeFunction(a,"pointer",["pointer","pointer"]);
  if(a=mp(miPos)) fPos=new NativeFunction(a,"void",["pointer","pointer","pointer"]);
  if(a=mp(miRot)) fRot=new NativeFunction(a,"void",["pointer","pointer","pointer"]);
  if(a=mp(miCam)) fCam=new NativeFunction(a,"pointer",["pointer"]);
  if(a=mp(miProj)) fProj=new NativeFunction(a,"void",["pointer","pointer","pointer"]);
  if(a=mp(miSW)) fSW=new NativeFunction(a,"int32",["pointer"]);
  if(a=mp(miSH)) fSH=new NativeFunction(a,"int32",["pointer"]);
  w("mp tf="+!!fTf+" pos="+!!fPos+" rot="+!!fRot+" cam="+!!fCam+" proj="+!!fProj+" scr="+!!fSW+"/"+!!fSH);
  w("udp="+udpInit()+" fd="+udpFd);

  if(!HENT){
    var vActor=findClass(cs,"KH","VActor");
    var ms=methodsOf(vActor,600), n=0;
    ["LateUpdate","Update"].forEach(function(nm){ if(n>0) return;
      for(var i=0;i<ms.length;i++){ if(ms[i].n!==nm||ms[i].a!==0) continue; var ad=mp(ms[i].mi); if(!ad) continue;
        try{ Interceptor.attach(ad,{onEnter:function(args){ addEnt(args[0]); }}); n++; w("ent hook VActor."+nm+" @"+ad); }catch(e){ w("ent ERR "+e); }
        break; }
    });
    w("entity hooks="+n);
    if(n>0) HENT=true;
  }

  if(!HTICK){
    var host=findClass(cs,"KH","KHMainCameraController");
    var hms=methodsOf(host,600), ok=false;
    ["LateUpdate","Update"].forEach(function(nm){
      if(ok) return;
      for(var i=0;i<hms.length;i++){ if(hms[i].n!==nm||hms[i].a!==0) continue; var ad=mp(hms[i].mi); if(!ad) continue;
        try{ Interceptor.attach(ad,{onEnter:function(){ tick(); }}); ok=true; w("drv "+nm+" @"+ad); }catch(e){ w("drv ERR "+e); }
        break; }
    });
    if(ok) HTICK=true;
    // tick 没挂上就重试（KHMainCameraController 可能比 il2cpp 晚就绪；
    // 不重试 → tick 永不跑 → 心跳停 → 守护死循环 reload → 启动动画反复弹）
    if(!ok && INITTRY<30) setTimeout(function(){ try{ initTail(cs,D); }catch(e){ w("retick ERR "+e); } }, 3000);
  }
  flush();

  // 脚本注入成功 → 通知悬浮窗播启动动画；带 pid，悬浮窗按"同一进程只播一次"去重
  udpSend("SPLASH " + Process.id + "\n");

  // 心跳脱离 tick：tick 因任何原因没跑时也要写，否则守护判 stale 会无限 reload。
  // 同一计时器里顺带 console.log（logcat 存活探针）—— 只保留这一个 5s 定时器。
  if(!BEAT){ BEAT=true;
    var b=0;
    (function beat(){
      b++;
      try{ hb("t="+(Date.now()/1000|0)+" mat="+(lastMat>-900?1:0)+" ent="+ents.length+" tk="+TICKS+" pvp="+(pvpOk?1:0)+" g="+guideOk); }catch(e){}
      try{ console.log("[beat] "+b+" f="+FRAME+" tk="+TICKS+" ent="+ents.length+" udp="+sent+"/"+serr+" err="+ERR); }catch(e){}
      setTimeout(beat,5000);
    })();
  }
}
setTimeout(function(){ try{ init(); }catch(e){ w("init ERR "+e); flush(); } }, 1200);
